import Foundation
import TrackTagCore

enum ReviewReason: String {
    case flagged = "Flagged", poor = "Poor quality", atRisk = "File at risk", sent = "Sent from Library", replaced = "Replaced"
}

struct ReviewItem: Identifiable {
    let id: String
    let number: Int
    let track: Track
    let reason: ReviewReason
    let detail: String       // e.g. the flag text
}

extension LibraryStore {
    // MARK: Grades

    func grade(_ t: Track) -> SoundGrade {
        cutoffs.grade(ceilingKHz: ceilings[t.id], kind: t.kind)
    }

    /// Fills ceilings from the saved cache and the Nov 2 scan, then scans the rest in the background.
    func startScan() {
        let seeds = ScanCache.seedPaths()
        var known: [String: Double] = [:]
        var todo: [(String, URL, Date?)] = []
        for t in tracks {
            guard let url = t.fileURL else { continue }
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let e = scanCache.entries[t.id], e.fileDate == date { known[t.id] = e.ceiling; continue }
            if let s = seeds[url.path.lowercased()] {
                known[t.id] = s
                scanCache.entries[t.id] = .init(ceiling: s, fileDate: date)
                continue
            }
            todo.append((t.id, url, date))
        }
        ceilings = known
        scanCache.save()
        recompute()
        guard !todo.isEmpty else { return }
        scanProgress = (0, todo.count)
        let work = todo
        Task.detached(priority: .utility) {
            var done = 0
            var batch: [String: (Double, Date?)] = [:]
            for (id, url, date) in work {
                if let r = SpectrumScanner.analyse(url) { batch[id] = (r.ceilingKHz, date) }
                done += 1
                if batch.count >= 20 || done == work.count {
                    let b = batch; batch = [:]; let d = done
                    await MainActor.run {
                        for (k, v) in b {
                            self.ceilings[k] = v.0
                            self.scanCache.entries[k] = .init(ceiling: v.0, fileDate: v.1)
                        }
                        self.scanProgress = d == work.count ? nil : (d, work.count)
                        self.scanCache.save()
                        self.recompute()
                    }
                }
            }
        }
    }

    // MARK: Queue

    var reviewItems: [ReviewItem] {
        var out: [ReviewItem] = []
        var used = Set<String>()
        func add(_ t: Track, _ r: ReviewReason, _ d: String = "") {
            guard used.insert(t.id).inserted else { return }
            out.append(ReviewItem(id: t.id, number: out.count + 1, track: t, reason: r, detail: d))
        }
        for t in tracks where replacedThisSession.contains(t.id) { add(t, .replaced) }
        for t in tracks {
            let flags = t.title.flags.filter { $0.lowercased() != "review" }
            if let f = flags.first { add(t, .flagged, f) }
        }
        for t in tracks where t.fileAtRisk { add(t, .atRisk) }
        // Poor sound: only tracks you actually play (energy 3+) so the queue stays focused.
        let poor = tracks.filter { grade($0) == .poor && $0.energy >= 3 }
            .sorted { ($0.energy, $0.title.display) > ($1.energy, $1.title.display) }
        for t in poor { add(t, .poor, String(format: "%.1f kHz", ceilings[t.id] ?? 0)) }
        for t in tracks where queues.reviewQueue.contains(t.id) { add(t, .sent) }
        return out
    }

    // MARK: Actions (all writes go through Music)

    /// Sets one review flag in the title (or none). Other flags are replaced; notes and !review! stay.
    func setFlag(_ id: String, to flag: String?) {
        guard let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        var title = tracks[i].title
        for f in title.flags where f.lowercased() != "review" { title = title.removing(flag: f) }
        if let flag, !flag.isEmpty { title = title.adding(flag: flag) }
        do {
            try MusicWriter().write(trackID: id, [.name: title.raw])
            tracks[i].title = title
            if flag == nil { queues.reviewQueue.remove(id); queues.save() }
            recompute()
            reviewMessage = flag == nil ? "Flag cleared" : "Flagged: \(flag!)"
        } catch { reviewMessage = "Couldn’t save the flag: \(error.localizedDescription)" }
    }

    /// Replace: point the same Music track at the better file, keep everything, park the old file.
    func replace(_ id: String, with newFile: URL) {
        guard let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        let t = tracks[i]
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        do {
            // Downloads get filed into the DL crate first: ~/Music/Crate/HQ/<year>.
            var target = newFile
            if newFile.path.hasPrefix(home.appendingPathComponent("Downloads").path) {
                let year = Calendar.current.component(.year, from: Date())
                let dir = home.appendingPathComponent("Music/Crate/HQ/\(year)", isDirectory: true)
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                target = dir.appendingPathComponent(newFile.lastPathComponent)
                if fm.fileExists(atPath: target.path) { target = dir.appendingPathComponent("\(t.id) \(newFile.lastPathComponent)") }
                try fm.moveItem(at: newFile, to: target)
            }
            let writer = MusicWriter()
            try writer.relink(trackID: id, to: target)

            // Old file goes to ~/Music/TrackTag/Replaced (kept 30 days).
            if let old = t.fileURL, fm.fileExists(atPath: old.path), old.path != target.path {
                let bin = home.appendingPathComponent("Music/TrackTag/Replaced", isDirectory: true)
                try fm.createDirectory(at: bin, withIntermediateDirectories: true)
                try? fm.moveItem(at: old, to: bin.appendingPathComponent("\(t.id) \(old.lastPathComponent)"))
            }

            // Write the tags into the new file (Music stores them, this pushes them into the file) and drop flags.
            let cleanTitle = t.title.removing(flag: nil)
            let keepReview = t.title.flags.contains { $0.lowercased() == "review" } ? cleanTitle.adding(flag: "review") : cleanTitle
            try writer.write(trackID: id, [.name: keepReview.raw, .artist: t.artist, .composer: t.composer,
                                           .comment: t.comments.rendered(categoryOrder: TagStops.writeRank),
                                           .genre: t.genre, .grouping: t.grouping, .rating: t.rating, .year: t.year])

            tracks[i].fileURL = target
            tracks[i].title = keepReview
            let ext = target.pathExtension.lowercased()
            tracks[i].kind = ext == "mp3" ? .mp3 : (ext == "wav" ? .wav : .other)
            if let r = SpectrumScanner.analyse(target) { ceilings[id] = r.ceilingKHz }
            queues.reviewQueue.remove(id); queues.save()
            replacedThisSession.insert(id)
            recompute()
            reviewMessage = "Replaced \(t.titleText). In Rekordbox, Relocate it; in Serato, rescan."
        } catch {
            reviewMessage = "Couldn’t replace: \(error.localizedDescription)"
        }
    }

    /// Removes the track from Music and moves its file to ~/Music/TrackTag/Deleted.
    func deleteTrack(_ id: String) {
        guard let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        let t = tracks[i]
        do {
            try MusicWriter().delete(trackID: id)
            if let f = t.fileURL, FileManager.default.fileExists(atPath: f.path) {
                let bin = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/TrackTag/Deleted", isDirectory: true)
                try? FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
                try? FileManager.default.moveItem(at: f, to: bin.appendingPathComponent("\(t.id) \(f.lastPathComponent)"))
            }
            tracks.remove(at: i)
            queues.reviewQueue.remove(id); queues.save()
            recompute()
            reviewMessage = "Deleted \(t.titleText). Its file is in ~/Music/TrackTag/Deleted."
        } catch { reviewMessage = "Couldn’t delete: \(error.localizedDescription)" }
    }
}
