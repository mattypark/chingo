import SwiftUI
import ChinGoDesign

/// Every permission on one screen, as switches.
///
/// This replaces a screen per permission, and the reason is not brevity. A dedicated screen
/// for a single permission has to justify itself, so it fills with copy, and a page of
/// argument in front of a system alert reads as pressure. A list of switches reads as a
/// settings page: here is what it wants, here is what each one buys you, decide.
///
/// **Flipping a switch fires the real prompt.** There is no "continue" that then shows three
/// alerts in a row. The switch is the request, so the system alert always arrives attached to
/// the thing the person just touched -- which is the whole of Apple's guidance on this and
/// also just how a switch is supposed to behave.
///
/// **Nothing here is required to finish.** Location off means the map has no fix and says so;
/// notifications off means a photo waits in the album instead of announcing itself. App Review
/// guideline 4.5.4 requires push to be optional, and the same principle is the right one for
/// location even though it is the app's whole premise: a first run that cannot be completed
/// without saying yes is a first run that teaches people to say yes without reading.
struct PermissionList: View {
    @Environment(\.accent) private var accent

    @Binding var wantsLocation: Bool
    @Binding var wantsNotifications: Bool
    var onLocation: () -> Void
    var onNotifications: () -> Void

    var body: some View {
        VStack(spacing: Space.snug) {
            row(
                icon: "location.fill",
                title: "Location",
                detail: "To see who's near you.",
                isOn: $wantsLocation,
                request: onLocation
            )
            row(
                icon: "bell.fill",
                title: "Notifications",
                detail: "For when a photo develops.",
                isOn: $wantsNotifications,
                request: onNotifications
            )

            // The safety line, which used to be a screen of its own. It is a caution, not a
            // decision, and a caution nobody has to tap past is one they might actually read.
            Text("ChinGo happens outside. Watch where you're going, and only meet people you actually want to meet.")
                .font(.chinFootnote)
                .foregroundStyle(Ink.textFaint)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Space.tight)
        }
    }

    private func row(
        icon: String,
        title: String,
        detail: String,
        isOn: Binding<Bool>,
        request: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Space.snug) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(accent.signal)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.chinHeadline)
                    .foregroundStyle(Ink.text)
                Text(detail)
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textSoft)
            }

            Spacer(minLength: Space.tight)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accent.signal)
                .onChange(of: isOn.wrappedValue) { was, now in
                    // Only on the way on. iOS shows each prompt once, so switching off and on
                    // again cannot re-ask -- and pretending otherwise by firing again would
                    // make the switch look broken. Turning one off is a note to ourselves not
                    // to schedule anything, which is what the settings screen honours too.
                    guard !was, now else { return }
                    request()
                }
        }
        .padding(Space.snug)
        .sticker(fill: Ink.groundRaised, radius: Radius.card)
        .padding(.trailing, Sticker.drop)
    }
}
