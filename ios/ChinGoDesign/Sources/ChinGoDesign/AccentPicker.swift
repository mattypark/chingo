import SwiftUI

/// Eight swatches, one of them chosen.
///
/// Used twice -- once during onboarding, once in the profile editor -- so it lives here
/// rather than in either of them. The two call sites must not drift, because the second one
/// is where somebody goes to undo the first.
///
/// **The tick is not decoration.** It is drawn in the accent's own `onSignal`, which is the
/// exact colour every label on that accent will use. So the picker demonstrates the contrast
/// it is selling: whichever swatch you are looking at, the mark on it is the mark you get.
public struct AccentPicker: View {

    /// The chosen index. Bound straight to `MeRecord.bannerTint`.
    @Binding public var selection: Int

    /// Bumped on every change, purely to hang the haptic on. A pick is one of the five
    /// events the vocabulary allows.
    @State private var picks = 0

    /// Four across, two down. A single row of eight puts each swatch under 40pt on the
    /// narrowest phone, below the floor a thumb can reliably hit.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Space.snug), count: 4)

    public init(selection: Binding<Int>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(spacing: Space.step) {
            LazyVGrid(columns: columns, spacing: Space.snug) {
                ForEach(Accent.all) { accent in
                    swatch(accent)
                }
            }

            // The name of the one you are on. Below the grid rather than under each swatch,
            // because eight labels turn a colour choice into a reading task.
            Text(Accent.at(selection).name)
                .font(.custom(Typeface.bagel, size: 17))
                .foregroundStyle(Ink.text)
                .contentTransition(.opacity)
                .animation(Motion.tap, value: selection)
        }
        .feedback(.pick, on: picks)
    }

    private func swatch(_ accent: Accent) -> some View {
        let chosen = accent.id == selection

        return Button {
            guard !chosen else { return }
            picks += 1
            withAnimation(Motion.tap) { selection = accent.id }
        } label: {
            ZStack {
                Circle().fill(accent.signal)
                Circle().strokeBorder(Ink.text, lineWidth: 3)

                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(accent.onSignal)
                    .opacity(chosen ? 1 : 0)
                    .scaleEffect(chosen ? 1 : 0.4)
            }
            .frame(width: 54, height: 54)
            .compositingGroup()
            // The chosen one stands up off the page and the rest lie flat against it. Same
            // move as pressing a sticker, run backwards -- and no blur anywhere, which is
            // what the alternative (a glow, a ring, a fade) would have cost.
            .shadow(
                color: Ink.text,
                radius: 0,
                x: chosen ? Sticker.drop : 0,
                y: chosen ? Sticker.drop : 0
            )
            .scaleEffect(chosen ? 1 : 0.86)
        }
        .buttonStyle(.plain)
        .hitTarget()
        .accessibilityLabel(accent.name)
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }
}
