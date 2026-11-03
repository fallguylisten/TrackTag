import Foundation

/// TrackTag's only local state: which tracks you've sent to each queue and which you've
/// reviewed. Keyed by Music persistent ID, saved in ~/Library/Application Support/TrackTag.
struct QueueState: Codable {
    var tagQueue: Set<String> = []
    var reviewQueue: Set<String> = []
    var reviewed: Set<String> = []

    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TrackTag", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("queues.json")
    }

    static func load() -> QueueState {
        guard let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(QueueState.self, from: data) else { return QueueState() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { try? data.write(to: Self.url, options: .atomic) }
    }
}
