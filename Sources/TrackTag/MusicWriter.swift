import Foundation

/// Writes through Apple Music's scripting interface — never to the files or Music's database
/// directly. Same approach as scripts/tracktag-migrate.js, which ran cleanly on this library.
struct MusicWriter {
    enum Field: String { case name, artist, composer, comment, genre, grouping, rating, year }

    struct WriteError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Sets fields on one track, found by persistent ID. Values are passed as JSON
    /// so titles with quotes, `<…>` or `!…!` can't break the script.
    func write(trackID: String, _ values: [Field: Any]) throws {
        let payload = Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })
        let json = String(data: try JSONSerialization.data(withJSONObject: payload), encoding: .utf8)!
        let script = """
        var Music = Application('Music');
        var hits = Music.libraryPlaylists[0].tracks.whose({ persistentID: \(Self.quote(trackID)) });
        if (!hits.length) throw new Error('Track not found in Music');
        var t = hits[0], v = \(json);
        Object.keys(v).forEach(function (k) { t[k] = v[k]; });
        'ok';
        """
        try Self.retrying { try Self.runJXA(script) }
    }

    /// Points the existing Music track at a different file (verified Nov 3: keeps the same track,
    /// tags, plays and playlists). Only AppleScript can do this; JXA fails.
    func relink(trackID: String, to file: URL) throws {
        let script = """
        tell application "Music" to set location of (first track of library playlist 1 whose persistent ID is \(Self.appleQuote(trackID))) to POSIX file \(Self.appleQuote(file.path))
        """
        try Self.retrying { try Self.run(["-e", script]) }
    }

    /// Removes the track from Music (the file itself is moved by the caller).
    func delete(trackID: String) throws {
        let script = """
        var hits = Application('Music').libraryPlaylists[0].tracks.whose({ persistentID: \(Self.quote(trackID)) });
        if (hits.length) Application('Music').delete(hits[0]);
        """
        try Self.runJXA(script)
    }

    /// Music may still be importing a new file for a moment ("-54 File permission error"): retry a few times.
    private static func retrying(_ body: () throws -> Void) throws {
        var last: Error?
        for attempt in 0..<5 {
            do { try body(); return } catch {
                last = error
                guard "\(error)".contains("-54") || error.localizedDescription.contains("-54") else { throw error }
                Thread.sleep(forTimeInterval: 1.0 + Double(attempt))
            }
        }
        throw last!
    }

    /// Runs JavaScript for Automation through osascript (same engine as the scripts).
    private static func runJXA(_ source: String) throws {
        try run(["-l", "JavaScript", "-e", source])
    }

    private static func run(_ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = args
        let err = Pipe(); p.standardError = err; p.standardOutput = Pipe()
        try p.run(); p.waitUntilExit()
        if p.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown error"
            throw WriteError(message: msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// AppleScript string literal: only backslash and double quote need escaping.
    private static func appleQuote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func quote(_ s: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [s])
        return String(String(data: data, encoding: .utf8)!.dropFirst().dropLast())
    }
}
