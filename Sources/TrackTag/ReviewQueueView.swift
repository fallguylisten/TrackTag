import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TrackTagCore

/// Review Queue: tracks to replace (poor sound, flags, files at risk) with the replace flow.
struct ReviewQueueView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var player: Player
    @State private var selected: String?
    @State private var reasonFilter: ReviewReason?
    @State private var query = ""

    private var items: [ReviewItem] {
        store.reviewItems.filter { item in
            if let r = reasonFilter, item.reason != r { return false }
            if query.isEmpty { return true }
            return item.track.titleText.localizedCaseInsensitiveContains(query)
                || item.track.artist.localizedCaseInsensitiveContains(query)
        }
    }

    private func count(_ r: ReviewReason?) -> Int {
        guard let r else { return store.reviewItems.count }
        return store.reviewItems.filter { $0.reason == r }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                listSide
                Rectangle().fill(Theme.border).frame(width: 1)
                ReviewPanel(trackID: selected, next: { goNext() })
                    .frame(width: 420).background(Theme.panel)
            }
            ShortcutBar(items: [("↑ ↓", "previous / next track"), ("⌘O", "find replacement"),
                                ("Return", "make replacement"), ("N", "not a match"), ("Space", "play / pause"), ("⌘F", "search")])
        }
        .background(Theme.window)
        .onAppear { if selected == nil { selected = items.first?.id }; store.focusID = selected }
    }

    private func goNext() {
        let ids = items.map(\.id)
        guard let cur = selected, let i = ids.firstIndex(of: cur) else { return }
        // Replaced tracks stay listed (as "Replaced") until you quit, so step past it.
        if i + 1 < ids.count { selected = ids[i + 1] }
    }

    private var listSide: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Review Queue").font(.system(size: 26, weight: .semibold))
                Text("\(store.reviewItems.count) tracks").font(.system(size: 13)).foregroundStyle(Theme.muted)
                if let p = store.scanProgress {
                    Text("Scanning sound quality… \(p.done) of \(p.total)").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Search the review queue", text: $query).textFieldStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.field))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderStrong))
            HStack(spacing: 8) {
                chip(nil, "All")
                chip(.poor, ReviewReason.poor.rawValue)
                chip(.flagged, ReviewReason.flagged.rawValue)
                chip(.atRisk, ReviewReason.atRisk.rawValue)
                chip(.sent, ReviewReason.sent.rawValue)
                if count(.replaced) > 0 { chip(.replaced, ReviewReason.replaced.rawValue) }
            }
            HStack(spacing: 12) {
                Text("#").frame(width: 30, alignment: .leading)
                Text("TITLE").frame(maxWidth: .infinity, alignment: .leading)
                Text("ARTIST").frame(width: 170, alignment: .leading)
                Text("SOURCE").frame(width: 52, alignment: .leading)
                Text("BITRATE").frame(width: 60, alignment: .leading)
                Text("CEILING").frame(width: 70, alignment: .leading)
                Text("WHY IT'S HERE").frame(width: 170, alignment: .leading)
            }
            .font(.system(size: 11)).tracking(0.6).foregroundStyle(Theme.muted).padding(.horizontal, 10)
            List(selection: $selected) {
                ForEach(items) { item in ReviewRow(item: item).tag(item.id) }
            }
            .contextMenu(forSelectionType: String.self, menu: { _ in }, primaryAction: { ids in
                if let id = ids.first, let t = store.tracks.first(where: { $0.id == id }) { player.play(t) }
            })
            .onChange(of: selected) { store.focusID = selected }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
        .padding(24)
    }

    private func chip(_ r: ReviewReason?, _ label: String) -> some View {
        FilterChip(label: label, count: count(r), selected: reasonFilter == r,
                   accent: Theme.red, accentText: Theme.redText, accentBg: Theme.redBg) { reasonFilter = r }
    }
}

struct ReviewRow: View {
    @EnvironmentObject var store: LibraryStore
    let item: ReviewItem

    var body: some View {
        let t = item.track
        let ceiling = store.ceilings[t.id]
        let poor = store.grade(t) == .poor
        return HStack(spacing: 12) {
            Text(String(item.number)).font(.system(size: 12)).foregroundStyle(Theme.muted).frame(width: 30, alignment: .leading)
            Text(t.titleText).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(t.artist).foregroundStyle(Theme.muted).lineLimit(1).frame(width: 170, alignment: .leading)
            Text(t.grouping).font(.system(size: 12)).frame(width: 52, alignment: .leading)
            Text(t.bitrate > 0 ? String(t.bitrate) : "—").font(.system(size: 12)).monospacedDigit()
                .foregroundStyle(Theme.text2).frame(width: 60, alignment: .leading)
            Text(ceiling.map { String(format: "%.1f kHz", $0) } ?? "—").font(.system(size: 12)).monospacedDigit()
                .foregroundStyle(ceiling == nil ? Theme.muted : (poor ? Theme.redText : Color(hex: 0x7FE0A0)))
                .frame(width: 70, alignment: .leading)
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(item.reason == .flagged ? item.detail.capitalized : item.reason.rawValue)
                    .font(.system(size: 12)).foregroundStyle(Theme.text2).lineLimit(1)
            }
            .frame(width: 170, alignment: .leading)
        }
        .font(.system(size: 13)).padding(.vertical, 3)
    }

    private var color: Color {
        switch item.reason {
        case .poor: return Color(hex: 0xEC7F4B)
        case .flagged: return Color(hex: 0xD0609E)
        case .atRisk: return Color(hex: 0xB39DFF)
        case .sent: return Theme.redText
        case .replaced: return Color(hex: 0x2BD46A)
        }
    }
}

