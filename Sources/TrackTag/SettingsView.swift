import SwiftUI
import AppKit
import TrackTagCore

enum SettingsPage: String, CaseIterable, Identifiable {
    case files = "Files", library = "Library", tagQueue = "Tag Queue", tags = "Tags", review = "Review Queue"
    var id: String { rawValue }
}

struct SettingsView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var page: SettingsPage = .files

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsPage.allCases) { p in
                    Button { page = p } label: {
                        Text(p.rawValue).font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 9)
                            .foregroundStyle(page == p ? Theme.orangeText : Theme.text)
                            .background(RoundedRectangle(cornerRadius: 8).fill(page == p ? Theme.orangeBg : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(page == p ? Color(hex: 0x5A4318) : Color.clear))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.vertical, 20).padding(.horizontal, 12)
            .frame(width: 220)
            .background(Theme.panel)
            Rectangle().fill(Theme.border).frame(width: 1)
            Group {
                switch page {
                case .files: FilesSettings()
                case .library: LibrarySettings()
                case .tagQueue: TagQueueSettings()
                case .tags: TagsSettings()
                case .review: ReviewSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Theme.window)
    }
}

// MARK: Shared pieces

struct SettingsPageView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.system(size: 26, weight: .semibold))
                content
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

struct Card<Content: View>: View {
    let title: String
    var subtitle: String = ""
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title).font(.system(size: 16, weight: .semibold))
                if !subtitle.isEmpty { Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted) }
            }
            content
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
    }
}

struct FolderRow: View {
    @Binding var path: String
    var body: some View {
        HStack(spacing: 8) {
            Text(path).font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderStrong))
            Button("Change…") {
                let p = NSOpenPanel()
                p.canChooseDirectories = true; p.canChooseFiles = false
                p.directoryURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                if p.runModal() == .OK, let u = p.url {
                    path = (u.path as NSString).abbreviatingWithTildeInPath
                }
            }
        }
    }
}

func note(_ s: String) -> some View {
    Text(s).font(.system(size: 13)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
}

// MARK: Files

struct FilesSettings: View {
    @EnvironmentObject var store: LibraryStore
    var body: some View {
        SettingsPageView(title: "Files") {
            Card(title: "Apple Music", subtitle: "\(store.tracks.count.formatted()) tracks") {
                note("TrackTag works on the library Music has open. Tags, titles and energy are always written through Music.")
            }
            Card(title: "MediaHuman rips", subtitle: "RIP") {
                FolderRow(path: $store.settings.ripFolder)
                note("MediaHuman adds new rips to Music itself. A better rip of a queued track is offered as a replacement.")
                Toggle("Watch for replacements", isOn: $store.settings.watchRip)
            }
            Card(title: "Artist downloads", subtitle: "DL") {
                FolderRow(path: $store.settings.dlFolder)
                note("Year folders (2025, 2026 …). TrackTag watches this folder only, never Downloads.")
                Toggle("Watch for replacements", isOn: $store.settings.watchDL)
                Toggle("Copy new tracks to “Automatically Add to Music” (replacements never go there)", isOn: $store.settings.copyNewDLToAutoAdd)
            }
            Card(title: "Replaced and deleted files") {
                note("~/Music/TrackTag/Replaced and ~/Music/TrackTag/Deleted")
                Stepper("Keep for \(store.settings.keepReplacedDays) days", value: $store.settings.keepReplacedDays, in: 7...365, step: 7)
            }
            Card(title: "Before bulk changes") {
                Toggle("Save an undo file first", isOn: $store.settings.backupBeforeBulk)
                note("Undo files go in ~/Music/TrackTag. Revert one with tracktag-migrate.js revert <file>.")
            }
        }
    }
}

// MARK: Library

struct LibrarySettings: View {
    @EnvironmentObject var store: LibraryStore
    var body: some View {
        SettingsPageView(title: "Library") {
            Card(title: "Tracks") {
                Toggle("Leave out long mixes (Grouping = MIX)", isOn: $store.settings.leaveOutMixes)
                note("Takes effect the next time TrackTag opens.")
            }
            Card(title: "Default columns") {
                note("Right-click the Library’s column headers to show or hide columns (Energy, Remixer, Source, Released).")
            }
            Card(title: "Scanning", subtitle: "\(store.ceilings.count.formatted()) of \(store.tracks.count.formatted()) tracks scanned") {
                Toggle("Scan new tracks when they arrive", isOn: $store.settings.scanNewTracks)
                Toggle("Scan the whole library in the background", isOn: $store.settings.scanInBackground)
                if let p = store.scanProgress { ProgressView(value: Double(p.done), total: Double(p.total)) }
                Button("Rescan library") { store.scanCache = ScanCache(); store.scanCache.save(); store.startScan() }
            }
        }
    }
}

// MARK: Tag Queue

struct TagQueueSettings: View {
    @EnvironmentObject var store: LibraryStore
    var body: some View {
        SettingsPageView(title: "Tag Queue") {
            Card(title: "Needs tags when") {
                note("Always: tracks not yet saved once on the Tag screen, and titles with !review!.")
                Stepper("It was added in the last \(store.settings.newImportDays) days", value: $store.settings.newImportDays, in: 1...180)
                Stepper("Fewer than \(store.settings.needsTagsPercent)% of the 12 categories are filled",
                        value: $store.settings.needsTagsPercent, in: 0...100, step: 5)
                Toggle("It has no album art", isOn: $store.settings.noArtNeedsTags)
                Stepper("Also bring back the \(store.settings.reappraiseCount) oldest-modified tracks each launch",
                        value: $store.settings.reappraiseCount, in: 0...50)
            }
        }
    }
}

// MARK: Review Queue

struct ReviewSettings: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        SettingsPageView(title: "Review Queue") {
            Card(title: "Needs review when") {
                note("Always: tracks flagged in the title with !text!.")
                Toggle("MP3 graded Poor", isOn: $store.settings.flagPoorMP3)
                Toggle("Only if Energy 3+ (keeps the queue to tracks you play)", isOn: $store.settings.poorOnlyPlayed)
                    .padding(.leading, 24)
                Toggle("WAV graded Poor (fake lossless)", isOn: $store.settings.flagPoorWAV)
                Toggle("File at risk: in the Trash or Downloads, or missing", isOn: $store.settings.flagAtRisk)
            }
            Card(title: "Sound grades", subtitle: "graded by file type, from the highest frequency with real sound") {
                GradeSlider(label: "MP3", kind: .mp3, value: $store.settings.mp3Cutoff,
                            desc: "sounds like 128 kbps or worse")
                GradeSlider(label: "WAV", kind: .wav, value: $store.settings.wavCutoff,
                            desc: "made from a lossy file")
                note("For reference: 128 kbps ≈ 16 kHz · 192 ≈ 19 · 320 ≈ 20 · lossless ≈ 22. Each histogram row doubles: 1–10 tracks, 11–20, 21–40 …")
            }
        }
    }
}

