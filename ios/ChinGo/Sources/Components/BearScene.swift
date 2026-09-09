import SwiftUI
import RealityKit
import ChinGoDesign

/// The bear, in three dimensions.
///
/// **Only the player's own bear.** Everybody else on the map stays a MapLibre symbol-layer
/// bitmap, and that is a decision rather than an unfinished job: symbols are drawn by the map
/// in its own pass, which is why twenty of them cost nothing. Twenty RealityKit entities on a
/// screen already running a tilted vector map and a GPS fix is a battery question, and
/// `project.yml` deliberately leaves 120Hz off for exactly that reason. One bear is a
/// character; twenty is a render budget.
///
/// **The body colour is slot 0, and the build script asserts it.** RealityKit hands materials
/// back as an array with no names attached, so the tint has to go in by index — and an index
/// into someone else's asset is the kind of dependency that rots without saying anything.
/// `assets/bear3d/build_bear.py` fails its own build if the order ever changes.
struct BearScene: View {
    /// Which accent to paint the body.
    var accent: Accent
    /// What the bear is doing.
    var motion: BearMotion
    /// Which way the bear is facing, in degrees, relative to the camera. Zero looks at you.
    ///
    /// A real rotation, which is the whole reason this exists. The flat bear it replaces had
    /// one front-on drawing and faked a profile with a horizontal squash and a mirror — that
    /// reads at a glance and can never put an ear in the right place, as `PlayerPuck`'s own
    /// comment admitted.
    var facing: Double = 0
    /// How far through a hug, 0 to 1. Driven straight from a finger rather than played as a
    /// clip — see `BearMotion.hugging`.
    var hug: Double = 0

    @State private var loaded: Entity?
    /// The parent the bear hangs off, so turning it does not fight the animation's own
    /// transforms on the model.
    @State private var turntable: Entity?
    @State private var failed = false

    /// Degrees about the vertical, as a quaternion.
    static func spin(_ degrees: Double) -> simd_quatf {
        simd_quatf(angle: Float(degrees * .pi / 180), axis: [0, 1, 0])
    }

    var body: some View {
        Group {
            if failed {
                // The bear is the app's face; a blank square where it should be reads as
                // broken rather than as loading. Falls back to the flat artwork, which is
                // still the same character.
                Image("Mascot").resizable().scaledToFit()
            } else {
                RealityView { content in
                    guard let bear = await BearAssets.shared.instance() else {
                        failed = true
                        return
                    }

                    // Painted and started here, not only in `update:`. Setting `@State` from
                    // inside `make:` does not itself schedule an update pass, so the first
                    // frame drew a berry bear standing still no matter what was asked for --
                    // and on a screen showing one motion that is every frame.
                    BearAssets.tint(bear, to: accent)
                    BearAssets.play(motion, on: bear, hug: hug)

                    let anchor = Entity()
                    anchor.addChild(bear)
                    content.add(anchor)
                    turntable = anchor
                    anchor.orientation = BearScene.spin(facing)

                    // An explicit camera, because the default one frames the whole scene and
                    // the whole scene is a one-metre bear in an empty world -- which it framed
                    // from about eight metres away and drew forty points tall inside a
                    // three-hundred point tile.
                    let camera = Entity()
                    camera.components.set(PerspectiveCameraComponent(
                        near: 0.05, far: 20, fieldOfViewInDegrees: 30
                    ))
                    camera.position = [0, 0.52, 2.6]
                    content.add(camera)

                    loaded = bear
                } update: { _ in
                    guard let loaded else { return }
                    BearAssets.tint(loaded, to: accent)
                    BearAssets.play(motion, on: loaded, hug: hug)
                    turntable?.orientation = BearScene.spin(facing)
                }
                .realityViewCameraControls(.none)
            }
        }
        .allowsHitTesting(false)
    }
}

/// What the bear is doing, and the one rule about which clip wins.
///
/// Ordered by how much it matters that you see it: a catch is the moment the app exists for
/// and interrupts anything, a hug is happening under a finger right now, walking beats
/// standing, and sleeping is what is left when nothing else is true.
enum BearMotion: Equatable {
    case idle
    case walking
    case sleeping
    case hugging
    case caught

    var clip: String {
        switch self {
        case .idle: "bear_idle"
        case .walking: "bear_walk"
        case .sleeping: "bear_sleep"
        case .hugging: "bear_hug"
        case .caught: "bear_catch"
        }
    }

    var loops: Bool {
        switch self {
        case .idle, .walking, .sleeping: true
        case .hugging, .caught: false
        }
    }
}

/// Loads the bear once and hands out copies.
///
/// An actor because `Entity(named:in:)` is async and every bear on screen would otherwise
/// start its own load of the same 800KB file. Cloning a loaded entity is cheap; parsing USD
/// six times is not.
@MainActor
final class BearAssets {
    static let shared = BearAssets()

    private var model: Entity?
    private var clips: [String: AnimationResource] = [:]

    /// A fresh copy of the bear, ready to add to a scene.
    func instance() async -> Entity? {
        if model == nil {
            model = try? await Entity(named: "bear", in: nil)
        }
        guard let model else { return nil }

        // Full size. The model is a metre tall and stands on zero; the camera does the
        // framing, so scaling here as well would be two things fighting over how big a bear
        // is and neither of them saying so.
        return model.clone(recursive: true)
    }

