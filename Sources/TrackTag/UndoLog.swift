import Foundation
import AVFoundation

/// Every single-track write logs the old values to ~/Music/TrackTag/undo-app-<date>.json,
/// in the same format as the scripts, so a day's edits can be reverted with
///   osascript -l JavaScript ~/Music/TrackTag/tracktag-migrate.js revert ~/Music/TrackTag/undo-app-<date>.json
enum UndoLog {
    private static var url: URL {
        let day = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/TrackTag/undo-app-\(day).json")
    }

    static func record(id: String, title: String, old: [String: Any]) {
        guard !old.isEmpty else { return }
        let u = url
        try? FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        var list: [[String: Any]] = []
        if let d = try? Data(contentsOf: u), let a = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] { list = a }
        list.append(["pid": id, "index": -1, "title": title, "old": old,
                     "at": ISO8601DateFormatter().string(from: Date())])
        if let d = try? JSONSerialization.data(withJSONObject: list) { try? d.write(to: u, options: .atomic) }
    }
}

/// After a write, re-reads the file's own tags and reports when they don't match what Music holds.
/// TrackTag never patches files itself; a mismatch is shown so you can fix it in Music.
enum FileTagCheck {
    static func titleMatches(_ file: URL?, expected: String) -> Bool {
        guard let file else { return true }
        let asset = AVURLAsset(url: file)
        let items = asset.commonMetadata.filter { $0.commonKey == .commonKeyTitle }
        guard let found = items.first?.stringValue else { return true }   // no readable tag: nothing to compare
        return found == expected
    }
}
