import Foundation

/// The Comments field: `| Tag | Tag | ... | // free-text note`.
/// Smart playlists match `| Tag |`, so the leading and trailing pipes always stay.
public struct Comments: Equatable {
    public var tags: [String]
    public var note: String

    public init(tags: [String] = [], note: String = "") {
        self.tags = tags
        self.note = note
    }

    public init(parsing raw: String) {
        let parts = raw.components(separatedBy: "//")
        let tagPart = parts.first ?? ""
        note = parts.dropFirst().joined(separator: "//").trimmingCharacters(in: .whitespaces)
        var seen = Set<String>()
        tags = tagPart
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public func has(_ tag: String) -> Bool { tags.contains(tag) }

    /// Writes tags in the order given by `categoryOrder` (tags not in it keep their place at the end).
    public func rendered(categoryOrder: [String: Int] = [:]) -> String {
        let ordered = tags.enumerated().sorted { a, b in
            let ra = categoryOrder[a.element] ?? Int.max
            let rb = categoryOrder[b.element] ?? Int.max
            return ra == rb ? a.offset < b.offset : ra < rb
        }.map(\.element)
        var out = ordered.isEmpty ? "" : "| " + ordered.joined(separator: " | ") + " |"
        if !note.isEmpty { out += (out.isEmpty ? "" : " ") + "// " + note }
        return out
    }
}
