import Foundation

/// When a photo stops being a secret.
///
/// A catch does not show you the photo. It shows you that there is one. At nine the next
/// morning it arrives -- on both phones, at the same instant, the same image.
///
/// **Why the delay is the feature.** Nobody poses for a photo they cannot check. Removing the
/// preview and the retake turns the camera from a thing you perform for into a thing that
/// records what was actually happening, which is the only kind of photo worth keeping of an
/// afternoon with somebody. Dispo proved the constraint works; it applied it to a photo you
/// took alone. This applies it to one two people are in, which is strictly better, because
/// Dispo's reveal was private and this one is shared.
///
/// It also buys the app the only notification it can honestly send: not "come back", but
/// "the thing you already did is ready". Two people who met yesterday get the same alert at
/// the same second, which is a reason to text each other rather than to open an app.
public enum Develop {

    /// Nine in the morning, local. Late enough that it is not an alarm, early enough that it
    /// is the first thing rather than something you find at lunch.
    public static let hour = 9

    /// The shortest a photo may ever wait.
    ///
    /// Without a floor, "the next 9am" means a catch at 08:59 develops sixty seconds later,
    /// and the one time somebody sees that happen the whole mechanic reads as broken rather
    /// than as a rule. Three hours is enough that the photo always outlives the moment it was
    /// taken in.
    private static let minimumWait: TimeInterval = 60 * 60 * 3

    /// When a photo taken at `moment` arrives.
    ///
    /// The next 9am at least `minimumWait` away. So an evening catch lands the next morning,
    /// a catch at two in the morning lands at nine that same morning -- correct, since it is
    /// already tomorrow -- and a catch over breakfast waits a full day rather than developing
    /// while you are still standing there.
    ///
    /// Built with `nextDate(after:matching:)` rather than by adding 86,400 seconds, because on
    /// the two days a year the clocks move a day is not 86,400 seconds long and the photo
    /// would arrive an hour early or an hour late.
    public static func next(
        after moment: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        calendar.nextDate(
            after: moment.addingTimeInterval(minimumWait),
            matching: DateComponents(hour: hour, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? moment.addingTimeInterval(60 * 60 * 24)
    }

    /// Whether a photo taken then, developing at that time, can be looked at yet.
    ///
    /// `nil` means already developed. Every photo that existed before this rule shipped has
    /// no develop time, and a rule that retroactively hid people's existing memories would be
    /// a bug wearing a feature's clothes.
    public static func isDeveloped(_ developsAt: Date?, now: Date = .now) -> Bool {
        guard let developsAt else { return true }
        return now >= developsAt
    }

    /// How long left, for a caption. Nil once it has arrived.
    public static func remaining(until developsAt: Date?, now: Date = .now) -> DateComponents? {
        guard let developsAt, now < developsAt else { return nil }
        return Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: now, to: developsAt)
    }

    /// "in 14 hours" / "in 40 minutes". Deliberately coarse -- a countdown to the second
    /// turns waiting into watching, and the point is that you go and do something else.
    public static func spokenWait(until developsAt: Date?, now: Date = .now) -> String? {
        guard let parts = remaining(until: developsAt, now: now) else { return nil }
        let hours = parts.hour ?? 0
        if hours >= 1 { return "in \(hours) hour\(hours == 1 ? "" : "s")" }
        let minutes = max(parts.minute ?? 0, 1)
        return "in \(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}
