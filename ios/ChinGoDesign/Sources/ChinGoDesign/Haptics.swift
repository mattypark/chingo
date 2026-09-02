import SwiftUI

/// What the phone is allowed to say, and when.
///
/// Haptics stop meaning anything the moment they fire on everything. So this is a closed
/// vocabulary of five events, each mapped to a distinct physical sensation, and scrolling is
/// deliberately not one of them.
///
/// Built on `.sensoryFeedback` (iOS 17+) rather than `UIImpactFeedbackGenerator`, so the
/// trigger is declarative and tied to a value change instead of to an imperative call site
/// that can fire twice.
public enum Feedback {
    /// A pin, a card, a row. The lightest thing the phone can do.
    case pick
    /// A catch landed. The one moment in the app that has genuinely earned a payoff.
    case caught
    /// A card settling into the album, a memory surfacing. Physical arrival.
    case arrive
    /// A boundary — nothing nearby, too far away, not yet.
    case refused
    /// A level gained.
    case levelled

    var sensory: SensoryFeedback {
        switch self {
        case .pick: .selection
        case .caught: .success
        case .arrive: .impact(weight: .light)
        case .refused: .warning
        case .levelled: .impact(weight: .heavy)
        }
    }
}

public extension View {
    /// Fire a feedback when `trigger` changes.
    ///
    /// Never attach this to a scroll offset or a continuously-changing value — a phone that
    /// buzzes constantly teaches people to ignore it, which costs the two moments that
    /// actually matter.
    func feedback<T: Equatable>(_ event: Feedback, on trigger: T) -> some View {
        sensoryFeedback(event.sensory, trigger: trigger)
    }
}
