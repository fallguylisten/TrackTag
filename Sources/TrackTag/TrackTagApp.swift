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
                Text(t.rawValue).font(.system(size: 14, weight: active || main ? .semibold : .regular))
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
            default:
                Text("\(tab.rawValue) — coming next").foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.window)
            }
        }
        .background(Theme.window)
        .task { store.load() }
    }
}
