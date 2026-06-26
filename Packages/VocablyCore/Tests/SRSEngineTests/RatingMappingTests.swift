import XCTest
import VocablyDomain

final class RatingMappingTests: XCTestCase {
    func testSwipeMapping() {
        XCTAssertEqual(Rating.from(swipe: .left), .again)
        XCTAssertEqual(Rating.from(swipe: .right), .good)
        XCTAssertEqual(Rating.from(swipe: .up), .easy)
        XCTAssertEqual(Rating.from(swipe: .down), .hard)
    }

    func testButtonLabelMapping() {
        XCTAssertEqual(Rating(buttonLabel: "Still learning"), .again)
        XCTAssertEqual(Rating(buttonLabel: "I know it"), .good)
        XCTAssertEqual(Rating(buttonLabel: "Got it"), .good)
        XCTAssertEqual(Rating(buttonLabel: "Known"), .good)
        XCTAssertEqual(Rating(buttonLabel: "HARD"), .hard)
        XCTAssertEqual(Rating(buttonLabel: "easy"), .easy)
        XCTAssertNil(Rating(buttonLabel: "nonsense"))
    }

    func testSM2Quality() {
        XCTAssertEqual(Rating.again.sm2Quality, 1)
        XCTAssertEqual(Rating.hard.sm2Quality, 3)
        XCTAssertEqual(Rating.good.sm2Quality, 4)
        XCTAssertEqual(Rating.easy.sm2Quality, 5)
    }
}
