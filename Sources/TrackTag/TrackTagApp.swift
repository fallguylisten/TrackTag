import SwiftUI
import AppKit
import TrackTagCore

/// Built as a Swift package, the app has no .app bundle yet, so macOS treats it as a
/// background tool (no Dock icon, no window focus). Make it a regular app on launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct TrackTagApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LibraryStore()
    var body: some Scene {
        WindowGroup("TrackTag") {
            RootView().environmentObject(store)
                .frame(minWidth: 1200, minHeight: 760)
                .preferredColorScheme(.dark)
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case settings = "Settings", review = "Review Queue", library = "Library", tagQueue = "Tag Queue", tag = "Tag"
    var id: String { rawValue }
    var dot: Color {
        switch self {
        case .settings: return Theme.grey
        case .review: return Theme.red
        case .library: return Theme.orange
        case .tagQueue, .tag: return Theme.teal
        }
    }
}

enum QueueKind { case review, tags }

enum QueueReason: String {
    case recheck = "Re-check tags", newImport = "New import", sent = "Sent from Library",
         incomplete = "Not fully tagged", reappraise = "Re-appraise (oldest)"
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var nextStep: [String: NextStep] = [:]
    @Published var queues = QueueState.load()
    @Published var error: String?
    @Published var loading = false
    let rules = NextStepRules()

    func load() {
        loading = true
        Task.detached {
            do {
                let t = try LibraryReader().load()
                let risk = Dictionary(uniqueKeysWithValues: t.map { ($0.id, $0.fileAtRisk) })
                await MainActor.run {
                    self.tracks = t
                    self.recompute(risk: risk)
                    self.loading = false
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.loading = false }
            }
        }
    }

    private var risk: [String: Bool] = [:]

    func recompute(risk newRisk: [String: Bool]? = nil) {
        if let r = newRisk { risk = r }
        let monthAgo = Date().addingTimeInterval(-30 * 86_400)
        var out: [String: NextStep] = [:]
        for t in tracks {
            var step = rules.nextStep(
                titleFlags: t.title.flags, grade: .unknown, fileAtRisk: risk[t.id] ?? false,
                isNew: (t.dateAdded ?? .distantPast) > monthAgo,
                notReviewed: false,
                categoriesFilled: min(12, t.comments.tags.count), hasArtwork: t.hasArtwork)
            if queues.reviewQueue.contains(t.id) { step = .needsReview }
            else if step == .none && queues.tagQueue.contains(t.id) { step = .needsTags }
            out[t.id] = step
        }
        nextStep = out
    }

    // MARK: Tag Queue

    /// Track shown in the Tag Queue side panel and on the Tag tab.
    @Published var currentID: String?
    @Published var saveMessage: String?

    /// Tag Queue rows with the reason each is there. Order: re-check, new, sent, incomplete, re-appraise.
    var tagQueue: [(track: Track, reason: QueueReason)] {
        let monthAgo = Date().addingTimeInterval(-30 * 86_400)
        var out: [(Track, QueueReason)] = []
        var used = Set<String>()
        func add(_ t: Track, _ r: QueueReason) { if used.insert(t.id).inserted { out.append((t, r)) } }
        let open = tracks.filter { !queues.reviewed.contains($0.id) }
        for t in open where t.title.flags.contains(where: { $0.lowercased() == "review" }) { add(t, .recheck) }
        for t in open where (t.dateAdded ?? .distantPast) > monthAgo { add(t, .newImport) }
        for t in open where queues.tagQueue.contains(t.id) { add(t, .sent) }
        for t in open where nextStep[t.id] == .needsTags { add(t, .incomplete) }
        // Re-appraise: the 10 tracks touched longest ago, even if reviewed before.
        let oldest = tracks.sorted { ($0.dateModified ?? .distantPast) < ($1.dateModified ?? .distantPast) }.prefix(10)
        for t in oldest { add(t, .reappraise) }
        return out.map { (track: $0.0, reason: $0.1) }
    }

    /// Writes the edited fields through Music, then updates the in-memory track.
    func save(_ id: String, title: String, artist: String, remixer: String, source: String, year: Int) {
        guard let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        var values: [MusicWriter.Field: Any] = [:]
        let t = tracks[i]
        if title != t.title.raw { values[.name] = title }
        if artist != t.artist { values[.artist] = artist }
        if remixer != t.composer { values[.composer] = remixer }
        if source != t.grouping { values[.grouping] = source }
        if year != t.year { values[.year] = year }
        guard !values.isEmpty else { saveMessage = "Nothing changed"; return }
        do {
            try MusicWriter().write(trackID: id, values)
            tracks[i].title = Title(title); tracks[i].artist = artist; tracks[i].composer = remixer
            tracks[i].grouping = source; tracks[i].year = year
            recompute()
            saveMessage = "Saved \(values.count) field\(values.count == 1 ? "" : "s") to Music"
        } catch {
            saveMessage = "Couldn’t save: \(error.localizedDescription)"
        }
    }

    func markReviewed(_ id: String) {
        queues.reviewed.insert(id); queues.tagQueue.remove(id); queues.save(); recompute()
    }

    func send(_ ids: [String], to kind: QueueKind) {
        switch kind {
        case .review: queues.reviewQueue.formUnion(ids)
        case .tags: queues.tagQueue.formUnion(ids)
        }
        queues.save()
        recompute()
    }
}

/// Header with the window's tab bar: Settings | Review Queue ‹ Library › Tag Queue › Tag
struct TabBar: View {
    @Binding var tab: AppTab
    var body: some View {
        HStack(spacing: 6) {
            Text("TrackTag").font(.system(size: 15, weight: .semibold)).frame(width: 140, alignment: .leading)
            Spacer()
            tabButton(.settings, icon: "gearshape")
            Rectangle().fill(Theme.borderStrong).frame(width: 1, height: 20).padding(.horizontal, 8)
            tabButton(.review)
            arrow("‹")
            tabButton(.library, main: true)
            arrow("›")
            tabButton(.tagQueue)
            arrow("›")
            tabButton(.tag)
            Spacer()
            Color.clear.frame(width: 140, height: 1)
        }
        .padding(.horizontal, 24).padding(.vertical, 10)
        .background(Theme.header)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private func arrow(_ a: String) -> some View { Text(a).font(.system(size: 16)).foregroundStyle(Color(hex: 0x5A5D63)) }

    private func tabButton(_ t: AppTab, icon: String? = nil, main: Bool = false) -> some View {
        let active = tab == t
        return Button { tab = t } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 13)) }
                else { Circle().fill(active ? Color(hex: 0x1A1206) : t.dot).frame(width: 7, height: 7) }
                // Reserve the bold width so tabs don't shift when the active one turns bold.
                ZStack {
                    Text(t.rawValue).font(.system(size: 14, weight: .semibold)).hidden()
                    Text(t.rawValue).font(.system(size: 14, weight: active || main ? .semibold : .regular))
                }
            }
            .padding(.horizontal, main ? 22 : 16).padding(.vertical, 8)
            .foregroundStyle(active ? Color(hex: 0x1A1206) : Theme.text2)
            .background(Capsule().fill(active ? t.dot : .clear))
            .overlay(Capsule().stroke(main && !active ? Color(hex: 0x44464C) : .clear, lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct RootView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var tab: AppTab = .library

    var body: some View {
        VStack(spacing: 0) {
            TabBar(tab: $tab)
            switch tab {
            case .library: LibraryView()
            case .tagQueue: TagQueueView(goToTag: { tab = .tag })
            default:
                Text("\(tab.rawValue) — coming next").foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.window)
            }
        }
        .background(Theme.window)
        .task { store.load() }
    }
}
