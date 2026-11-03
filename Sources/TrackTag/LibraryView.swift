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
        store.tracks.filter { t in
            let step = store.nextStep[t.id] ?? .none
            switch filter {
            case .all: break
            case .review: if step != .needsReview { return false }
            case .tags: if step != .needsTags { return false }
            case .none: if step != .none { return false }
            }
            return query.isEmpty
                || t.title.display.localizedCaseInsensitiveContains(query)
                || t.artist.localizedCaseInsensitiveContains(query)
                || t.genre.localizedCaseInsensitiveContains(query)
                || t.comments.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
        .sorted(using: sortOrder)
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

    private var table: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columns) {
            TableColumn("") { (t: Track) in
                let on = selection.contains(t.id)
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundStyle(on ? Theme.orange : Theme.muted)
                    .contentShape(Rectangle())
                    .onTapGesture { if on { selection.remove(t.id) } else { selection.insert(t.id) } }
            }
            .width(22).customizationID("check").disabledCustomizationBehavior(.all)

            TableColumn("Art") { (t: Track) in
                RoundedRectangle(cornerRadius: 4)
                    .fill(t.hasArtwork ? Theme.orange.opacity(0.35) : .clear)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(t.hasArtwork ? .clear : Theme.muted, lineWidth: 1))
                    .frame(width: 22, height: 22)
                    .help(t.hasArtwork ? "Has artwork" : "No album art")
            }
            .width(30).customizationID("art")

            Group {
            TableColumn("Title", value: \.title.display) { t in Text(t.title.display).lineLimit(1) }
                .customizationID("title").disabledCustomizationBehavior(.visibility)
            TableColumn("Artist", value: \.artist) { t in Text(t.artist).foregroundStyle(Theme.muted).lineLimit(1) }
                .customizationID("artist")
            TableColumn("Genre", value: \.genre).width(min: 70, ideal: 90).customizationID("genre")
            TableColumn("BPM", value: \.bpm) { t in Text(t.bpm > 0 ? "\(t.bpm)" : "").monospacedDigit() }
                .width(44).customizationID("bpm")
            TableColumn("Energy", value: \.rating) { t in
                Text(t.energy > 0 ? "\(t.energy)" : "–").font(.system(size: 12, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.energyColor(t.energy)))
                    .foregroundStyle(Color(hex: 0x0B0C0D))
            }
            .width(56).customizationID("energy").defaultVisibility(.hidden)
            }
            Group {
            TableColumn("Tags") { t in
                Text(t.comments.tags.joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            .customizationID("tags")
            TableColumn("Added", value: \.addedSort) { t in
                Text(t.dateAdded.map { $0.formatted(.dateTime.month(.abbreviated).year()) } ?? "")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .width(76).customizationID("added")
            TableColumn("Tagged", value: \.taggedPercent) { t in
                Text("\(t.taggedPercent)%").font(.system(size: 12)).monospacedDigit()
                    .foregroundStyle(t.taggedPercent >= 50 ? Theme.text2 : Theme.muted)
            }
            .width(56).customizationID("tagged")
            TableColumn("Next step") { t in NextStepPill(step: store.nextStep[t.id] ?? .none) }
                .width(116).customizationID("next")
            TableColumn("Remixer", value: \.composer).customizationID("remixer").defaultVisibility(.hidden)
            TableColumn("Source", value: \.grouping).width(56).customizationID("source").defaultVisibility(.hidden)
            TableColumn("Released", value: \.year) { t in Text(t.year > 0 ? "\(t.year)" : "") }
                .width(64).customizationID("released").defaultVisibility(.hidden)
            }
        }
        .onExitCommand { selection.removeAll() }
        .scrollContentBackground(.hidden)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
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
