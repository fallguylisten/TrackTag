import SwiftUI
import TrackTagCore

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All", review = "Needs review", tags = "Needs tags", none = "Nothing to do"
    var id: String { rawValue }
}

/// Library tab: every track (minus long mixes), with Next step, selection and the two
/// "send to queue" buttons above the player.
struct LibraryView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var query = ""
    @State private var filter: LibraryFilter = .all
    @State private var selection = Set<Track.ID>()
    @State private var sortOrder = [KeyPathComparator(\Track.addedSort, order: .reverse)]
    @SceneStorage("libraryColumns") private var columns = TableColumnCustomization<Track>()

    private var rows: [Track] {
        store.tracks.filter(matches).sorted(using: sortOrder)
    }

    private func matches(_ t: Track) -> Bool {
        let step: NextStep = store.nextStep[t.id] ?? .none
        switch filter {
        case .all: break
        case .review: if step != .needsReview { return false }
        case .tags: if step != .needsTags { return false }
        case .none: if step != .none { return false }
        }
        if query.isEmpty { return true }
        if t.titleText.localizedCaseInsensitiveContains(query) { return true }
        if t.artist.localizedCaseInsensitiveContains(query) { return true }
        if t.genre.localizedCaseInsensitiveContains(query) { return true }
        return t.tagsText.localizedCaseInsensitiveContains(query)
    }

    private func count(_ f: LibraryFilter) -> Int {
        switch f {
        case .all: return store.tracks.count
        case .review: return store.nextStep.values.filter { $0 == .needsReview }.count
        case .tags: return store.nextStep.values.filter { $0 == .needsTags }.count
        case .none: return store.nextStep.values.filter { $0 == .none }.count
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Library").font(.system(size: 26, weight: .semibold))
                    Text("\(store.tracks.count.formatted()) tracks").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    if store.loading { ProgressView().controlSize(.small) }
                }
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                        TextField("Search the library", text: $query).textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.field))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderStrong))
                    ForEach(LibraryFilter.allCases) { f in
                        FilterChip(label: f.rawValue, count: count(f), selected: filter == f) { filter = f }
                    }
                }
                if let e = store.error { Text(e).foregroundStyle(Theme.redText) }
                table
            }
            .padding(24)

            if !selection.isEmpty { selectionBar }
            ShortcutBar(items: [("↑ ↓", "previous / next track"), ("⇧ ↑ ↓", "select several"),
                                ("⌘ click", "add / remove"), ("⌘A", "select all"), ("esc", "clear selection"),
                                ("⌘F", "search")])
        }
        .background(Theme.window)
    }

    // Each column is its own property so the compiler type-checks them one at a time.

    private var table: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columns) {
            checkColumn
            artColumn
            titleColumn
            artistColumn
            genreColumn
            bpmColumn
            energyColumn
            tagsColumn
            Group {
                addedColumn
                taggedColumn
                nextColumn
                remixerColumn
                sourceColumn
                releasedColumn
            }
        }
        .onExitCommand { selection.removeAll() }
        .scrollContentBackground(.hidden)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }

    private var checkColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("") { (t: Track) in CheckCell(on: selection.contains(t.id)) { toggle(t.id) } }
            .width(22).customizationID("check").disabledCustomizationBehavior(.all)
    }
    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }
    private var artColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Art") { (t: Track) in ArtCell(has: t.hasArtwork) }
            .width(30).customizationID("art")
    }
    private var titleColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Title", value: \Track.titleText) { (t: Track) in Text(t.titleText).lineLimit(1) }
            .customizationID("title").disabledCustomizationBehavior(.visibility)
    }
    private var artistColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Artist", value: \Track.artist) { (t: Track) in Text(t.artist).foregroundStyle(Theme.muted).lineLimit(1) }
            .customizationID("artist")
    }
    private var genreColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Genre", value: \Track.genre) { (t: Track) in Text(t.genre).lineLimit(1) }
            .width(min: 70, ideal: 90).customizationID("genre")
    }
    private var bpmColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("BPM", value: \Track.bpm) { (t: Track) in Text(t.bpmText).monospacedDigit() }
            .width(44).customizationID("bpm")
    }
    private var energyColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Energy", value: \Track.rating) { (t: Track) in EnergyCell(energy: t.energy) }
            .width(56).customizationID("energy").defaultVisibility(.hidden)
    }
    private var tagsColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Tags") { (t: Track) in
            Text(t.tagsText).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
        }
        .customizationID("tags")
    }
    private var addedColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Added", value: \Track.addedSort) { (t: Track) in
            Text(t.addedText).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .width(76).customizationID("added")
    }
    private var taggedColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Tagged", value: \Track.taggedPercent) { (t: Track) in
            Text("\(t.taggedPercent)%").font(.system(size: 12)).monospacedDigit()
                .foregroundStyle(t.taggedPercent >= 50 ? Theme.text2 : Theme.muted)
        }
        .width(56).customizationID("tagged")
    }
    private var nextColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Next step") { (t: Track) in NextStepPill(step: store.nextStep[t.id] ?? .none) }
            .width(116).customizationID("next")
    }
    private var remixerColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Remixer", value: \Track.composer) { (t: Track) in Text(t.composer).lineLimit(1) }
            .customizationID("remixer").defaultVisibility(.hidden)
    }
    private var sourceColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Source", value: \Track.grouping) { (t: Track) in Text(t.grouping) }
            .width(56).customizationID("source").defaultVisibility(.hidden)
    }
    private var releasedColumn: some TableColumnContent<Track, KeyPathComparator<Track>> {
        TableColumn("Released", value: \Track.year) { (t: Track) in Text(t.year > 0 ? String(t.year) : "") }
            .width(64).customizationID("released").defaultVisibility(.hidden)
    }

    private var selectionBar: some View {
        let picked = store.tracks.filter { selection.contains($0.id) }
        return HStack(spacing: 16) {
            Button { store.send(Array(selection), to: .review) } label: {
                HStack(spacing: 8) { Text("‹").font(.system(size: 18)); Text("Send to Review Queue"); Keycap(key: "⌘←") }
                    .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 18).frame(height: 40)
                    .foregroundStyle(Theme.redText)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.redBg))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.red))
            }
            .buttonStyle(.plain).keyboardShortcut(.leftArrow, modifiers: .command)

            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("\(selection.count) SELECTED").font(.system(size: 11)).tracking(0.6).foregroundStyle(Theme.muted)
                    Button { selection.removeAll() } label: {
                        HStack(spacing: 5) { Text("Clear"); Text("esc").foregroundStyle(Theme.muted) }
                            .font(.system(size: 11)).padding(.horizontal, 6).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.borderStrong))
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 4) {
                    Text(picked.first?.title.display ?? "").font(.system(size: 17, weight: .semibold)).lineLimit(1)
                    if picked.count > 1 { Text("+ \(picked.count - 1) more").foregroundStyle(Theme.muted) }
                }
            }
            Spacer()

            Button { store.send(Array(selection), to: .tags) } label: {
                HStack(spacing: 8) { Text("Send to Tag Queue"); Keycap(key: "⌘→"); Text("›").font(.system(size: 18)) }
                    .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 18).frame(height: 40)
                    .foregroundStyle(Theme.tealText)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tealBg))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.teal))
            }
            .buttonStyle(.plain).keyboardShortcut(.rightArrow, modifiers: .command)
        }
        .padding(.horizontal, 24).padding(.vertical, 10)
        .background(Theme.panel)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