    /// Load a clip once and keep it. The clip files each carry a copy of the mesh — wasteful
    /// on disk and free at runtime, because only the animation is pulled out of them.
    private func clip(_ name: String) async -> AnimationResource? {
        if let cached = clips[name] { return cached }
        guard let source = try? await Entity(named: name, in: nil),
              let animation = source.availableAnimations.first
        else { return nil }
        clips[name] = animation
        return animation
    }

    /// Paint the body, and only the body.
    ///
    /// Found by name. The first version tinted material slot 0 on every mesh it walked past,
    /// which put an array index into someone else's asset at the centre of the feature — USD
    /// does not promise to hand slots back in the order they went in, and the bear arrived
    /// with a coral body and no face, because the ink had been repainted along with the fur.
    ///
    /// `build_bear.py` now emits three named meshes and asserts the names, so this can ask for
    /// the one it means. Tinting everything is the other obvious shortcut and it loses the
    /// two-tone that makes this the mascot rather than a bear-shaped blob.
    static func tint(_ entity: Entity, to accent: Accent) {
        var paint = PhysicallyBasedMaterial()
        paint.baseColor = .init(tint: UIColor(accent.signal))
        paint.roughness = 0.62
        paint.metallic = 0.0

        entity.repaint(matching: BearAssets.berry, with: paint)
    }

    /// The body colour `build_bear.py` ships the model in, and the only thing the app repaints.
    ///
    /// Matching on colour rather than on a name, after trying names twice. `usdcat` shows the
    /// prims are called `BearBody`, `BearCream` and `BearInk` in the file — but neither
    /// `findEntity(named:)` nor skipping subtrees by name did anything at runtime, so the
    /// names do not survive the import even though they survive the format. Painting by name
    /// left a berry bear; skipping by name painted the eyes and the muzzle too.
    ///
    /// Colour survives everything. The three are far apart in any colour space — a saturated
    /// mid magenta, a near-white cream and a near-black ink — so nearest-of-three is not a
    /// close call, and it holds up if the meshes are renamed, reordered or re-split.
    static let berry = SIMD3<Float>(0.478, 0.180, 0.322)

    /// Start the clip for a motion, if it is not already the one playing.
    static func play(_ motion: BearMotion, on entity: Entity, hug: Double) {
        Task { @MainActor in
            guard let animation = await BearAssets.shared.clip(motion.clip) else { return }

            if motion == .hugging {
                // Driven, not played. A hug that plays as a clip finishes on its own schedule
                // while the finger is still down, which is exactly the "looks like it has
                // agency and does not react" failure `MascotOrb` was written against.
                let controller = entity.playAnimation(animation, transitionDuration: 0)
                controller.speed = 0
                controller.time = animation.definition.duration * hug
                return
            }

            entity.playAnimation(
                animation.repeat(duration: motion.loops ? .infinity : animation.definition.duration),
                // Long enough to blend rather than snap. Standing still and then walking is
                // one continuous thing when it happens to a real body.
                transitionDuration: 0.28,
                startsPaused: false
            )
        }
    }
}

private extension Entity {
    /// Repaint every material that is currently this colour, anywhere under this entity.
    ///
    /// USD import nests meshes inside transform prims, so the thing carrying materials is
    /// never the entity you were handed and this has to recurse.
    func repaint(matching source: SIMD3<Float>, with material: PhysicallyBasedMaterial) {
        if let model = self as? ModelEntity, var component = model.model {
            component.materials = component.materials.map { existing in
                guard let pbr = existing as? PhysicallyBasedMaterial,
                      pbr.baseColor.tint.isNear(source)
                else { return existing }
                return material
            }
            model.model = component
        }
        for child in children {
            child.repaint(matching: source, with: material)
        }
    }
}

private extension UIColor {
    /// Whether this is the colour we are looking for, allowing for the round trip through USD.
    ///
    /// Generous, because the export writes linear values and the import may hand them back
    /// through a colour space of its own choosing. The three colours in this model are far
    /// enough apart that a loose threshold still cannot confuse them — and a false negative is
    /// a bear that keeps its default berry, which is a colour rather than a crash.
    func isNear(_ target: SIMD3<Float>, tolerance: Float = 0.22) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return false }

        let here = SIMD3<Float>(Float(r), Float(g), Float(b))
        // **One colour space, and that is the fix rather than a tidy-up.** This used to accept
        // a match against either the linear value or its sRGB encoding, on the reasoning that
        // the importer might hand back either. It hands back sRGB — and the near-black of the
        // eyes, encoded, lands 0.21 away from berry in *linear*, which slipped inside a 0.22
        // tolerance and painted the bear's eyes and nose the player's colour.
        //
        // Against sRGB alone the three are 0.45 and 0.64 apart, so the threshold is nowhere
        // near a close call.
        let encoded = SIMD3<Float>(
            target.x.srgbEncoded, target.y.srgbEncoded, target.z.srgbEncoded
        )
        return distance(here, encoded) < tolerance
    }
}

private extension Float {
    var srgbEncoded: Float {
        self <= 0.0031308 ? self * 12.92 : 1.055 * pow(self, 1 / 2.4) - 0.055
    }
}
