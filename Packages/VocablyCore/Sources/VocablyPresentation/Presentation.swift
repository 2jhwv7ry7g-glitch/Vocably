import Foundation

/// Presentation-layer state machines: plain, testable Swift (no SwiftUI / Observation).
/// The Xcode app's `@Observable` view models are thin wrappers around these types,
/// so all screen logic is verified here, on any platform.
public enum Presentation {
    public static let version = "1.0"
}
