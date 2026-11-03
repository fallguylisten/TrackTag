import SwiftUI
import TrackTagCore

/// Tag Queue: tracks waiting to be tagged, with the field editor on the right.
struct TagQueueView: View {
    @EnvironmentObject var store: LibraryStore
    let goToTag: () -> Void
    @State private var query = ""
    @State private var reasonFilter: QueueReason?

    private var queue: [(track: Track, reason: QueueReason)] { store.tagQueue }

    private var rows: [(track: Track, reason: QueueReason)] {
        queue.filter { row in
            if let r = reasonFilter, row.reason != r { return false }
            if query.isEmpty { return true }
            return row.track.titleText.localizedCaseInsensitiveContains(query)
                || row.track.artist.localizedCaseInsensitiveContains(query)
        }
    }

    private var items: [QueueItem] {
        var out: [QueueItem] = []
        for (i, row) in rows.enumerated() {
            out.append(QueueItem(id: row.track.id, number: i + 1, track: row.track, reason: row.reason))
        }
        return out
    }

    private func count(_ r: QueueReason?) -> Int {
        guard let r else { return queue.count }
        return queue.filter { $0.reason == r }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                listSide
                Rectangle().fill(Theme.border).frame(width: 1)
                FieldEditor(goToTag: goToTag)
                    .frame(width: 420)
                    .background(Theme.panel)
            }
            ShortcutBar(items: [("↑ ↓", "previous / next track"), ("⌘K", "clean up"), ("⌘S", "save fields"),
                                ("⌘Z", "revert"), ("Return", "start tagging this track"), ("⌘F", "search")])
        }
        .background(Theme.window)
        .onAppear { if store.currentID == nil { store.currentID = queue.first?.track.id } }
    }

    private var listSide: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Tag Queue").font(.system(size: 26, weight: .semibold))
                Text("\(queue.count.formatted()) tracks").font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField("Search the queue", text: $query).textFieldStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderStrong))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(nil, "All")
                    chip(.recheck, QueueReason.recheck.rawValue)
                    chip(.newImport, QueueReason.newImport.rawValue)
                    chip(.sent, QueueReason.sent.rawValue)
                    chip(.missing, QueueReason.missing.rawValue)
                    chip(.incomplete, QueueReason.incomplete.rawValue)
                    chip(.notReviewed, QueueReason.notReviewed.rawValue)
                    chip(.reappraise, QueueReason.reappraise.rawValue)
                }
            }
            List(selection: $store.currentID) {
                ForEach(items) { item in
                    QueueRow(number: item.number, track: item.track, reason: item.reason).tag(item.id)
                }
            }
            .listStyle(.plain)
            // Keep the columns from shifting when a filter changes the row count and the scrollbar
            // appears or disappears: the scrollbar sits over the list instead of taking width.
            .scrollIndicators(.never)
            .scrollContentBackground(.hidden)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .onKeyPress(.return) { goToTag(); return .handled }
        }
        .padding(24)
    }

    private func chip(_ r: QueueReason?, _ label: String) -> some View {
        FilterChip(label: label, count: count(r), selected: reasonFilter == r,
                   accent: Theme.teal, accentText: Theme.tealText, accentBg: Theme.tealBg) { reasonFilter = r }
    }
}

struct QueueItem: Identifiable {
    let id: String
    let number: Int
    let track: Track
    let reason: QueueReason
}

struct QueueRow: View {
    let number: Int
    let track: Track
    let reason: QueueReason
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)").font(.system(size: 12)).foregroundStyle(Theme.muted).frame(width: 36, alignment: .leading)
            Text(track.titleText).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(track.artist).foregroundStyle(Theme.muted).lineLimit(1).frame(width: 200, alignment: .leading)
            Text(track.bpmText).monospacedDigit().frame(width: 44, alignment: .leading)
            Text(track.addedText).font(.system(size: 12)).foregroundStyle(Theme.muted).frame(width: 76, alignment: .leading)
            HStack(spacing: 6) {
                Circle().fill(Self.color(reason)).frame(width: 7, height: 7)
                Text(reason.rawValue).font(.system(size: 12)).foregroundStyle(Theme.text2)
            }
            .frame(width: 150, alignment: .leading)
        }
        .font(.system(size: 13))
        .padding(.vertical, 3)
    }
    static func color(_ r: QueueReason) -> Color {
        switch r {
        case .recheck: return Theme.orange
        case .newImport: return Theme.teal
        case .sent: return Theme.tealText
        case .missing: return Theme.orangeText
        case .incomplete: return Color(hex: 0x8E9198)
        case .notReviewed: return Theme.text2
        case .reappraise: return Color(hex: 0xB39DFF)
        }
    }
}

/// Right-hand panel: Clean Up, the editable fields, Before/After, Save.
struct FieldEditor: View {
    @EnvironmentObject var store: LibraryStore
    let goToTag: () -> Void

    @State private var loadedID: String?
    @State private var name = ""
    @State private var version = ""
    @State private var original = false
    @State private var notes = ""
    @State private var flags: [String] = []
    @State private var artists = ""
    @State private var remixer = ""
    @State private var source = "RIP"
    @State private var year = ""

