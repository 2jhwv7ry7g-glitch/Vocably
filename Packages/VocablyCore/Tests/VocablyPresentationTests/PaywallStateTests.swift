import XCTest
import VocablyDomain
import VocablyPresentation

final class PaywallStateTests: XCTestCase {

    private var yearly: SubscriptionProduct {
        SubscriptionProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            formattedPrice: "$39.99",
            period: .yearly,
            hasFreeTrial: true
        )
    }

    private var monthly: SubscriptionProduct {
        SubscriptionProduct(
            id: "pro.monthly",
            displayName: "Monthly",
            formattedPrice: "$4.99",
            period: .monthly,
            hasFreeTrial: false
        )
    }

    func testInitDefaultSelectsYearly() {
        let state = PaywallState(products: [yearly, monthly])
        XCTAssertEqual(state.selectedProductID, "pro.yearly")
        XCTAssertEqual(state.selectedProduct, yearly)
        XCTAssertEqual(state.phase, .idle)
    }

    func testInitDefaultSelectsYearlyRegardlessOfOrder() {
        let state = PaywallState(products: [monthly, yearly])
        XCTAssertEqual(state.selectedProductID, "pro.yearly")
    }

    func testInitWithoutYearlySelectsFirst() {
        let state = PaywallState(products: [monthly])
        XCTAssertEqual(state.selectedProductID, "pro.monthly")
    }

    func testInitEmptyHasNoSelection() {
        let state = PaywallState()
        XCTAssertNil(state.selectedProductID)
        XCTAssertNil(state.selectedProduct)
        XCTAssertEqual(state.ctaTitle, "Subscribe")
    }

    func testCtaTitleFreeTrialWhenYearlySelected() {
        let state = PaywallState(products: [yearly, monthly])
        XCTAssertEqual(state.ctaTitle, "Start free trial")
    }

    func testCtaTitleSubscribeWhenNoTrial() {
        var state = PaywallState(products: [yearly, monthly])
        state.select("pro.monthly")
        XCTAssertEqual(state.selectedProductID, "pro.monthly")
        XCTAssertEqual(state.ctaTitle, "Subscribe")
    }

    func testSelectSwitchesProduct() {
        var state = PaywallState(products: [yearly, monthly])
        state.select("pro.monthly")
        XCTAssertEqual(state.selectedProduct, monthly)
    }

    func testSelectUnknownIsNoOp() {
        var state = PaywallState(products: [yearly, monthly])
        state.select("does.not.exist")
        XCTAssertEqual(state.selectedProductID, "pro.yearly")
    }

    func testSetProductsReDefaults() {
        var state = PaywallState()
        XCTAssertNil(state.selectedProductID)
        state.setProducts([monthly, yearly])
        XCTAssertEqual(state.selectedProductID, "pro.yearly")
    }

    func testPhaseTransitions() {
        var state = PaywallState(products: [yearly, monthly])
        XCTAssertEqual(state.phase, .idle)
        state.begin()
        XCTAssertEqual(state.phase, .purchasing)
        state.succeed()
        XCTAssertEqual(state.phase, .purchased)
        state.fail("Card declined")
        XCTAssertEqual(state.phase, .failed("Card declined"))
    }
}
