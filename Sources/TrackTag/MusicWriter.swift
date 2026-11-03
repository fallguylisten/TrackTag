import Foundation

/// Writes through Apple Music's scripting interface — never to the files or Music's database
/// directly. Same approach as scripts/tracktag-migrate.js, which ran cleanly on this library.
struct MusicWriter {
    enum Field: String { case name, artist, composer, comment, genre, grouping, rating }

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
        try Self.runJXA(script)
    }

    /// Runs JavaScript for Automation through osascript (same engine as the scripts).
    private static func runJXA(_ source: String) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-l", "JavaScript", "-e", source]
        let err = Pipe(); p.standardError = err; p.standardOutput = Pipe()
        try p.run(); p.waitUntilExit()
        if p.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown error"
            throw WriteError(message: msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func quote(_ s: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [s])
        return String(String(data: data, encoding: .utf8)!.dropFirst().dropLast())
    }
}
