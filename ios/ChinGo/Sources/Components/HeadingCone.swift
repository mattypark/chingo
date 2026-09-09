import SwiftUI
import ChinGoDesign

/// The wedge on the ground showing which way you are facing.
///
/// Lifted from Bump, and from every map app that has one, because it answers a question the
/// map cannot: the bear tells you *where* you are and this tells you which way you are pointed.
/// Matthew's own words on noticing it work — "I'm pointing north and it detects that I'm
/// actually pointing north" — are the whole argument for having it.
///
/// **It is the second soft thing allowed on this map, and it is allowed for the first one's
/// reason.** `DESIGN.md` bans translucent fills and soft edges by name, and `SkyBand` is the
/// standing exception because it is not printed on the world — it *is* the world. A heading
/// cone is the same kind of object: it is a beam falling on the ground, and a beam with a 3pt
/// ink outline and a hard drop shadow would be a printed arrow, which is a different and much
/// worse thing. Nothing else gets this.
///
/// **It lies on the ground, not on the screen.** The map is raked, so a wedge drawn upright
/// would stand in front of the bear like a card. It is squashed vertically by the same ratio
/// the contact shadow uses, which is what puts it on the road.
struct HeadingCone: View {
    /// Which way, in screen degrees — zero points up the screen, the same convention the
    /// bear's own facing uses.
    var facing: Double
    /// The player's colour. Bump's is blue because Bump has one colour; this one is whichever
    /// the player chose, so the cone and the bear it comes out of agree.
    var tint: Color
    /// How far the beam reaches, in points.
    var reach: CGFloat

    /// How wide the beam opens. Narrow enough to mean a direction rather than a region — past
    /// about 60 degrees it stops reading as pointing and starts reading as lighting.
    private static let spread: Double = 46

    var body: some View {
        Wedge(spread: Self.spread)
            .fill(
                // Bright where it leaves the bear, gone by the end. A beam that stays solid to
                // its tip reads as a shape with an edge, which is the one thing this must not
                // have — it would become an arrow drawn on the road.
                LinearGradient(
                    colors: [tint.opacity(0.62), tint.opacity(0.22), tint.opacity(0)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: reach * 1.5, height: reach)
            // The ground plane. Same squash as the contact shadow, so the two agree about
            // where the floor is.
            .scaleEffect(y: 0.42, anchor: .bottom)
            .rotationEffect(.degrees(facing), anchor: .bottom)
            .allowsHitTesting(false)
    }
}

/// A triangle opening upward from the bottom-centre, with a rounded far edge.
private struct Wedge: Shape {
    /// Total opening angle, in degrees.
    var spread: Double

    func path(in rect: CGRect) -> Path {
        let apex = CGPoint(x: rect.midX, y: rect.maxY)
        let half = (spread / 2) * .pi / 180
        let reach = rect.height

        var path = Path()
        path.move(to: apex)
        // Swept as an arc rather than closed with a straight line, so the far end of the beam
        // is a constant distance from the bear. A flat end is further away at the corners than
        // in the middle, which reads as a triangle rather than as a cone of light.
        path.addArc(
            center: apex,
            radius: reach,
            startAngle: .radians(-.pi / 2 - half),
            endAngle: .radians(-.pi / 2 + half),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
