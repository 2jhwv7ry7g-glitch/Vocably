import XCTest
import VocablyPresentation

final class PresentationTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertEqual(Presentation.version, "1.0")
    }
}
