import Foundation
import TrackTagCore

/// Everything on the Settings tab. Saved in UserDefaults; changes apply immediately.
struct AppSettings: Codable, Equatable {
    // Files
    var ripFolder = "~/Music/Crate/LQ"
    var dlFolder = "~/Music/Crate/HQ"
    var watchRip = true
    var watchDL = true
    var copyNewDLToAutoAdd = true
    var keepReplacedDays = 30
    var backupBeforeBulk = true
    // Library tab
    var leaveOutMixes = true
    var scanNewTracks = true
    var scanInBackground = true
    // Tag Queue
    var newImportDays = 30
    var needsTagsPercent = 50
    var noArtNeedsTags = true
    var reappraiseCount = 10
    // Review Queue
    var mp3Cutoff = 17.0
    var wavCutoff = 20.0
    var flagPoorMP3 = true
    var flagPoorWAV = true
    var poorOnlyPlayed = true
    var flagAtRisk = true

    private static let key = "TrackTagSettings"

    static func load() -> AppSettings {
        guard let d = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(AppSettings.self, from: d) else { return AppSettings() }
        return s
    }

    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) }
    }

    var cutoffs: GradeCutoffs {
        var c = GradeCutoffs(); c.mp3 = mp3Cutoff; c.wav = wavCutoff; return c
    }
}
