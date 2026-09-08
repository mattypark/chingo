import SwiftUI
import ChinGoDesign

/// Who is around, down the right edge.
///
/// The structure is lifted from GOAT's level rail: names stacked against the right margin,
/// one focus position, the rest falling away above and below it. What is *not* lifted is how
/// GOAT draws it -- there, focus is blur plus brightness, and both are banned here by name.
///
/// So focus is carried by weight and size instead, at full opacity throughout. The chosen name
/// is heavy and large over a 3pt accent rule; its neighbours step down in weight. Nothing
/// fades, nothing blurs, and the list still has an obvious middle.
///
/// **Gloria Hallelujah, and that overrules a rule.** `DESIGN.md` says Gloria is a person
/// speaking and never a control label. Matthew's call is that these names are exactly that --
/// a handwritten list of who is out there, in the app's own hand, rather than a system control
/// -- and the contract has been amended to say so instead of quietly broken.
///
/// The names were Bagel from the day this was written, which was wrong for the opposite
/// reason: Bagel is for numbers and two-word shouts, and at display weight over a park, with a
/// hard cream offset behind each one, the letterforms doubled and the rail looked embossed.
///
/// Gloria has no weight axis, so the focus ramp is carried entirely by size, and it is set
/// larger than either predecessor -- a handwriting face at 16 points over grass is a scribble.
/// Nothing sits behind the names: a plate would be a translucent fill, which this language
/// does not have.
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
        // `tight` rather than `hair`. Gloria slants and its descenders hang further than an
        // upright face's, so at 4pt the tail of one name touches the top of the next.
        VStack(alignment: .trailing, spacing: Space.tight) {
            ForEach(Array(listed.enumerated()), id: \.element.id) { index, person in
                let distance = abs(index - clampedFocus)

                Text(person.handle)
                    .font(.custom(Typeface.gloria, size: size(at: distance)))
                    .foregroundStyle(colour(at: distance))
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

    /// Three sizes, chosen rather than interpolated: a continuous ramp would put every row at
    /// its own arbitrary size, which is the uniformity the token sets exist to prevent, one
    /// step removed.
    ///
    /// Bigger than the sizes either earlier face used, because Gloria has a small x-height for
    /// its point size and only one weight -- so size is the only thing left to carry focus,
    /// and the whole ramp has to sit above the point where a handwriting face over grass stops
    /// being legible.
    private func size(at distance: Int) -> CGFloat {
        switch distance {
        case 0: 27
        case 1: 21
        default: 18
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
        // A step darker than the cream screens use. `textSoft` and `textFaint` are tuned
        // against the paper ground, and over a park `textFaint` is very nearly the same value
        // as the grass -- the count was there and unreadable, which is worse than absent.
        VStack(alignment: .trailing, spacing: 2) {
            Text(Distance.away(metres: listed[clampedFocus].approxMetres))
                .font(.chinCallout)
                .foregroundStyle(Ink.text)
            Text(people.count == 1 ? "1 person near you" : "\(people.count) people near you")
                .font(.chinFootnote)
                .foregroundStyle(Ink.textSoft)
        }
        .padding(.top, Space.tight)
        .contentTransition(.numericText())
    }

    private var empty: some View {
        // Gloria, because this is the bear talking rather than the interface labelling.
        Text("Nobody out here yet.")
            .font(.chinHand)
            .foregroundStyle(Ink.textSoft)
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
