import Foundation

/// How a stop on the Tag screen behaves.
public enum PickRule: Equatable {
    case one          // pick one, then jump to the next stop (Version, Decade)
    case atLeastOne   // Genre, Mood: shows "!" until something is picked
    case any          // pick any or none
    case freeText     // Note (// …)
}

/// One stop on the Tag screen: a display name over one or more raw Comments categories.
public struct TagStop: Identifiable, Equatable {
    public let id: String          // display name
    public let categories: [String]
    public let rule: PickRule
    public let hint: String
}

public enum TagStops {
    public static let all: [TagStop] = [
        TagStop(id: "Genre", categories: ["Family"], rule: .atLeastOne, hint: "1–2 per track"),
        TagStop(id: "Subgenre", categories: ["Style"], rule: .any, hint: "adds its genre"),
        TagStop(id: "Mood", categories: ["Mood", "Theme"], rule: .atLeastOne, hint: "pick at least one"),
        TagStop(id: "Version", categories: ["Version", "Reference"], rule: .one, hint: "~ sources for flips and mashups"),
        TagStop(id: "Decade", categories: ["Era"], rule: .one, hint: "decade of the original"),
        TagStop(id: "Texture", categories: ["Sound", "Instruments"], rule: .any, hint: "sound and instruments"),
        TagStop(id: "Crowd reaction", categories: ["Reaction", "Dance"], rule: .any, hint: "reaction and moves"),
        TagStop(id: "Beat & Structure", categories: ["Rhythm", "Structure"], rule: .any, hint: ""),
        TagStop(id: "Audience", categories: ["Audience"], rule: .any, hint: ""),
        TagStop(id: "Place", categories: ["Place"], rule: .any, hint: ""),
        TagStop(id: "Language", categories: ["Language"], rule: .any, hint: ""),
        TagStop(id: "Note", categories: [], rule: .freeText, hint: "Rare, people, samples"),
    ]

    /// Tags that live on the Energy panel (Set), not in a stop. Peak was dropped.
    public static let setTags = ["Opening", "Closing"]

    /// Raw category of a tag, from the catalog (nil = unknown tag, written at the end).
    public static let categoryOf: [String: String] = {
        var m: [String: String] = [:]
        for (cat, tags) in Catalog.tags { for t in tags where m[t] == nil { m[t] = cat } }
        return m
    }()

    /// Sort rank used when writing Comments: category order, then the catalog order inside it.
    public static let writeRank: [String: Int] = {
        var r: [String: Int] = [:]
        for (ci, cat) in Catalog.commentOrder.enumerated() {
            for (ti, t) in (Catalog.tags[cat] ?? []).enumerated() where r[t] == nil { r[t] = ci * 1000 + ti }
        }
        return r
    }()

    /// Stops that have at least one tag on this track (Note counts if there is a note).
    public static func filledCount(_ c: Comments) -> Int {
        let cats = Set(c.tags.compactMap { categoryOf[$0] })
        return all.filter { s in s.rule == .freeText ? !c.note.isEmpty : !Set(s.categories).isDisjoint(with: cats) }.count
    }

    /// Main style for the Genre field: first Style tag, else first Family tag.
    public static func genreField(_ c: Comments) -> String {
        c.tags.first { categoryOf[$0] == "Style" && $0 != "Club" }
            ?? c.tags.first { categoryOf[$0] == "Family" } ?? ""
    }
}