/// Cut-off slider with a log-scale block histogram of the library above it.
struct GradeSlider: View {
    @EnvironmentObject var store: LibraryStore
    let label: String
    let kind: FileKind
    @Binding var value: Double
    let desc: String

    private let lo = 14.0, hi = 23.0
    private static let rows = [0, 10, 20, 40, 80, 160, 320]

    private var bins: [Int] {
        var b = [Int](repeating: 0, count: Int((hi - lo) * 2))
        for t in store.tracks where t.kind == kind {
            guard let c = store.ceilings[t.id] else { continue }
            let i = min(b.count - 1, max(0, Int((c - lo) * 2)))
            b[i] += 1
        }
        return b
    }

    var body: some View {
        let b = bins
        let poorCount = store.tracks.filter { $0.kind == kind && (store.ceilings[$0.id] ?? 99) < value }.count
        let total = store.tracks.filter { $0.kind == kind }.count
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(label).font(.system(size: 11, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.grey)).foregroundStyle(Color(hex: 0x0B0C0D))
                Text("Poor below ") + Text(String(format: "%.1f kHz", value)).bold()
                Text(desc).font(.system(size: 13)).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(poorCount) of \(total) Poor").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(b.indices, id: \.self) { i in
                    let binLo = lo + Double(i) / 2
                    VStack(spacing: 2) {
                        ForEach(Self.rows.indices.reversed(), id: \.self) { r in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(b[i] > Self.rows[r] ? (binLo < value ? Color(hex: 0xC2454A) : Color(hex: 0x2E9E5B)) : Color(hex: 0x202227))
                                .frame(height: 6)
                        }
                    }
                    .help("\(String(format: "%.1f", binLo))–\(String(format: "%.1f", binLo + 0.5)) kHz: \(b[i]) tracks")
                }
            }
            Slider(value: $value, in: lo...hi, step: 0.5)
            HStack {
                ForEach(Int(lo)...Int(hi), id: \.self) { k in
                    Text(k == Int(hi) ? "\(k) kHz" : "\(k)").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    if k < Int(hi) { Spacer() }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: Tags

struct TagsSettings: View {
    @EnvironmentObject var store: LibraryStore
    @State private var stop = TagStops.all[0]
    @State private var selected: String?
    @State private var renameText = ""
    @State private var mergeTarget = ""
    @State private var confirm: Action?

    enum Action: Identifiable { case rename, merge, retire; var id: Int { hashValue } }

    private var tagsInStop: [String] {
        var all: [String] = []
        for c in stop.categories { all += Catalog.tags[c] ?? [] }
        var seen = Set<String>()
        return all.filter { seen.insert($0).inserted && (store.tagCounts[$0] ?? 0) > 0 }
            .sorted { (store.tagCounts[$0] ?? 0) > (store.tagCounts[$1] ?? 0) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CATEGORIES").font(.system(size: 11)).tracking(0.7).foregroundStyle(Theme.muted).padding(.bottom, 6)
                ForEach(TagStops.all.filter { $0.rule != .freeText }) { s in
                    Button { stop = s; selected = nil } label: {
                        Text(s.id).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 8).fill(stop == s ? Theme.orangeBg : Color.clear))
                            .foregroundStyle(stop == s ? Theme.orangeText : Theme.text)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(16).frame(width: 200).background(Theme.card)
            Rectangle().fill(Theme.border).frame(width: 1)
            List(selection: $selected) {
                ForEach(tagsInStop, id: \.self) { t in
                    HStack {
                        Text(t)
                        if let home = Catalog.styleHome[t], stop.id == "Subgenre" {
                            Text(home).font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(String(store.tagCounts[t] ?? 0)).foregroundStyle(Theme.muted).monospacedDigit()
                    }
                    .tag(t)
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
            .frame(minWidth: 260)
            Rectangle().fill(Theme.border).frame(width: 1)
            detail.frame(width: 360).background(Theme.panel)
        }
    }

    @ViewBuilder private var detail: some View {
        if let tag = selected {
            let n = store.tagCounts[tag] ?? 0
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(stop.id.uppercased())").font(.system(size: 11)).tracking(0.7).foregroundStyle(Theme.muted)
                    Text(tag).font(.system(size: 26, weight: .semibold))
                    Text("\(n) tracks").foregroundStyle(Theme.muted)
                    if let home = Catalog.styleHome[tag] {
                        Text("Parent genre: \(home). Picking \(tag) also writes \(home).").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                    Divider()
                    Text("CHANGE THIS TAG").font(.system(size: 11)).tracking(0.7).foregroundStyle(Theme.muted)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rename").font(.system(size: 14, weight: .semibold))
                        Text("Rewrites the tag on all \(n) tracks. Update smart playlists that use it.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        HStack { TextField("New name", text: $renameText); Button("Rename…") { confirm = .rename }.disabled(renameText.isEmpty) }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Merge into another tag").font(.system(size: 14, weight: .semibold))
                        Text("\(tag) disappears; its \(n) tracks get the other tag instead.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        HStack {
                            Picker("", selection: $mergeTarget) {
                                Text("Choose…").tag("")
                                ForEach(tagsInStop.filter { $0 != tag }, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            Button("Merge…") { confirm = .merge }.disabled(mergeTarget.isEmpty)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Retire").font(.system(size: 14, weight: .semibold))
                        Text("Removes \(tag) from all \(n) tracks.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        Button("Retire…") { confirm = .retire }.foregroundStyle(Theme.redText)
                    }
                    if let p = store.bulkProgress { ProgressView("Writing through Music…", value: Double(p.done), total: Double(p.total)) }
                    if let m = store.bulkMessage { Text(m).font(.system(size: 12)).foregroundStyle(Color(hex: 0x7FE0A0)) }
                    Text("Every change saves an undo file first.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .alert(item: $confirm) { a in
                let what: String
                switch a {
                case .rename: what = "Rename \(tag) to \(renameText) on \(n) tracks?"
                case .merge: what = "Merge \(tag) into \(mergeTarget) on \(n) tracks?"
                case .retire: what = "Remove \(tag) from \(n) tracks?"
                }
                return Alert(title: Text(what), message: Text("Written through Music. An undo file is saved first."),
                             primaryButton: .destructive(Text("Do it")) {
                                 switch a {
                                 case .rename: store.bulkTagChange(tag, to: renameText); selected = nil
                                 case .merge: store.bulkTagChange(tag, to: mergeTarget); selected = nil
                                 case .retire: store.bulkTagChange(tag, to: nil); selected = nil
                                 }
                             },
                             secondaryButton: .cancel())
            }
        } else {
            Text("Pick a tag").foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
