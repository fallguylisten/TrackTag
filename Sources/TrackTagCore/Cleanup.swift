import Foundation

/// "Clean Up" in the Tag Queue: turns messy rip/download names into the house format.
///   Title:    Name (part of name) [Version] <note> !flag!
///   Artist:   all artists, comma-separated (ft. / feat. / x / ; / · become commas; & is left alone)
///   Composer: the remixer(s), taken from the version, e.g. [Gaszia Edit] -> Gaszia
public struct CleanFields: Equatable {
    public var name: String          // without version, notes or flags
    public var version: String       // text inside [ ], "" for an original
    public var notes: [String]       // <…> personal annotations
    public var flags: [String]       // !…! review flags (kept, never edited here)
    public var artists: [String]
    public var remixer: String

    public init(name: String, version: String, notes: [String], flags: [String], artists: [String], remixer: String) {
        self.name = name; self.version = version; self.notes = notes; self.flags = flags
        self.artists = artists; self.remixer = remixer
    }

    public var isOriginal: Bool { version.isEmpty }

    public var title: String {
        var s = name
        if !version.isEmpty { s += " [\(version)]" }
        for n in notes where !n.isEmpty { s += " <\(n)>" }
        for f in flags { s += " !\(f)!" }
        return s
    }

    public var artist: String { artists.joined(separator: ", ") }
}

public enum Cleanup {
    /// Words that mark a version (case-insensitive) when found in ( ) or [ ] or after " - ".
    static let versionWords = ["edit", "remix", "flip", "mashup", "bootleg", "vip", "rework", "mix", "dub",
                               "refix", "blend", "megamix", "re-edit", "redo", "version", "cover", "club"]

    static func isVersion(_ s: String) -> Bool {
        let l = s.lowercased()
        return versionWords.contains { l.range(of: "\\b\($0)\\b", options: .regularExpression) != nil }
    }

    /// Splits "A ft. B x C; D" into ["A", "B", "C", "D"]. "&" stays inside a name.
    public static func splitArtists(_ raw: String) -> [String] {
        var s = raw
        for sep in [" feat. ", " feat ", " ft. ", " ft ", " Feat. ", " Ft. ", " x ", " X ", ";", " · ", "·", " / "] {
            s = s.replacingOccurrences(of: sep, with: ",")
        }
        var seen = Set<String>()
        return s.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    /// Remixer from a version: "Gaszia Edit" -> "Gaszia", "dudda x votu Flip" -> "dudda, votu".
    public static func remixer(from version: String) -> String {
        guard !version.isEmpty else { return "" }
        var words = version.split(separator: " ").map(String.init)
        while let last = words.last, isVersion(last) || last.lowercased() == "club" { words.removeLast() }
        return splitArtists(words.joined(separator: " ")).joined(separator: ", ")
    }

    public static func clean(title raw: String, artist rawArtist: String, composer: String) -> CleanFields {
        var s = raw.trimmingCharacters(in: .whitespaces)

        func pull(_ pattern: String) -> [String] {
            guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
            let ns = s as NSString
            let found = re.matches(in: s, range: NSRange(location: 0, length: ns.length))
                .map { ns.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespaces) }
            s = re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: ns.length), withTemplate: "")
            return found
        }

        let flags = pull(#"\s*!([^!]+)!"#)
        // Notes may contain ">" (e.g. <108 > 127>), so a note ends at ">" followed by another note, a flag or the end.
        let notes = pull(#"\s*<([^<]*?)>(?=\s*(?:<|!|$))"#)
        var version = pull(#"\s*\[([^\]]+)\]"#).first ?? ""

        // Version-like text in ( ), e.g. "(Loft Mix)" -> [Loft Mix]; other ( ) stay as part of the name.
        if version.isEmpty, let re = try? NSRegularExpression(pattern: #"\s*\(([^)]+)\)"#) {
            let ns = s as NSString
            for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)).reversed() {
                let inner = ns.substring(with: m.range(at: 1))
                if isVersion(inner) {
                    version = inner.trimmingCharacters(in: .whitespaces)
                    s = (s as NSString).replacingCharacters(in: m.range, with: "")
                    break
                }
            }
        }
        // "Name - Version" style.
        if version.isEmpty, let r = s.range(of: " - ", options: .backwards) {
            let tail = String(s[r.upperBound...])
            if isVersion(tail) { version = tail.trimmingCharacters(in: .whitespaces); s = String(s[..<r.lowerBound]) }
        }
        // Rip leftovers such as "-X1501" or "(2)".
        s = s.replacingOccurrences(of: #"-X\d+$"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s*\(\d\)$"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let rx = composer.isEmpty ? remixer(from: version) : composer
        return CleanFields(name: s, version: version, notes: notes, flags: flags,
                           artists: splitArtists(rawArtist), remixer: rx)
    }
}