struct CheckCell: View {
    let on: Bool
    let toggle: () -> Void
    var body: some View {
        Image(systemName: on ? "checkmark.square.fill" : "square")
            .foregroundStyle(on ? Theme.orange : Theme.muted)
            .contentShape(Rectangle())
            .onTapGesture(perform: toggle)
    }
}

struct ArtCell: View {
    let has: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(has ? Theme.orange.opacity(0.35) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(has ? Color.clear : Theme.muted, lineWidth: 1))
            .frame(width: 22, height: 22)
            .help(has ? "Has artwork" : "No album art")
    }
}

struct EnergyCell: View {
    let energy: Int
    var body: some View {
        Text(energy > 0 ? String(energy) : "–").font(.system(size: 12, weight: .bold))
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.energyColor(energy)))
            .foregroundStyle(Color(hex: 0x0B0C0D))
    }
}

struct NextStepPill: View {
    let step: NextStep
    var body: some View {
        switch step {
        case .needsReview: pill("Needs review", Theme.redBg, Theme.red, Theme.redText)
        case .needsTags: pill("Needs tags", Theme.tealBg, Color(hex: 0x2F8F93), Theme.tealText)
        case .none: Text("—").foregroundStyle(Color(hex: 0x5A5D63))
        }
    }
    private func pill(_ t: String, _ bg: Color, _ border: Color, _ fg: Color) -> some View {
        Text(t).font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 3)
            .foregroundStyle(fg)
            .background(Capsule().fill(bg))
            .overlay(Capsule().stroke(border))
    }
}