    private var track: Track? { store.tracks.first { $0.id == store.currentID } }

    private var editedTitle: String {
        CleanFields(name: name, version: original ? "" : version,
                    notes: notes.isEmpty ? [] : [notes], flags: flags,
                    artists: [], remixer: "").title
    }

    var body: some View {
        ScrollView {
            if let t = track {
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("Selected track")
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(t.hasArtwork ? Theme.orange.opacity(0.35) : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.hasArtwork ? Color.clear : Theme.muted))
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.titleText).font(.system(size: 18, weight: .semibold)).lineLimit(2)
                            Text(t.artist).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                    }
                    Divider()
                    sectionLabel("Field edit")
                    Button(action: cleanUp) {
                        HStack { Image(systemName: "wand.and.stars"); Text("Clean Up"); Keycap(key: "⌘K") }
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .foregroundStyle(Theme.tealText)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tealBg))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.teal))
                    }
                    .buttonStyle(.plain).keyboardShortcut("k", modifiers: .command)

                    field("Title", text: $name)
                    HStack(alignment: .bottom, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Version").font(.system(size: 12)).foregroundStyle(Theme.muted)
                                Spacer()
                                Toggle("original", isOn: $original).toggleStyle(.checkbox).font(.system(size: 11))
                            }
                            TextField("e.g. Loft Mix", text: $version).textFieldStyle(.roundedBorder).disabled(original)
                        }
                        field("Notes", text: $notes, placeholder: "e.g. 108 > 127")
                    }
                    HStack(spacing: 10) {
                        field("Artists", text: $artists)
                        field("Remixer", text: $remixer)
                    }
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Source").font(.system(size: 12)).foregroundStyle(Theme.muted)
                            Picker("", selection: $source) {
                                Text("RIP · MediaHuman rip").tag("RIP")
                                Text("DL · artist download").tag("DL")
                                Text("OWN · my own").tag("OWN")
                            }
                            .labelsHidden()
                        }
                        field("Release year", text: $year, placeholder: "YEAR")
                    }
                    beforeAfter(t)
                    HStack(spacing: 10) {
                        Button(action: { load(t) }) {
                            HStack { Text("Revert"); Keycap(key: "⌘Z") }.frame(maxWidth: .infinity).frame(height: 36)
                        }
                        .buttonStyle(.bordered).keyboardShortcut("z", modifiers: .command)
                        Button(action: save) {
                            HStack { Text("Save fields"); Keycap(key: "⌘S") }.frame(maxWidth: .infinity).frame(height: 36)
                        }
                        .buttonStyle(.bordered).keyboardShortcut("s", modifiers: .command)
                    }
                    if let m = store.saveMessage { Text(m).font(.system(size: 12)).foregroundStyle(Theme.muted) }
                    Button(action: { save(); goToTag() }) {
                        HStack { Text("Start tagging"); Keycap(key: "⏎") }
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .foregroundStyle(Color(hex: 0x06201F))
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.teal))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .onAppear { load(t) }
                .onChange(of: store.currentID) { if let n = track { load(n) } }
            } else {
                Text("Pick a track from the queue").foregroundStyle(Theme.muted).padding(40)
            }
        }
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 12)).tracking(0.7).foregroundStyle(Theme.muted)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.muted)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func beforeAfter(_ t: Track) -> some View {
        let before = "\(t.artist) – \(t.title.display)"
        let after = "\(artists) – \(CleanFields(name: name, version: original ? "" : version, notes: notes.isEmpty ? [] : [notes], flags: [], artists: [], remixer: "").title)"
        return VStack(spacing: 8) {
            box("BEFORE", before, Theme.orange)
            box("AFTER", after, Theme.teal)
        }
    }

    private func box(_ label: String, _ text: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10)).tracking(0.7).foregroundStyle(c)
            Text(text).font(.system(size: 12)).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(c.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }

    /// Fills the fields from the track exactly as it is (no cleanup).
    private func load(_ t: Track) {
        let raw = Cleanup.clean(title: t.title.raw, artist: t.artist, composer: t.composer)
        // Keep the current name as-is until Clean Up is pressed; only split out what's already in house format.
        loadedID = t.id
        name = raw.name
        version = raw.version
        original = raw.version.isEmpty
        notes = raw.notes.first ?? ""
        flags = raw.flags
        artists = t.artist
        remixer = t.composer
        source = ["RIP", "DL", "OWN"].contains(t.grouping) ? t.grouping : "RIP"
        year = t.year > 0 ? String(t.year) : ""
        store.saveMessage = nil
    }

    private func cleanUp() {
        guard let t = track else { return }
        let c = Cleanup.clean(title: editedTitle, artist: artists, composer: remixer)
        name = c.name
        version = c.version
        original = c.isOriginal
        artists = c.artist
        remixer = c.remixer.isEmpty ? t.composer : c.remixer
        notes = c.notes.first ?? notes
    }

    private func save() {
        guard let id = store.currentID else { return }
        store.save(id, title: editedTitle, artist: artists, remixer: remixer, source: source, year: Int(year) ?? 0)
    }
}
