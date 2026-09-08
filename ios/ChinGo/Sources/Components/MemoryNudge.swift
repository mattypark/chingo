import SwiftUI
import ChinGoDesign

/// "You met somebody here."
///
/// Arrives when you walk inside a memory's radius and names who and when. Tapping opens it.
///
/// **Why this is in-app and not a push.** `LocationService` is When-In-Use by deliberate
/// design -- no background updates, no significant-change monitoring, no Always. Region
/// monitoring only delivers to a backgrounded app under Always, so a real push version of
/// this would mean asking for permanent background location on a social map, which is the
/// exact posture the location comment already refuses. The trade is honest rather than
/// grudging: this is a game you play with the app open and walking, so the moment it needs to
/// catch is a moment it is already on screen.
///
/// **Why it is a strip and not an alert.** It reports something that is true whether or not
/// you look at it, and it must never interrupt a walk. It slides in, it waits, it goes. The
/// map underneath stays live and stays tappable, and the only thing it can cost you is the
/// eight seconds of screen it occupies.
struct MemoryNudge: View {
    @Environment(\.accent) private var accent

    let memory: MemoryRecord
    var onOpen: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Space.snug) {
                thumbnail

                VStack(alignment: .leading, spacing: 1) {
                    Text("You met \(memory.friendHandle) here")
                        .font(.chinBody)
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                    Text(when)
                        .font(.chinFootnote)
                        .foregroundStyle(Ink.textSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: Space.tight)

                // Explicit dismiss as well as the timer. A strip that can only be waited out
                // is one you cannot get rid of when you are trying to look at the map under it.
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Ink.textSoft)
                        .hitTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(.leading, Space.tight)
            .padding(.trailing, Space.hair)
            .padding(.vertical, Space.tight)
            .sticker(fill: Ink.groundRaised, radius: Radius.card)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You met \(memory.friendHandle) here, \(when). Open it.")
        .accessibilityAddTraits(.isButton)
    }

    private var thumbnail: some View {
        Group {
            if !memory.isDeveloped {
                // Not an error state -- the frame says "there is something here" and the
                // sheet behind it says when.
                accent.signal.overlay {
                    Image(systemName: "hourglass")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent.onSignal)
                }
            } else if let image = PhotoStore.load(memory.photoFile) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                // Developed but nothing to show: a tag rather than a photo, or a file that has
                // gone missing. Separate from the case above on purpose -- an hourglass here
                // would promise a picture that is never coming.
                Ink.groundSunk.overlay {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Ink.textFaint)
                }
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Ink.text, lineWidth: 3)
        }
    }

    /// Relative, not a date. "Three weeks ago" is what a person remembers; "14 August" is what
    /// a filing system remembers.
    private var when: String {
        let style = Date.RelativeFormatStyle(presentation: .named, unitsStyle: .wide)
        return memory.happenedOn.formatted(style)
    }
}
