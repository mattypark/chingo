import SwiftUI
import ChinGoDesign

/// One option on a takeover menu.
struct RadialOption: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    /// The centre option, drawn larger. Exactly one option should claim it.
    var isPrimary: Bool = false
    let action: () -> Void
}

/// The catch menu: options scattered around a centre, not lined up in a row.
///
/// The arrangement is the Pokémon GO player-menu shape — two above, one in the middle, two
/// below, close button under all of it. A row reads as a toolbar and gets scanned left to
/// right; a scatter reads as a place you are standing in, and the eye goes to the middle
/// first, which is where the thing you came for lives.
///
/// Sizes are deliberately smaller than a normal control. These sit on an empty field with
/// nothing to compete with, so they do not need to shout, and a 100pt circle on a phone reads
/// as a mistake rather than as emphasis.
struct RadialMenu: View {
    let title: String
    let options: [RadialOption]
    var onClose: () -> Void

    @State private var open = false

    /// Where each option sits, as a fraction of the menu area. Centre first, so the primary
    /// option lands there whatever order the caller passes.
    private static let slots: [UnitPoint] = [
        UnitPoint(x: 0.50, y: 0.50),   // centre — the primary
        UnitPoint(x: 0.22, y: 0.24),   // upper left
        UnitPoint(x: 0.78, y: 0.24),   // upper right
        UnitPoint(x: 0.22, y: 0.76),   // lower left
        UnitPoint(x: 0.78, y: 0.76),   // lower right
    ]

    /// Primary to the centre slot, everything else outward in the order given.
    private var placed: [(option: RadialOption, slot: UnitPoint)] {
        var remaining = Self.slots
        let centre = remaining.removeFirst()
        var result: [(RadialOption, UnitPoint)] = []

        if let primary = options.first(where: \.isPrimary) {
            result.append((primary, centre))
        }
        for option in options where !option.isPrimary {
            guard !remaining.isEmpty else { break }
            result.append((option, remaining.removeFirst()))
        }
        return result
    }

    var body: some View {
        ZStack {
            MenuBackdrop(onTap: { close() })
                .opacity(open ? 1 : 0)

            VStack(spacing: 0) {
                Text(title)
                    .font(.chinCallout)
                    .foregroundStyle(Ink.onSignal.opacity(0.62))
                    .padding(.top, Space.section)

                GeometryReader { geo in
                    ForEach(Array(placed.enumerated()), id: \.element.option.id) { index, entry in
                        button(entry.option, index: index)
                            .position(
                                x: geo.size.width * entry.slot.x,
                                y: geo.size.height * entry.slot.y
                            )
                    }
                }

                CloseButton { close() }
                    .opacity(open ? 1 : 0)
                    .padding(.bottom, Space.section)
            }
        }
        .onAppear { withAnimation(Motion.arrive) { open = true } }
    }

    private func button(_ option: RadialOption, index: Int) -> some View {
        let size: CGFloat = option.isPrimary ? 74 : 58

        return VStack(spacing: Space.snug) {
            Button {
                close(then: option.action)
            } label: {
                Image(systemName: option.icon)
                    .font(.system(size: option.isPrimary ? 28 : 21, weight: .bold))
                    .foregroundStyle(option.isPrimary ? Ink.berryDeep : Ink.text)
                    .frame(width: size, height: size)
            }
            // Opaque, outlined, hard-shadowed. The translucent-fill-with-hairline version
            // this replaces was the single most Pokemon-GO-looking thing in the app.
            .buttonStyle(StickerCircleStyle(fill: option.isPrimary ? Ink.signal : Ink.ground))
            .hitTarget()

            MenuLabel(option.label)
        }
        .opacity(open ? 1 : 0)
        .scaleEffect(open ? 1 : 0.5)
        .animation(Motion.arrive.delay(Double(index) * 0.04), value: open)
    }

    private func close(then action: (() -> Void)? = nil) {
        withAnimation(Motion.dismiss) { open = false }
        Task {
            // Let the menu leave before whatever it opened arrives on top of it.
            try? await Task.sleep(for: .milliseconds(180))
            onClose()
            action?()
        }
    }
}

/// The deck menu: a right-aligned column, label then icon.
///
/// A different shape from the catch menu on purpose. That one is a place you stand in the
/// middle of; this one is a list of things you might go and do, and a list should read as a
/// list. Right-aligned because it opens from the bottom-right button and belongs to it.
struct ListMenu: View {
    let options: [RadialOption]
    var onClose: () -> Void

    @State private var open = false

    var body: some View {
        ZStack {
            MenuBackdrop(onTap: { close() })
                .opacity(open ? 1 : 0)

            VStack(spacing: Space.step) {
                Spacer()

                // The rows hug the right edge; the close button does not. Centring it inside
                // a trailing-aligned stack lands it off-centre by exactly the stack's own
                // padding, which is the kind of misalignment that looks like carelessness
                // rather than intent.
                VStack(alignment: .trailing, spacing: Space.snug) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        row(option, index: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, Space.margin)

                CloseButton { close() }
                    .opacity(open ? 1 : 0)
            }
            .padding(.bottom, Space.section)
        }
        .onAppear { withAnimation(Motion.arrive) { open = true } }
    }

    private func row(_ option: RadialOption, index: Int) -> some View {
        Button {
            close(then: option.action)
        } label: {
            HStack(spacing: Space.snug) {
                Image(systemName: option.icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Ink.text)
                    .frame(width: 26)

                Text(option.label)
                    .font(.custom(Typeface.bagel, size: 19))
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, Space.inset)
            .padding(.vertical, Space.snug)
        }
        // Bagel on a solid pill, not thin caps floating on a gradient. The label is the
        // button now, which is what a heavy typeface wants to be.
        .buttonStyle(StickerButtonStyle(fill: Ink.ground, radius: Radius.surface))
        .hitTarget()
        .opacity(open ? 1 : 0)
        // Rows arrive from the right, the side they belong to.
        .offset(x: open ? 0 : 40)
        .animation(Motion.arrive.delay(Double(index) * 0.05), value: open)
    }

    private func close(then action: (() -> Void)? = nil) {
        withAnimation(Motion.dismiss) { open = false }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            onClose()
            action?()
        }
    }
}
