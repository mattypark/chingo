import Foundation
import UserNotifications
import ChinGoDesign

/// The one notification this app sends.
///
/// It says that a thing you already did is ready -- not that you should come back. That
/// distinction is the whole design: every notification in the research that people muted,
/// disabled or uninstalled over was an app asking for attention it had not earned, and the
/// ones people kept were the ones that reported an event the person was already invested in.
///
/// **One per morning, never one per photo.** Catch three people in an evening and three
/// pushes at nine the next morning would be the same mistake at a smaller scale. The
/// identifier is the date, so a second catch the same evening replaces the pending alert
/// rather than adding to it.
///
/// **Permission is asked in context**, after the first photo that has something to wait for --
/// never on launch. Apple's own guidance, and it is also the only moment where the ask makes
/// sense: there is now a specific photo, arriving at a specific time, and the alert is how
/// you find out.
///
/// **The app works fully without it.** App Review guideline 4.5.4 requires that, and it costs
/// nothing here: the photo develops whether or not anybody was told. Without permission the
/// album simply has one waiting for you when you next open it.
@MainActor
enum DevelopAlerts {

    private static let prefix = "develop-"

    /// Ask, once, at a moment where the ask explains itself.
    ///
    /// Returns whether alerts can be sent. A refusal is a normal outcome and not an error --
    /// roughly half of iOS users decline push, and the median for this app's category is 48%.
    @discardableResult
    static func requestPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        let settings = await centre.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            // Asking again does nothing -- iOS shows the prompt once. Anything further has to
            // be a link into Settings, offered where the toggle lives rather than here.
            return false
        default:
            return (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    /// Schedule (or replace) the alert for the morning `developsAt` falls on.
    ///
    /// `handles` is everyone whose photo lands that morning, so the body can name them
    /// instead of saying "1 new photo", which is the difference between a notification that
    /// reads as a message and one that reads as a badge.
    static func schedule(at developsAt: Date, handles: [String]) async {
        guard await requestPermission(), developsAt > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your yesterday developed"
        content.body = body(for: handles)
        content.sound = .default
        // Deliberately not time-sensitive. The HIG reserves that for something happening now
        // or within the hour, and warns that the first one prompts the user about breaking
        // Focus. A photo that has waited all night can wait for the person to pick the phone
        // up; spending a Focus interruption on it would be exactly the overreach this app is
        // supposed to be the alternative to.
        content.interruptionLevel = .active

        let parts = Calendar.autoupdatingCurrent.dateComponents(
            [.year, .month, .day, .hour, .minute], from: developsAt
        )
        let request = UNNotificationRequest(
            identifier: identifier(for: developsAt),
            content: content,
            // Non-repeating: each morning is its own request, so nothing lingers once it has
            // fired and the pending list stays a handful rather than growing forever.
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Drop every pending alert. Called when the setting is turned off, so the toggle governs
    /// what is already scheduled and not merely what happens next -- a switch that leaves
    /// yesterday's alerts armed is the reason people conclude these settings are fake.
    static func cancelAll() async {
        let centre = UNUserNotificationCenter.current()
        let pending = await centre.pendingNotificationRequests()
        centre.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        )
    }

    // MARK: Copy

    private static func body(for handles: [String]) -> String {
        let names = Array(Set(handles)).sorted()
        switch names.count {
        case 0: return "Open it up."
        case 1: return "\(names[0]) is ready."
        case 2: return "\(names[0]) and \(names[1]) are ready."
        default:
            let rest = names.count - 2
            return "\(names[0]), \(names[1]) and \(rest) more are ready."
        }
    }

    private static func identifier(for developsAt: Date) -> String {
        let parts = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: developsAt)
        return "\(prefix)\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
