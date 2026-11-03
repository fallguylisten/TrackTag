import Foundation

/// TrackTag's only local state: which tracks you've sent to each queue and which you've
/// reviewed. Keyed by Music persistent ID, saved in ~/Library/Application Support/TrackTag.
struct QueueState: Codable {
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        tagQueue = try c.decodeIfPresent(Set<String>.self, forKey: .tagQueue) ?? []
        reviewQueue = try c.decodeIfPresent(Set<String>.self, forKey: .reviewQueue) ?? []
        reviewed = try c.decodeIfPresent(Set<String>.self, forKey: .reviewed) ?? []
        incomplete = try c.decodeIfPresent(Set<String>.self, forKey: .incomplete) ?? []
    }

    var tagQueue: Set<String> = []
    var reviewQueue: Set<String> = []
    var reviewed: Set<String> = []
    var incomplete: Set<String> = []

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
