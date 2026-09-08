import SwiftUI
import UIKit
import ChinGoDesign
import ChinGoEngine

/// Pick the icon on your home screen, and see the ones you have not earned.
///
/// **Locked icons are shown, not hidden.** A milestone nobody can see is not a milestone — the
/// whole value of unlocking one is knowing it was there. They are drawn at the same size in
/// their own artwork, dimmed, with the level they need under them, and they cannot be tapped.
///
/// **The alert is unavoidable and that shapes the whole feature.** `setAlternateIconName` always
/// shows "You have changed the icon for ChinGo" and there is no public way to suppress it.
/// Here that is fine: you asked, and the alert lands on the screen where you asked. It is the
/// reason the lapse icon next to this is opt-in — firing a system alert at somebody who is in
/// another app entirely is not something to do without being told to.
struct AppIconPicker: View {
    @Environment(\.accent) private var accent

    /// The catalogue name currently chosen, or nil for the shipped icon.
    @Binding var selection: String?
    /// What has been earned.
    let level: Int

    /// Set when the system refuses the change, which is nearly always "this icon is not in the
    /// bundle" — a name in `AppIcon.all` that never made it into the asset catalogue.
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Text("Your icon")
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.snug) {
                    ForEach(AppIcon.all) { icon in
                        cell(icon)
                    }
                }
                // Room for the hard shadows, which are drawn outside the tiles and clip
                // against the scroll view's edge without it.
                .padding(.vertical, Sticker.drop)
                .padding(.trailing, Sticker.drop)
            }

            if failed {
                // No whimsy in an error state. Says what happened and what it means.
                Text("That icon isn't available in this build.")
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textSoft)
            }
        }
    }

    private func cell(_ icon: AppIcon) -> some View {
        let chosen = icon.name == selection
        let unlocked = icon.unlocked(atLevel: level)

        return VStack(spacing: Space.hair) {
            Button {
                choose(icon)
            } label: {
                artwork(icon)
                    .frame(width: 62, height: 62)
                    // The corner every iOS icon is masked to. A square here would be the only
                    // place in the app showing an icon in a shape it never appears in.
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.45)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(chosen ? accent.signal : Ink.text, lineWidth: 3)
                    }
                    .compositingGroup()
                    .shadow(color: Ink.text, radius: 0, x: Sticker.drop, y: Sticker.drop)
            }
            .buttonStyle(SquashButtonStyle())
            .disabled(!unlocked)

            Text(unlocked ? icon.title : "Level \(icon.level)")
                .font(.chinFootnote)
                .foregroundStyle(unlocked ? Ink.text : Ink.textFaint)
                .lineLimit(1)
        }
        .frame(width: 74)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            unlocked
                ? "\(icon.title) icon\(chosen ? ", selected" : "")"
                : "\(icon.title) icon, locked until level \(icon.level)"
        )
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }

    /// The icon's own artwork, from the picker's own copy of it.
    ///
    /// See `AppIcon.previewAsset`: the appiconset cannot be drawn from, because
    /// `UIImage(named:)` answers with the primary icon whatever alternate you ask it for --
    /// which showed the same berry bear in all six tiles and looked exactly like the
    /// alternates had failed to ship.
    @ViewBuilder
    private func artwork(_ icon: AppIcon) -> some View {
        if let image = UIImage(named: icon.previewAsset) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            // The catalogue is missing it. Draw the shipped mascot rather than a blank tile,
            // which would look like the icon itself is broken.
            Image("Mascot").resizable().scaledToFit().padding(6).background(Ink.groundSunk)
        }
    }

    private func choose(_ icon: AppIcon) {
        guard icon.name != selection else { return }

        UIApplication.shared.setAlternateIconName(icon.name) { error in
            Task { @MainActor in
                // Only commit once the system has actually taken it. Writing the choice first
                // and letting the call fail silently leaves the picker showing an icon the
                // home screen does not have, which is the one bug in here nobody would report
                // because it looks like the app forgot.
                if error == nil {
                    selection = icon.name
                    failed = false
                } else {
                    failed = true
                }
            }
        }
    }
}
