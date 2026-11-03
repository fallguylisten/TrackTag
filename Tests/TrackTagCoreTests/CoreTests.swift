import XCTest
@testable import TrackTagCore

final class CoreTests: XCTestCase {
    func testCommentsRoundTrip() {
        let c = Comments(parsing: "| HipHop | Cali | Hyphy | // samples Too $hort")
        XCTAssertEqual(c.tags, ["HipHop", "Cali", "Hyphy"])
        XCTAssertEqual(c.note, "samples Too $hort")
        XCTAssertEqual(c.rendered(), "| HipHop | Cali | Hyphy | // samples Too $hort")
    }

    func testTitleFlagsHiddenAnnotationsKept() {
        let t = Title("HARDX [Club Edit] <108 > 127> !poor quality!")
        XCTAssertEqual(t.flags, ["poor quality"])
        XCTAssertEqual(t.display, "HARDX [Club Edit] <108 > 127>")
        XCTAssertEqual(t.version, "Club Edit")
        XCTAssertEqual(t.removing().raw, "HARDX [Club Edit] <108 > 127>")
        XCTAssertEqual(Title("Ballin").adding(flag: "review").raw, "Ballin !review!")
    }

    func testGrades() {
        let g = GradeCutoffs()
        XCTAssertEqual(g.grade(ceilingKHz: 16.5, kind: .mp3), .poor)
        XCTAssertEqual(g.grade(ceilingKHz: 20.1, kind: .mp3), .good)
        XCTAssertEqual(g.grade(ceilingKHz: 19.5, kind: .wav), .poor)
    }

    func testReviewBeatsTags() {
        let r = NextStepRules()
        XCTAssertEqual(r.nextStep(titleFlags: ["poor quality"], grade: .good, fileAtRisk: false,
                                  isNew: true, notReviewed: true, categoriesFilled: 2, hasArtwork: false), .needsReview)
        XCTAssertEqual(r.nextStep(titleFlags: ["review"], grade: .good, fileAtRisk: false,
                                  isNew: false, notReviewed: false, categoriesFilled: 10, hasArtwork: true), .needsTags)
        XCTAssertEqual(r.nextStep(titleFlags: [], grade: .good, fileAtRisk: false,
                                  isNew: false, notReviewed: false, categoriesFilled: 8, hasArtwork: true), .none)
    }
}
