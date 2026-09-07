import Foundation

/// How far away someone is, said out loud.
///
/// One formatter, because the rail and the add sheet were about to disagree -- the rail
/// already said "about 40 m away" while the list that lets you act on it was going to say
/// miles, and two units for one fact on two screens reads as two different facts.
///
/// **Locale, not a hardcoded unit.** Asked for in miles, and in the US that is what this
/// gives: `naturalScale` picks feet under about a tenth of a mile and miles above it, so
/// "0.1 mi away" arrives when it is true and "130 ft" arrives when *that* is true, which is
/// the more useful sentence at the distance you can actually see somebody. Outside the US
/// the same code says metres, with no second branch to keep in step.
/// Main-actor isolated because `MeasurementFormatter` is not `Sendable` and building a fresh
/// one per call, in a view body that runs every frame, is the wrong trade. Every caller is a
/// view, so the isolation costs nothing.
@MainActor
public enum Distance {

    private static let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = [.naturalScale, .providedUnit]
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()

    /// `metres` is already coarsened to the cell before it reaches here. Nothing in this file
    /// is ever a real distance to a real person.
    public static func spoken(metres: Int) -> String {
        let base = Measurement(value: Double(metres), unit: UnitLength.meters)
        let metric = Locale.current.measurementSystem == .metric
        return formatter.string(from: metric ? base : base.converted(to: .feet))
    }

    /// "about 400 ft away" -- the sentence, not just the number.
    public static func away(metres: Int) -> String {
        "about \(spoken(metres: metres)) away"
    }
}
