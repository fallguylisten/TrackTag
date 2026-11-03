import Foundation

/// Sound ceiling = highest frequency (kHz) with real content, from the spectrogram.
/// Graded per file type with one cut-off each (Settings → Review Queue sliders).
public enum FileKind: String, Codable, Hashable { case mp3, wav, other }

public enum SoundGrade: String, Codable { case good, poor, unknown }

public struct GradeCutoffs: Codable, Equatable {
    /// MP3 below this sounds like 128 kbps or worse.
    public var mp3: Double = 17.0
    /// WAV below this was made from a 256 kbps file or worse (fake lossless).
    public var wav: Double = 20.0
    public init() {}

    public func grade(ceilingKHz: Double?, kind: FileKind) -> SoundGrade {
        guard let c = ceilingKHz else { return .unknown }
        switch kind {
        case .mp3: return c < mp3 ? .poor : .good
        case .wav: return c < wav ? .poor : .good
        case .other: return .unknown
        }
    }
}

/// Library "Next step" column. Review beats tagging.
public enum NextStep: String { case needsReview = "Needs review", needsTags = "Needs tags", none = "—" }

public struct NextStepRules {
    public var needsTagsBelowFraction = 0.5
    public init() {}

    public func nextStep(titleFlags: [String], grade: SoundGrade, fileAtRisk: Bool,
                         isNew: Bool, notReviewed: Bool, categoriesFilled: Int,
                         hasArtwork: Bool) -> NextStep {
        let reviewFlags = titleFlags.filter { $0.lowercased() != "review" }
        if !reviewFlags.isEmpty || grade == .poor || fileAtRisk { return .needsReview }
        if isNew || notReviewed || titleFlags.contains(where: { $0.lowercased() == "review" })
            || Double(categoriesFilled) / 12.0 < needsTagsBelowFraction || !hasArtwork {
            return .needsTags
        }
        return .none
    }
}
