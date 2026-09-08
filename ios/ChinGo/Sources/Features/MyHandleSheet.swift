import SwiftUI
import SwiftData
import ChinGoDesign

/// Your handle, big enough to read across a table.
///
/// The other half of "Add someone". There is no directory in ChinGo, so the only way anybody
/// gets you into their album is by you telling them what to type -- and "tell them your
/// handle" is a worse experience than it sounds when you are standing in a loud room reading
/// eight point type off your own profile.
///
/// So: one word, as large as it will go, on the player's own colour. Nothing else on the
/// screen. It is a thing you hold up.
struct MyHandleSheet: View {
    @Environment(\.accent) private var accent
    @Environment(\.modelContext) private var context

    @Query private var me: [MeRecord]
    @State private var copied = 0

    private var handle: String { me.first?.handle ?? "" }

    var body: some View {
        SheetShell("Your handle") {
            VStack(spacing: Space.section) {
                Spacer(minLength: 0)

                if handle.isEmpty {
                    // Gloria, because this is the bear pointing something out rather than the
                    // interface labelling a field.
                    Text("You haven't picked a handle yet. Set one on your profile and people can add you.")
                        .font(.chinHand)
                        .foregroundStyle(Ink.textSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.margin)
                } else {
                    // Your face above your name, because this screen is held out to somebody
                    // who is standing in front of you. A handle alone makes them check a
                    // spelling; a handle under the face they are looking at makes them check
                    // nothing.
                    PortraitWell(portraitFile: me.first?.portraitFile, diameter: 84)

                    Text(handle)
                        .font(.custom(Typeface.bagel, size: 46))
                        .foregroundStyle(accent.onSignal)
                        .lineLimit(1)
                        // Long handles shrink rather than truncate. A truncated handle is
                        // worse than a small one -- one is hard to read, the other is wrong.
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, Space.inset)
                        .padding(.vertical, Space.margin)
                        .frame(maxWidth: .infinity)
                        .sticker(fill: accent.signal, radius: Radius.surface)
                        .padding(.horizontal, Space.margin)
                        .padding(.trailing, Sticker.drop)

                    Button {
                        UIPasteboard.general.string = handle
                        copied += 1
                    } label: {
                        Text(copied > 0 ? "Copied" : "Copy")
                            .font(.custom(Typeface.bagel, size: 17))
                            .foregroundStyle(Ink.onSignal)
                            .padding(.horizontal, Space.section)
                            .padding(.vertical, Space.snug)
                    }
                    .buttonStyle(StickerButtonStyle(fill: Ink.text, outline: Ink.text, radius: Radius.surface))
                    .hitTarget()
                    .feedback(.pick, on: copied)
                    .animation(Motion.tap, value: copied)
                }

                Spacer(minLength: 0)

                Text("They type this in. There is no search, so nobody finds you without it.")
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.margin)
                    .padding(.bottom, Space.step)
            }
        }
    }
}
