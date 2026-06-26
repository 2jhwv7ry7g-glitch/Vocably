import Foundation

/// A purchasable Pro plan, surfaced on the Paywall.
public struct SubscriptionProduct: Identifiable, Sendable, Equatable {
    public enum Period: String, Sendable, Equatable { case monthly, yearly }

    public var id: String                  // StoreKit product id, e.g. "pro.yearly"
    public var displayName: String
    public var formattedPrice: String      // localized, e.g. "$39.99"
    public var period: Period
    public var hasFreeTrial: Bool

    public init(id: String, displayName: String, formattedPrice: String, period: Period, hasFreeTrial: Bool) {
        self.id = id
        self.displayName = displayName
        self.formattedPrice = formattedPrice
        self.period = period
        self.hasFreeTrial = hasFreeTrial
    }
}

/// Current entitlement state used to gate Pro features.
public enum SubscriptionStatus: Sendable, Equatable {
    case unknown
    case free
    case trial
    case pro

    public var isPro: Bool { self == .trial || self == .pro }
}
