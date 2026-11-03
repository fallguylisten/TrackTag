import SwiftUI
import TrackTagCore

/// Tag tab: one track at a time, one category (stop) at a time.
/// Keys: letters toggle tags · 1–5 energy · ↑↓ category · ←→ previous / next track (saves) · Return next track.
struct TagView: View {
    @EnvironmentObject var store: LibraryStore

    @State private var stopIndex = 0
    @State private var editingID: String?
    @State private var comments = Comments()
    @State private var rating = 0
    @State private var dirty = false
    @State private var filter = ""
    @FocusState private var keysFocused: Bool
    @FocusState private var textFocused: Bool

    private static let letters = Array("QWERTYUIOPASDFGHJKLZXCVBNM")
    private static let energyNames = ["", "Sitting", "Chilling", "Moving", "Dancing", "Peaking"]

    private var queueIDs: [String] { store.tagQueue.map { $0.track.id } }
    private var track: Track? { store.tracks.first { $0.id == store.currentID } }
    private var stop: TagStop { TagStops.all[stopIndex] }

    var body: some View {
        VStack(spacing: 0) {
            if let t = track {
                header(t)
                HStack(spacing: 0) {
                    stopList.frame(width: 240).background(Theme.panel)
                    Rectangle().fill(Theme.border).frame(width: 1)
                    centre
                    Rectangle().fill(Theme.border).frame(width: 1)
                    energyPanel.frame(width: 200).background(Theme.panel)
                }
                .focusable()
                .focusEffectDisabled()
                .focused($keysFocused)
                .onKeyPress(phases: .down, action: handleKey)
                .onAppear { load(t); keysFocused = true; store.focusID = t.id }
                .onChange(of: store.currentID) { if let n = track { load(n); store.focusID = n.id } }
            } else {
                Text("Pick a track in the Tag Queue first").foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            ShortcutBar(items: [("A–Z", "toggle tag"), ("1–5", "energy"), ("↑ ↓", "category"),
                                ("← →", "previous / next track (saves)"), ("Return", "save, next track"), ("Space", "play / pause")])
        }
        .background(Theme.window)
    }

    // MARK: Header

    private func header(_ t: Track) -> some View {
        let idx = (queueIDs.firstIndex(of: t.id) ?? 0) + 1
        return HStack(spacing: 18) {
            ArtView(id: t.id, has: t.hasArtwork, size: 80, corner: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title.display.replacingOccurrences(of: t.title.version.map { " [\($0)]" } ?? "", with: ""))
                    .font(.system(size: 26, weight: .bold)).lineLimit(1)
                if let v = t.title.version { Text("[\(v)]").font(.system(size: 20)).foregroundStyle(Theme.muted).lineLimit(1) }
                Text(t.artist).foregroundStyle(Theme.text2).lineLimit(1)
                HStack(spacing: 12) {
                    if t.bpm > 0 { Text("BPM \(t.bpm)") }
                    if t.year > 0 { Text("Released \(String(t.year))") }
                    Text(t.grouping)
                }
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: 420, alignment: .leading)
            FlowTags(tags: comments.tags).frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                navButton("←") { move(-1) }
                Text("Track \(idx) of \(queueIDs.count)").font(.system(size: 13)).foregroundStyle(Theme.muted)
                navButton("→") { move(1) }
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(Theme.header)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private func navButton(_ s: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(s).frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderStrong))
        }
        .buttonStyle(.plain)
    }

    // MARK: Stop list

    private var stopList: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("CATEGORIES · ↑ ↓").font(.system(size: 11)).tracking(0.7).foregroundStyle(Theme.muted)
                .padding(.horizontal, 10).padding(.bottom, 8)
            ForEach(TagStops.all.indices, id: \.self) { i in
                stopRow(i, TagStops.all[i])
            }
            Spacer()
        }
        .padding(.vertical, 16).padding(.horizontal, 12)
    }

    private func picked(in s: TagStop) -> [String] {
        if s.rule == .freeText { return comments.note.isEmpty ? [] : [comments.note] }
        return comments.tags.filter { s.categories.contains(TagStops.categoryOf[$0] ?? "") }
    }

    private func stopRow(_ i: Int, _ s: TagStop) -> some View {
        let p = picked(in: s)
        let missing = s.rule == .atLeastOne && p.isEmpty
        let active = i == stopIndex
        return Button { stopIndex = i; filter = "" } label: {
            HStack {
                Text(s.id).font(.system(size: 14, weight: active ? .semibold : .regular))
                if missing { Text("!").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.orange) }
                Spacer()
                Text(p.isEmpty ? "" : (s.rule == .freeText ? "✓" : String(p.count)))
                    .font(.system(size: 12)).foregroundStyle(Theme.tealText)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .foregroundStyle(active ? Theme.tealText : Theme.text)
            .background(RoundedRectangle(cornerRadius: 8).fill(active ? Theme.tealBg : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? Color(hex: 0x1F5558) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Centre

    /// Tags offered for the current stop, most used first, filtered by the search box.
    private var options: [String] {
        var base: [String] = []
        for c in stop.categories { base += Catalog.tags[c] ?? [] }
        var seen = Set<String>()
        let unique = base.filter { seen.insert($0).inserted && $0 != "Peak" && !TagStops.setTags.contains($0) }
        let used = unique.filter { (store.tagCounts[$0] ?? 0) > 0 || comments.has($0) }
        let sorted = used.sorted { (store.tagCounts[$0] ?? 0) > (store.tagCounts[$1] ?? 0) }
        return filter.isEmpty ? sorted : sorted.filter { $0.localizedCaseInsensitiveContains(filter) }
    }

    private var centre: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(stop.id).font(.system(size: 24, weight: .semibold))
                Text(stop.hint).font(.system(size: 13)).foregroundStyle(Theme.muted)
                Spacer()
                if dirty { Text("unsaved").font(.system(size: 12)).foregroundStyle(Theme.orangeText) }
            }
            if stop.rule == .freeText {
                noteEditor
            } else {
                ScrollView {
                    chipGrid(options)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField("Filter tags…", text: $filter).textFieldStyle(.plain).focused($textFocused)
                        .onSubmit { textFocused = false; keysFocused = true }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderStrong))
            }
            Text(comments.rendered(categoryOrder: TagStops.writeRank))
                .font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(2).textSelection(.enabled)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func chipGrid(_ opts: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(opts.indices, id: \.self) { i in
                chip(opts[i], letter: i < Self.letters.count ? String(Self.letters[i]) : nil)
            }
        }
    }

    private func chip(_ tag: String, letter: String?) -> some View {
        let on = comments.has(tag)
        let n = store.tagCounts[tag] ?? 0
        let size = 13 + min(7, Double(n).squareRoot() / 3)
        return Button { toggle(tag) } label: {
            HStack(spacing: 8) {
                if let letter { Text(letter).font(.system(size: 10, weight: .semibold)).frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 4).fill(on ? Color(hex: 0x0E3A3C) : Color(hex: 0x26282D))) }
                Text(tag).font(.system(size: size, weight: on ? .semibold : .regular))
                Text(String(n)).font(.system(size: 11)).foregroundStyle(on ? Color(hex: 0x0E3A3C) : Theme.muted)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(on ? Color(hex: 0x06201F) : Theme.text)
            .background(Capsule().fill(on ? Theme.teal : Theme.field))
            .overlay(Capsule().stroke(on ? Theme.teal : Theme.borderStrong))
        }
        .buttonStyle(.plain)
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("//").foregroundStyle(Theme.muted)
                TextField("Rare, people, sampled artists…", text: Binding(
                    get: { comments.note }, set: { comments.note = $0; dirty = true }))
                    .textFieldStyle(.plain).focused($textFocused)
                    .onSubmit { textFocused = false; saveAndMove(1) }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.field))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.teal))
            Text("Return saves and moves to the next track.").font(.system(size: 12)).foregroundStyle(Theme.muted)
            Spacer()
        }
    }

    // MARK: Energy panel

    private var energyPanel: some View {
        let e = rating / 20
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Energy").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(e > 0 ? String(e) : "–").font(.system(size: 26, weight: .bold))
                    .foregroundStyle(e > 0 ? Theme.energyColor(e) : Theme.muted)
            }
            ForEach((1...5).reversed(), id: \.self) { level in
                Button { setEnergy(level) } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(level <= e ? Theme.energyColor(level) : Color(hex: 0x26282D))
                            .frame(width: 36, height: 22)
                        Text(Self.energyNames[level]).font(.system(size: 13))
                            .foregroundStyle(level == e ? Theme.text : Theme.muted)
                        Spacer()
                        Keycap(key: String(level))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("SET").font(.system(size: 11)).tracking(0.7).foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                setToggle("Opener", tag: "Opening")
                setToggle("Closer", tag: "Closing")
            }
        }
        .padding(16)
    }

    private func setToggle(_ label: String, tag: String) -> some View {
        let on = comments.has(tag)
        return Button { toggle(tag) } label: {
            Text(label).font(.system(size: 13)).frame(maxWidth: .infinity).frame(height: 32)
                .foregroundStyle(on ? Color(hex: 0x06201F) : Theme.text)
                .background(RoundedRectangle(cornerRadius: 8).fill(on ? Theme.teal : Theme.field))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? Theme.teal : Theme.borderStrong))
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func load(_ t: Track) {
        editingID = t.id
        comments = t.comments
        rating = t.rating
        dirty = false
        filter = ""
        stopIndex = 0
    }

    private func toggle(_ tag: String) {
        if let i = comments.tags.firstIndex(of: tag) {
            comments.tags.remove(at: i)
        } else {
            if stop.rule == .one, let cat = TagStops.categoryOf[tag] {
                comments.tags.removeAll { TagStops.categoryOf[$0] == cat }   // pick one: replace
            }
            comments.tags.append(tag)
            // Subgenre adds its genre (and Club-group styles add Club via the catalog's home map).
            if let home = Catalog.styleHome[tag], !comments.has(home) { comments.tags.append(home) }
            if stop.rule == .one, stopIndex < TagStops.all.count - 1 { stopIndex += 1 }
        }
        dirty = true
    }

    private func setEnergy(_ level: Int) { rating = level * 20; dirty = true }

    private func move(_ delta: Int) { saveAndMove(delta) }

    private func saveAndMove(_ delta: Int) {
        // Work out where to go before saving: saving marks the track reviewed, which takes it out of the queue.
        let ids = queueIDs
        let cur = ids.firstIndex(of: store.currentID ?? "") ?? 0
        let nextIdx = cur + delta
        let target: String? = ids.indices.contains(nextIdx) ? ids[nextIdx] : nil
        if let id = editingID {
            if dirty { store.saveTags(id, comments: comments, rating: rating) } else { store.leaveTrack(id) }
        }
        if let target { store.currentID = target }
        keysFocused = true
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if textFocused { return .ignored }
        switch press.key {
        case .upArrow: stopIndex = max(0, stopIndex - 1); filter = ""; return .handled
        case .downArrow: stopIndex = min(TagStops.all.count - 1, stopIndex + 1); filter = ""; return .handled
        case .leftArrow: saveAndMove(-1); return .handled
        case .rightArrow, .return: saveAndMove(1); return .handled
        default: break
        }
        guard let ch = press.characters.uppercased().first else { return .ignored }
        if let n = Int(String(ch)), (1...5).contains(n) { setEnergy(n); return .handled }
        if stop.rule == .freeText { textFocused = true; return .ignored }
        if let i = Self.letters.firstIndex(of: ch), i < options.count { toggle(options[i]); return .handled }
        return .ignored
    }
}

/// Current tags as small centred pills in the header.
struct FlowTags: View {
    let tags: [String]
    var body: some View {
        FlowLayout(spacing: 6, centered: true) {
            ForEach(tags, id: \.self) { t in
                Text(t).font(.system(size: 11)).padding(.horizontal, 9).padding(.vertical, 3)
                    .foregroundStyle(Theme.text2)
                    .background(Capsule().fill(Theme.field))
                    .overlay(Capsule().stroke(Theme.borderStrong))
            }
        }
    }
}

/// Wrapping row layout for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var centered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? 600, subviews: subviews)
        let h = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = centered ? bounds.minX + (bounds.width - row.width) / 2 : bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - s.height) / 2), proposal: .unspecified)
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + spacing + s.width > width {
                rows.append(Row())
            }
            var r = rows[rows.count - 1]
            r.width += (r.items.isEmpty ? 0 : spacing) + s.width
            r.height = max(r.height, s.height)
            r.items.append(i)
            rows[rows.count - 1] = r
        }
        return rows
    }
}
