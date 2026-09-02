import SwiftUI
import ChinGoDesign

/// One option in a menu that rises out of the button you pressed.
struct RadialOption: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    /// The centre option is drawn larger. Exactly one option should claim it.
    var isPrimary: Bool = false
    let action: () -> Void
}

/// A menu that comes out of its button rather than in from the system.
///
/// Deliberately not a sheet. A sheet slides up from the bottom of the screen no matter what
/// you pressed, which makes every panel feel like it came from iOS. These rise from the
/// control you touched and fall back into it, so the menu belongs to the button — the
/// Pokémon GO player-menu shape, and the reason it feels like part of the game rather than
/// part of the phone.
///
/// The map dims but stays visible underneath. Covering it entirely would mean losing the
/// thing the app is about for the sake of a four-item list.
struct RadialMenu: View {
    let title: String
    let options: [RadialOption]
    /// Where the menu grows from, in screen space.
    let anchor: UnitPoint
    var onClose: () -> Void

    @State private var open = false

    var body: some View {
        ZStack {
            // Tapping the dimmed map closes the menu. Every panel needs an escape that is not
            // the one control you might have missed.
            Ink.text.opacity(open ? 0.28 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: Space.step) {
                Spacer()

                Text(title)
                    .chinLabelStyle()
                    .foregroundStyle(Ink.onSignal)
                    .padding(.horizontal, Space.snug)
                    .padding(.vertical, Space.hair)
                    .background(Capsule().fill(Ink.text.opacity(0.55)))
                    .opacity(open ? 1 : 0)

                HStack(alignment: .bottom, spacing: Space.step) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        button(option, index: index)
                    }
                }

                CloseButton { close() }
                    .opacity(open ? 1 : 0)
                    .padding(.top, Space.tight)
            }
            .padding(.bottom, Space.section)
            .padding(.horizontal, Space.inset)
        }
        .onAppear {
            withAnimation(Motion.arrive) { open = true }
        }
    }

    private func button(_ option: RadialOption, index: Int) -> some View {
        let size: CGFloat = option.isPrimary ? 82 : 60

        return Button {
            close(then: option.action)
        } label: {
            VStack(spacing: Space.hair) {
                ZStack {
                    Circle()
                        .fill(option.isPrimary ? Ink.signal : Ink.groundRaised)
                        .elevated(option.isPrimary ? .card : .float)
                    Image(systemName: option.icon)
                        .font(.system(size: option.isPrimary ? 30 : 20, weight: .semibold))
                        .foregroundStyle(option.isPrimary ? Ink.onSignal : Ink.textSoft)
                }
                .frame(width: size, height: size)

                Text(option.label)
                    .chinLabelStyle()
                    .foregroundStyle(Ink.onSignal)
                    .padding(.horizontal, Space.tight)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Ink.text.opacity(0.55)))
            }
        }
        .buttonStyle(SquashButtonStyle())
        .hitTarget()
        // Staggered so the options arrive in sequence rather than as one block. The gap is
        // small enough to read as a single movement and large enough to have direction.
        .opacity(open ? 1 : 0)
        .scaleEffect(open ? 1 : 0.4, anchor: .bottom)
        .offset(y: open ? 0 : 40)
        .animation(Motion.arrive.delay(Double(index) * 0.045), value: open)
    }

    private func close(then action: (() -> Void)? = nil) {
        withAnimation(Motion.dismiss) { open = false }
        Task {
            // Let the menu actually leave before whatever it opened arrives on top of it.
            try? await Task.sleep(for: .milliseconds(180))
            onClose()
            action?()
        }
    }
}
