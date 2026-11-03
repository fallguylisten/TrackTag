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
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var error: String?
    @Published var loading = false

    func load() {
        loading = true
        Task.detached {
            do {
                let t = try LibraryReader().load()
                await MainActor.run { self.tracks = t; self.loading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.loading = false }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var tab: AppTab = .library

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(AppTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 640).padding(12)
            Divider()
            switch tab {
            case .library: LibraryView()
            default: Text("\(tab.rawValue) — coming next").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { store.load() }
    }
}

/// First real screen: proves reading works on the real library.
struct LibraryView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var query = ""
    private let rules = NextStepRules()
    private let cutoffs = GradeCutoffs()

    var filtered: [Track] {
        query.isEmpty ? store.tracks : store.tracks.filter {
            $0.title.display.localizedCaseInsensitiveContains(query) || $0.artist.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                Text("Library").font(.largeTitle.bold())
                Text("\(store.tracks.count) tracks").foregroundStyle(.secondary)
                Spacer()
            }
            TextField("Search the library", text: $query).textFieldStyle(.roundedBorder)
            if let e = store.error { Text(e).foregroundStyle(.red) }
            Table(filtered) {
                TableColumn("Title") { Text($0.title.display) }
                TableColumn("Artist", value: \.artist)
                TableColumn("Genre", value: \.genre)
                TableColumn("BPM") { Text($0.bpm > 0 ? "\($0.bpm)" : "") }.width(50)
                TableColumn("Tags") { Text($0.comments.tags.joined(separator: " · ")).foregroundStyle(.secondary) }
                TableColumn("Next step") { t in
                    Text(rules.nextStep(titleFlags: t.title.flags,
                                        grade: .unknown, fileAtRisk: false, isNew: false, notReviewed: false,
                                        categoriesFilled: min(12, t.comments.tags.count), hasArtwork: t.hasArtwork).rawValue)
                }.width(110)
            }
        }
        .padding(24)
    }
}
