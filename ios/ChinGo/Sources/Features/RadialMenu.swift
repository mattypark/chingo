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
    @Environment(\.accent) private var accent

    let title: String
    let options: [RadialOption]
    var onClose: () -> Void

    @State private var open = false

    /// The centre. Deliberately low: the button that opens this menu is at the bottom of the
    /// screen, and a cluster floating in the middle makes the thumb travel up to reach what
    /// it just pressed. Sitting the camera right above the real button means the menu opens
    /// where the hand already is.
    private static let centreSlot = UnitPoint(x: 0.50, y: 0.78)

    /// Where the satellites go, by how many there are.
    ///
    /// Not a fixed list. With a fixed grid, dropping an option leaves the survivors hanging
    /// off one side and the whole cluster looks broken rather than smaller. One satellite
    /// sits straight above the centre; two split evenly either side.
    private static func satelliteSlots(count: Int) -> [UnitPoint] {
        switch count {
        case 0: []
        case 1: [UnitPoint(x: 0.50, y: 0.52)]
        case 2: [UnitPoint(x: 0.21, y: 0.56), UnitPoint(x: 0.79, y: 0.56)]
        default: [
            UnitPoint(x: 0.19, y: 0.58),
            UnitPoint(x: 0.50, y: 0.48),
            UnitPoint(x: 0.81, y: 0.58),
        ]
        }
    }

    /// Primary to the centre, everything else spread above it.
    private var placed: [(option: RadialOption, slot: UnitPoint)] {
        let satellites = options.filter { !$0.isPrimary }
        var remaining = Self.satelliteSlots(count: satellites.count)
        var result: [(RadialOption, UnitPoint)] = []

        if let primary = options.first(where: \.isPrimary) {
            result.append((primary, Self.centreSlot))
        }
        for option in satellites {
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
                    // Drawn first so the buttons sit on top of where the lines end.
                    Connectors(
                        centre: point(Self.centreSlot, in: geo.size),
                        satellites: placed.dropFirst().map { point($0.slot, in: geo.size) }
                    )
                    .opacity(open ? 1 : 0)
                    .animation(Motion.arrive.delay(0.08), value: open)

                    ForEach(Array(placed.enumerated()), id: \.element.option.id) { index, entry in
                        button(entry.option, index: index)
                            .position(point(entry.slot, in: geo.size))
                    }
                }

                CloseButton { close() }
                    .opacity(open ? 1 : 0)
                    .padding(.bottom, Space.section)
            }
        }
        .onAppear { withAnimation(Motion.arrive) { open = true } }
    }

    private func point(_ slot: UnitPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * slot.x, y: size.height * slot.y)
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
            .buttonStyle(StickerCircleStyle(fill: option.isPrimary ? accent.signal : Ink.ground))
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

                // Under the rows, not centred on the screen. This menu opens from the
                // bottom-right button and the thumb that opened it is already over there;
                // sending it back to the middle to close is a trip for nothing.
                CloseButton { close() }
                    .opacity(open ? 1 : 0)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.trailing, Space.margin)
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


/// The bubbly lines tying the options to the middle.
///
/// Thick, rounded, and bowed rather than straight, with a blob at each end — the same idea as
/// the typeface: no thin strokes, no sharp terminals. A straight hairline between two buttons
/// would read as a wireframe annotation; a fat curve reads as something drawn.
///
/// They also do real work. Without them the satellites look like three unrelated buttons
/// scattered on a field; with them the camera is visibly the centre and the others hang off it.
private struct Connectors: View {
    let centre: CGPoint
    let satellites: [CGPoint]

    var body: some View {
        ZStack {
            ForEach(Array(satellites.enumerated()), id: \.offset) { _, target in
                let path = curve(from: centre, to: target)

                path
                    .stroke(
                        Ink.onSignal.opacity(0.42),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )

                // A blob where the line meets the satellite, so the stroke ends in something
                // round rather than simply stopping. Wider than the stroke, so it reads as a
                // terminal rather than as the line getting thicker.
                Circle()
                    .fill(Ink.onSignal.opacity(0.42))
                    .frame(width: 15, height: 15)
                    .position(blobPoint(from: centre, to: target))
            }
        }
        .allowsHitTesting(false)
    }

    /// A single quadratic bow, always arcing upward, so the two lines mirror each other
    /// instead of bending whichever way the geometry happens to fall.
    private func curve(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        // The centre end clears its own circle; the satellite end has to clear its circle
        // *and* the label underneath it, or the line runs straight through the caption.
        let start = inset(from: from, towards: to, by: 46)
        let end = inset(from: to, towards: from, by: 66)
        let span = abs(start.x - end.x)
        let control = CGPoint(
            // A straight vertical run has no horizontal span to bow from, so it gets a fixed
            // sideways kick instead of collapsing into a plain line.
            x: (start.x + end.x) / 2 + (span < 24 ? 26 : 0),
            y: min(start.y, end.y) - max(span * 0.22, 18)
        )
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }

    /// Pulls a line end back out of the button it points at, so the stroke stops at the
    /// button's edge rather than disappearing under it.
    private func inset(from: CGPoint, towards: CGPoint, by distance: CGFloat) -> CGPoint {
        let dx = towards.x - from.x
        let dy = towards.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        return CGPoint(x: from.x + dx / length * distance, y: from.y + dy / length * distance)
    }

    private func blobPoint(from: CGPoint, to: CGPoint) -> CGPoint {
        inset(from: to, towards: from, by: 66)
    }
}
