import Foundation

/// Title format: `Name (part of name) [Version] <personal annotation> !review flag!`
///
/// - `<108 > 127>` personal annotations: shown everywhere.
/// - `!poor quality!` review flags: kept in Music and the file tags (searchable in
///   Rekordbox/Serato) but hidden in TrackTag's own title displays; the flag shows
///   in the "Why it's here" / Next step columns instead.
public struct Title: Hashable {
    public var raw: String

    public init(_ raw: String) { self.raw = raw }

    private static let flagPattern = try! NSRegularExpression(pattern: #"\s*!([^!]+)!"#)
    private static let versionPattern = try! NSRegularExpression(pattern: #"\[([^\]]+)\]"#)

    /// Review flags in the title, e.g. ["poor quality"].
    public var flags: [String] {
        Self.matches(Self.flagPattern, in: raw).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// The title as TrackTag shows it: review flags removed.
    public var display: String {
        let range = NSRange(raw.startIndex..., in: raw)
        return Self.flagPattern.stringByReplacingMatches(in: raw, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// The text in square brackets, e.g. "Gaszia Edit".
    public var version: String? { Self.matches(Self.versionPattern, in: raw).first }

    /// Adds a review flag (no-op if already present).
    public func adding(flag: String) -> Title {
        guard !flags.contains(flag) else { return self }
        return Title(raw.trimmingCharacters(in: .whitespaces) + " !\(flag)!")
    }

    /// Removes one review flag, or all of them when `flag` is nil.
    public func removing(flag: String? = nil) -> Title {
        var out = raw
        for f in flags where flag == nil || f == flag {
            out = out.replacingOccurrences(of: " !\(f)!", with: "")
                     .replacingOccurrences(of: "!\(f)!", with: "")
        }
        return Title(out.trimmingCharacters(in: .whitespaces))
    }

    private static func matches(_ re: NSRegularExpression, in s: String) -> [String] {
        re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap {
            Range($0.range(at: 1), in: s).map { String(s[$0]) }
        }
    }
}
