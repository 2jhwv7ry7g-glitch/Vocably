import Foundation
import VocablyDomain

/// Drives the paywall screen: available plans, the selected plan, and the purchase lifecycle.
///
/// Pure presentation logic — `begin/succeed/fail` record intent and outcome reported by the
/// platform's StoreKit layer; this type performs no purchasing itself.
public struct PaywallState: Equatable, Sendable {
    /// Where the purchase flow currently stands.
    public enum Phase: Equatable, Sendable {
        case idle
        case purchasing
        case purchased
        case failed(String)
    }

    /// Plans offered on the paywall.
    public private(set) var products: [SubscriptionProduct]
    /// Identifier of the highlighted plan, if any.
    public private(set) var selectedProductID: String?
    /// Current purchase lifecycle phase.
    public private(set) var phase: Phase

    /// Create a paywall, default-selecting the yearly plan (or the first plan) when products are supplied.
    public init(products: [SubscriptionProduct] = []) {
        self.products = products
        self.selectedProductID = Self.defaultSelection(in: products)
        self.phase = .idle
    }

    /// The currently highlighted product, resolved from `selectedProductID`.
    public var selectedProduct: SubscriptionProduct? {
        guard let selectedProductID else { return nil }
        return products.first { $0.id == selectedProductID }
    }

    /// Call-to-action label: "Start free trial" when the selected plan offers a trial, else "Subscribe".
    public var ctaTitle: String {
        selectedProduct?.hasFreeTrial == true ? "Start free trial" : "Subscribe"
    }

    /// Replace the product list, re-defaulting the selection to the yearly plan (or first).
    public mutating func setProducts(_ products: [SubscriptionProduct]) {
        self.products = products
        self.selectedProductID = Self.defaultSelection(in: products)
    }

    /// Highlight the product with the given id, if it exists in the current list.
    public mutating func select(_ id: String) {
        guard products.contains(where: { $0.id == id }) else { return }
        selectedProductID = id
    }

    /// Enter the purchasing phase.
    public mutating func begin() {
        phase = .purchasing
    }

    /// Record a successful purchase.
    public mutating func succeed() {
        phase = .purchased
    }

    /// Record a failed purchase with a user-facing message.
    public mutating func fail(_ message: String) {
        phase = .failed(message)
    }

    /// Prefer the yearly plan, otherwise the first plan, otherwise none.
    private static func defaultSelection(in products: [SubscriptionProduct]) -> String? {
        (products.first { $0.period == .yearly } ?? products.first)?.id
    }
}
