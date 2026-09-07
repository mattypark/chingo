import SwiftUI
import ChinGoDesign

/// Who is around, down the right edge.
///
/// The structure is lifted from GOAT's level rail: names stacked against the right margin,
/// one focus position, the rest falling away above and below it. What is *not* lifted is how
/// GOAT draws it -- there, focus is blur plus brightness, and both are banned here by name.
///
/// So focus is carried by weight and size instead, at full opacity throughout. The chosen
/// name is Bagel over a 3pt accent rule; its neighbours step down through `textSoft` to
/// `textFaint`. Nothing fades, nothing blurs, and the list still has an obvious middle.
///
/// It exists because the map never said a single person was near you -- on an app whose whole
/// premise is collecting the people you meet.
struct NearbyRail: View {
    @Environment(\.accent) private var accent

    var people: [NearbyPerson]
    @Binding var focused: Int

    /// Bumped per name crossed, to hang the haptic on.
    @State private var picks = 0
    /// Focus at the moment the current drag began, so the whole gesture is measured from
    /// one origin rather than accumulating rounding error per frame.
    @State private var dragOrigin: Int?

    /// One row's worth of drag. Short enough that a flick moves several, long enough that a
    /// thumb resting on the screen does not.
    private static let rowTravel: CGFloat = 34
    /// Presence is inherently a short list -- people within a couple of hundred metres who
    /// have switched themselves visible. Capped anyway, because an unbounded stack of names
    /// would slide off both ends of the screen.
    private static let visible = 7

    private var listed: [NearbyPerson] { Array(people.prefix(Self.visible)) }

    var body: some View {
        VStack(alignment: .trailing, spacing: Space.tight) {
            if listed.isEmpty {
                empty
            } else {
                rail
                caption
            }
        }
        // The screen margin comes from the stack this sits in, alongside the two bars, so
        // the rail lines up with them rather than inventing its own edge.
        .frame(maxWidth: .infinity, alignment: .trailing)
        // Capped, and this is the one place in the app that caps anything. The rail is an
        // overlay on a live map with a fixed slot between two bars; past accessibility1 the
        // names start colliding with each other and the caption spans the whole screen,
        // covering the map it is annotating. Clamping keeps it legible and keeps the map
        // visible, and nothing here is only available visually -- every name is a labelled
        // button and the caption is read out with it.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .feedback(.pick, on: picks)
    }

    /// The list holds still and the focus moves through it.
    ///
    /// GOAT pins the focus to a fixed line and slides the list underneath, which is right for
    /// thirty brands and wrong for this: presence is two to five people, the whole list fits,
    /// and pinning the focus would make the entire rail jump up the screen every time you
    /// scrubbed one name. Same structure, opposite mechanic, because the data is not the same
    /// shape. What carries the choice is the size ramp and the rule, not the position.
    private var rail: some View {
        VStack(alignment: .trailing, spacing: Space.hair) {
            ForEach(Array(listed.enumerated()), id: \.element.id) { index, person in
                let distance = abs(index - clampedFocus)

                Text(person.handle)
                    .font(.custom(Typeface.bagel, size: size(at: distance)))
                    .foregroundStyle(colour(at: distance))
                    // A hard cream offset behind every name. The rail sits over a live map,
                    // and ink on a park is not the same problem as ink on the cream ground.
                    // This is the same trick as every other shadow in the app -- zero blur,
                    // one offset -- doing the job a blurred halo would otherwise do.
                    .shadow(color: Ink.ground, radius: 0, x: 2, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .overlay(alignment: .bottom) {
                        // The mark for "this one". A rule, not a chip: a filled shape out
                        // here competes with the map behind it, and the map is the product.
                        Rectangle()
                            .fill(accent.signal)
                            .frame(height: 3)
                            .offset(y: 3)
                            .opacity(distance == 0 ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { move(to: index) }
                    .accessibilityAddTraits(distance == 0 ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(Motion.reduceMotion ? nil : Motion.tap, value: clampedFocus)
        .gesture(scrub)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("People near you")
    }

    /// Bagel at three sizes. Chosen rather than interpolated: a continuous ramp would put
    /// every row at its own arbitrary size, which is the uniformity the token sets exist to
    /// prevent, one step removed.
    private func size(at distance: Int) -> CGFloat {
        switch distance {
        case 0: 26
        case 1: 18
        default: 15
        }
    }

    /// Two steps, not three. `textFaint` is tuned for cream and disappears over a park -- the
    /// size ramp already carries the hierarchy, so colour does not have to spend legibility
    /// buying something it has already paid for.
    private func colour(at distance: Int) -> Color {
        distance == 0 ? Ink.text : Ink.textSoft
    }

    /// How far away the focused person is, and how many there are. Both facts are coarse on
    /// purpose -- `approxMetres` is already rounded to the cell, and never a real distance to
    /// a real person.
    private var caption: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(Distance.away(metres: listed[clampedFocus].approxMetres))
                .font(.chinFootnote)
                .foregroundStyle(Ink.textSoft)
            Text(people.count == 1 ? "1 person near you" : "\(people.count) people near you")
                .font(.chinFootnote)
                .foregroundStyle(Ink.textFaint)
        }
        .padding(.top, Space.tight)
        .contentTransition(.numericText())
    }

    private var empty: some View {
        // Gloria, because this is the bear talking rather than the interface labelling.
        Text("Nobody out here yet.")
            .font(.chinHand)
            .foregroundStyle(Ink.textSoft)
            // Same hard cream offset the names get. Gloria is a lighter face than Bagel and
            // needs it more, not less, over a park.
            .shadow(color: Ink.ground, radius: 0, x: 2, y: 2)
            .multilineTextAlignment(.trailing)
            // Narrow enough to wrap onto two short lines and stay hard against the right
            // edge. On one line it reaches back across the middle of the screen and lands on
            // top of the player puck, which sits dead centre and never moves.
            .frame(maxWidth: 132, alignment: .trailing)
    }

    private var clampedFocus: Int {
        min(max(focused, 0), max(listed.count - 1, 0))
    }

    /// Drag to scrub the focus. Discrete: it ticks per name crossed and lands on one, which
    /// is a pick rather than a scroll -- the thing the haptic vocabulary rules out is a buzz
    /// tied to a continuously changing offset, and this is not one.
    private var scrub: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let origin = dragOrigin ?? clampedFocus
                dragOrigin = origin
                // Negated: dragging up pulls the list up, which brings the name below into
                // focus. The other direction reads as the list fighting the thumb.
                move(to: origin + Int((-value.translation.height / Self.rowTravel).rounded()))
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func move(to index: Int) {
        let next = min(max(index, 0), listed.count - 1)
        guard next != focused else { return }
        picks += 1
        if Motion.reduceMotion {
            focused = next
        } else {
            withAnimation(Motion.tap) { focused = next }
        }
    }
}