/// Side panel: spectrogram, flag, replacement comparison and actions.
struct ReviewPanel: View {
    @EnvironmentObject var store: LibraryStore
    let trackID: String?
    let next: () -> Void

    @State private var image: NSImage?
    @State private var candidate: URL?
    @State private var candidateResult: SpectrumScanner.Result?
    @State private var confirmDelete = false
    @State private var customFlag = ""
    @State private var askCustom = false

    private static let flags = ["poor quality", "unexpected sounds", "explicit", "clean", "replace"]

    private var track: Track? { store.tracks.first { $0.id == trackID } }

    var body: some View {
        if let t = track {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let m = store.reviewMessage { banner(m) }
                        label("Selected track")
                        HStack(spacing: 12) {
                            ArtView(id: t.id, has: t.hasArtwork, size: 48, corner: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.titleText).font(.system(size: 18, weight: .semibold)).lineLimit(2)
                                Text("\(t.artist) · \(t.kind.rawValue.uppercased()) · \(t.bitrate) kbps · \(t.grouping)")
                                    .font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                        }
                        flagMenu(t)
                        label("Spectrogram")
                        spectrogram(image, ceiling: store.ceilings[t.id], height: 130)
                        verdict(t)
                        if let c = candidate { comparison(t, c) }
                    }
                    .padding(20)
                }
                actions(t)
            }
            .task(id: t.id) { await loadImage(t) }
            .confirmationDialog("Delete \(t.titleText) from your library?", isPresented: $confirmDelete) {
                Button("Delete from library", role: .destructive) { store.deleteTrack(t.id); next() }
            } message: {
                Text("It’s removed from Music and every playlist. The file moves to ~/Music/TrackTag/Deleted. Rekordbox and Serato will show it as missing.")
            }
            .alert("Custom flag", isPresented: $askCustom) {
                TextField("e.g. wrong version", text: $customFlag)
                Button("Add") { if !customFlag.isEmpty { store.setFlag(t.id, to: customFlag.lowercased()) }; customFlag = "" }
                Button("Cancel", role: .cancel) { customFlag = "" }
            }
        } else {
            Text("Nothing selected").foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Pieces

    private func label(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 12)).tracking(0.7).foregroundStyle(Theme.muted)
    }

    private func banner(_ m: String) -> some View {
        HStack(alignment: .top) {
            Text(m)
            if store.lastReplace != nil {
                Spacer()
                Button("Undo") { store.undoLastReplace() }.buttonStyle(.bordered).controlSize(.small)
            }
        }
        .font(.system(size: 13)).foregroundStyle(Color(hex: 0x7FE0A0))
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x11261A)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0x1F5A3A)))
    }

    private func flagMenu(_ t: Track) -> some View {
        let current = t.title.flags.first { $0.lowercased() != "review" }
        return VStack(alignment: .leading, spacing: 6) {
            label("Flag")
            Menu {
                ForEach(Self.flags, id: \.self) { f in
                    Button(f.capitalized) { store.setFlag(t.id, to: f) }
                }
                Divider()
                Button("Add custom flag…") { askCustom = true }
                Button("No flag (leave the Review Queue)") { store.setFlag(t.id, to: nil) }
            } label: {
                Text(current?.capitalized ?? "No flag").frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func spectrogram(_ img: NSImage?, ceiling: Double?, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x0B0C0D))
            if let img {
                Image(nsImage: img).resizable().interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let c = ceiling {
                GeometryReader { g in
                    let y = g.size.height * (1 - min(1, c / 22.05))
                    Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: g.size.width, y: y)) }
                        .stroke(Theme.redText, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    Text(String(format: "%.1f kHz", c)).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.redText).position(x: g.size.width - 34, y: max(10, y - 9))
                }
            }
        }
        .frame(height: height)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
    }

    private func verdict(_ t: Track) -> some View {
        let g = store.grade(t)
        let text: String
        switch g {
        case .poor: text = t.kind == .wav ? "Fake lossless · made from a lossy file" : "Poor · sounds like 128 kbps or worse"
        case .good: text = "Good"
        case .unknown: text = "Not scanned yet"
        }
        return Text(text).font(.system(size: 13, weight: g == .poor ? .semibold : .regular))
            .foregroundStyle(g == .poor ? Theme.redText : Theme.text2)
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(g == .poor ? Theme.redBg : Theme.field))
    }

    private func comparison(_ t: Track, _ c: URL) -> some View {
        let newKind = c.pathExtension.uppercased()
        let newCeil = candidateResult?.ceilingKHz
        let newGrade: SoundGrade = store.cutoffs.grade(ceilingKHz: newCeil,
                                                        kind: c.pathExtension.lowercased() == "wav" ? .wav : .mp3)
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("REPLACEMENT FOUND").font(.system(size: 11)).tracking(0.7).foregroundStyle(Theme.tealText)
                Text(c.lastPathComponent).font(.system(size: 13)).lineLimit(2)
                Text(c.deletingLastPathComponent().path).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tealBg))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0x1F5558)))
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow { Text(""); Text("CURRENT").foregroundStyle(Theme.muted); Text("NEW").foregroundStyle(Theme.tealText) }
                    .font(.system(size: 11))
                GridRow { Text("Format").foregroundStyle(Theme.muted); Text(t.kind.rawValue.uppercased()); Text(newKind) }
                GridRow {
                    Text("Ceiling").foregroundStyle(Theme.muted)
                    Text(store.ceilings[t.id].map { String(format: "%.1f kHz", $0) } ?? "—")
                    Text(newCeil.map { String(format: "%.1f kHz", $0) } ?? "…")
                }
                GridRow {
                    Text("Sound").foregroundStyle(Theme.muted)
                    Text(store.grade(t) == .poor ? "Poor" : "Good")
                    Text(newCeil == nil ? "…" : (newGrade == .poor ? "Poor" : "Good"))
                        .foregroundStyle(newGrade == .poor ? Theme.redText : Color(hex: 0x7FE0A0))
                }
            }
            .font(.system(size: 13))
            HStack(spacing: 10) {
                spectrogram(image, ceiling: store.ceilings[t.id], height: 90)
                spectrogram(candidateResult?.image, ceiling: newCeil, height: 90)
            }
            Text("Keeps: tags · energy \(t.energy) · title & artists · plays · playlists · date added")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }

    private func actions(_ t: Track) -> some View {
        VStack(spacing: 8) {
            if candidate != nil {
                HStack(spacing: 8) {
                    Button { candidate = nil; candidateResult = nil } label: {
                        HStack { Text("Not a match"); Keycap(key: "N") }.frame(maxWidth: .infinity).frame(height: 36)
                    }
                    .buttonStyle(.bordered).keyboardShortcut("n", modifiers: [])
                    Button { pickFile() } label: {
                        HStack { Image(systemName: "folder"); Text("Find another…"); Keycap(key: "⌘O") }
                            .frame(maxWidth: .infinity).frame(height: 36)
                    }
                    .buttonStyle(.bordered).keyboardShortcut("o", modifiers: .command)
                }
            } else {
                Button { pickFile() } label: {
                    HStack { Image(systemName: "folder"); Text("Find replacement…"); Keycap(key: "⌘O") }
                        .frame(maxWidth: .infinity).frame(height: 40)
                }
                .buttonStyle(.bordered).keyboardShortcut("o", modifiers: .command)
            }
            Button {
                if let c = candidate { store.replace(t.id, with: c); candidate = nil; candidateResult = nil; next() }
            } label: {
                HStack { Text("Make replacement"); Keycap(key: "⏎") }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .foregroundStyle(candidate == nil ? Color(hex: 0x7A4A4C) : Color(hex: 0x1F0607))
                    .background(RoundedRectangle(cornerRadius: 10).fill(candidate == nil ? Color(hex: 0x241416) : Theme.red))
            }
            .buttonStyle(.plain).disabled(candidate == nil).keyboardShortcut(.return, modifiers: [])
            Button { confirmDelete = true } label: {
                HStack { Text("Delete from library…"); Keycap(key: "⌘⌫") }.font(.system(size: 13)).foregroundStyle(Theme.redText)
            }
            .buttonStyle(.plain).keyboardShortcut(.delete, modifiers: .command)
        }
        .padding(20)
        .background(Theme.panel)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    // MARK: Work

    private func loadImage(_ t: Track) async {
        image = nil; candidate = nil; candidateResult = nil
        guard let url = t.fileURL else { return }
        let r = await Task.detached(priority: .userInitiated) { SpectrumScanner.analyse(url, wantImage: true) }.value
        image = r?.image
        if let c = r?.ceilingKHz, store.ceilings[t.id] == nil { store.ceilings[t.id] = c }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/Crate")
        panel.message = "Pick the better copy of this track"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        candidate = url
        candidateResult = nil
        Task {
            let r = await Task.detached(priority: .userInitiated) { SpectrumScanner.analyse(url, wantImage: true) }.value
            candidateResult = r
        }
    }
}
