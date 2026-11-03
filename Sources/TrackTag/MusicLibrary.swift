import Foundation
import iTunesLibrary
import TrackTagCore

/// One track as TrackTag sees it. Read from iTunesLibrary (fast, read-only).
struct Track: Identifiable, Hashable {
    let id: String              // Music persistent ID, hex (same as the scripts use)
    var title: Title
    var artist: String
    var composer: String        // remixer(s)
    var genre: String
    var grouping: String        // source: RIP / DL (MIX = long mix, excluded)
    var comments: Comments
    var rating: Int             // 0–100; energy = rating / 20
    var bpm: Int
    var year: Int
    var dateAdded: Date?
    var dateModified: Date?
    var fileURL: URL?
    var kind: FileKind
    var hasArtwork: Bool
    var bitrate: Int = 0

    var energy: Int { rating / 20 }
    var titleText: String { title.display }
    var artSort: Int { hasArtwork ? 1 : 0 }
    var bpmText: String { bpm > 0 ? String(bpm) : "" }
    var tagsText: String { comments.tags.joined(separator: " · ") }
    var addedText: String { dateAdded.map { $0.formatted(.dateTime.month(.abbreviated).year()) } ?? "" }
    /// For sorting by date added (tracks without a date sort last).
    var addedSort: Date { dateAdded ?? .distantPast }
    /// Tag screen stops (of 12) that have something on this track.
    var stopsFilled: Int { TagStops.filledCount(comments) }
    var taggedPercent: Int { stopsFilled * 100 / 12 }
    /// File in the Trash, in Downloads, or missing.
    var fileAtRisk: Bool {
        guard let url = fileURL else { return true }
        let path = url.path
        if path.contains("/.Trash/") || path.contains("/Downloads/") { return true }
        return !FileManager.default.fileExists(atPath: path)
    }
}

enum LibraryError: Error, LocalizedError {
    case cannotOpen(String)
    var errorDescription: String? {
        switch self { case .cannotOpen(let why): return "Couldn’t open the Music library: \(why)" }
    }
}

/// Reads the library Music has open. Never writes: all writes go through MusicWriter.
struct LibraryReader {
    func load() throws -> [Track] {
        let lib: ITLibrary
        do { lib = try ITLibrary(apiVersion: "1.1") }
        catch { throw LibraryError.cannotOpen(error.localizedDescription) }

        return lib.allMediaItems.compactMap { item -> Track? in
            guard item.mediaKind == .kindSong else { return nil }
            let grouping = item.grouping ?? ""
            if grouping.trimmingCharacters(in: .whitespaces) == "MIX" { return nil }
            let ext = item.location?.pathExtension.lowercased() ?? ""
            return Track(
                id: String(format: "%016llX", item.persistentID.uint64Value),
                title: Title(item.title),
                artist: item.artist?.name ?? "",
                composer: item.composer,
                genre: item.genre,
                grouping: grouping,
                comments: Comments(parsing: item.comments ?? ""),
                rating: item.rating,
                bpm: item.beatsPerMinute,
                year: item.year,
                dateAdded: item.addedDate,
                dateModified: item.modifiedDate,
                fileURL: item.location,
                kind: ext == "mp3" ? .mp3 : (ext == "wav" ? .wav : .other),
                hasArtwork: item.hasArtworkAvailable,
                bitrate: item.bitrate
            )
        }
    }
}
