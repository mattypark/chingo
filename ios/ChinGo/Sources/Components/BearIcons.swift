import UIKit
import SwiftUI
import ChinGoDesign

/// Every bear the map can draw, generated once at launch.
///
/// MapLibre's symbol layer draws registered images by name, so each player's colour and each
/// step of the walk has to exist as its own bitmap. That would normally mean an artist
/// producing eight colourways times three frames. It does not here, because the mascot is
/// already the right shape and already two-tone: a saturated body and a near-neutral cream
/// belly and muzzle.
///
/// **Recoloured by saturation, not by multiply.** A flat multiply over the berry mascot turns
/// cobalt into mud and loses the belly entirely. Instead each pixel is judged: strongly
/// coloured pixels take the accent's hue and keep their own lightness, so the render's
/// shading survives; the cream stays cream. That is exactly how the source pose sheet is
/// built -- a coloured body with a cream front -- so this reproduces the art rather than
/// tinting over it.
///
/// **The walk is derived, not drawn.** Three frames per colour, made by squashing and leaning
/// the one pose. A bear seen from the front does not swing its legs visibly at this size; it
/// bobs. That is the whole animation, and it is what the existing `MascotOrb` idle already
/// does in SwiftUI.
enum BearIcons {

    /// Edge length of a generated icon. Small on purpose -- on screen a bear is about 60
    /// points tall, so this is already generous on a 3x device, and twenty-four of them at
    /// full source resolution would be forty megabytes for no visible gain.
    private static let side: CGFloat = 192

    /// How many steps the walk cycles through.
    static let walkFrames = 3

    /// `bear-<accent>-idle` or `bear-<accent>-walk<n>`.
    static func name(accent: Int, phase: Int?) -> String {
        guard let phase else { return "bear-\(accent)-idle" }
        return "bear-\(accent)-walk\(phase % walkFrames)"
    }

    static let shadowName = "bear-shadow"

    /// Every image the layers can ask for, keyed by the name above.
    ///
    /// Built once and held, because regenerating twenty-four bitmaps on every style reload --
    /// which is what changing accent does -- would stutter the map.
    static let all: [String: UIImage] = build()

    private static func build() -> [String: UIImage] {
        guard let source = UIImage(named: "Mascot") else { return [:] }
        let base = downscaled(source, to: side)

        var images: [String: UIImage] = [shadowName: shadow()]
        for accent in Accent.all {
            guard let tinted = recoloured(base, to: accent.signal) else { continue }
            images[name(accent: accent.id, phase: nil)] = tinted
            for phase in 0..<walkFrames {
                images[name(accent: accent.id, phase: phase)] = stepped(tinted, phase: phase)
            }
        }
        return images
    }

    // MARK: Colour

    /// Replaces the hue of coloured pixels while keeping their lightness, and leaves
    /// near-neutral pixels alone.
    private static func recoloured(_ image: UIImage, to colour: Color) -> UIImage? {
        guard let source = image.cgImage else { return nil }
        let (width, height) = (source.width, source.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        let target = colour.resolve(in: EnvironmentValues())
        let (tr, tg, tb) = (Double(target.red), Double(target.green), Double(target.blue))

        // What "normal body colour" is on this render, measured rather than assumed.
        //
        // Without it the shading is normalised against the *accent's* lightness instead of the
        // source's, and every accent comes out at the lightness of the berry body it replaced
        // -- a dark plum. Coral arrived as chestnut brown, which is the correct answer to the
        // wrong question: it preserved the render's shading so faithfully that the colour the
        // player picked stopped being visible.
        let bodyLevel = bodyLightness(of: pixels)

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = Double(pixels[i + 3]) / 255
            guard a > 0.01 else { continue }
            // Un-premultiply before judging the colour, or every soft edge reads as neutral.
            let r = Double(pixels[i]) / 255 / a
            let g = Double(pixels[i + 1]) / 255 / a
            let b = Double(pixels[i + 2]) / 255 / a

            let high = max(r, g, b), low = min(r, g, b)
            let chroma = high - low
            // Cream, white and the eyes' near-black are all low-chroma and all stay.
            guard chroma > 0.14 else { continue }

            // Keep this pixel's own lightness so the render's shading survives; take the
            // accent's colour. Full strength on the strongly coloured pixels, easing off
            // through the anti-aliased edge so nothing gets a hard rim.
            let lightness = (high + low) / 2
            let strength = min((chroma - 0.14) / 0.20, 1)
            // Clamped, so a specular highlight cannot wash the accent out to white and a deep
            // shadow cannot take it to black. The bear has to stay recognisably one colour.
            let scale = min(max(lightness / bodyLevel, 0.62), 1.38)
            let mix = { (channel: Double, tint: Double) -> Double in
                let lit = min(tint * scale, 1)
                return channel + (lit - channel) * strength
            }
            pixels[i] = UInt8(min(mix(r, tr) * a * 255, 255))
            pixels[i + 1] = UInt8(min(mix(g, tg) * a * 255, 255))
            pixels[i + 2] = UInt8(min(mix(b, tb) * a * 255, 255))
        }

        return context.makeImage().map { UIImage(cgImage: $0, scale: image.scale, orientation: .up) }
    }

    /// The dominant lightness of the coloured pixels -- what "body colour" means on this
    /// render, so a body pixel can be made to land exactly on the accent.
    ///
    /// **Median, not mean, and the difference is the whole thing.** The mascot's coloured
    /// pixels are sharply bimodal: 400k of them sit at lightness 0.32 (the body) and 97k at
    /// 0.86 (the peach muzzle and belly, which carry enough chroma to count). Their mean is
    /// 0.44, which describes neither cluster -- it lands in the empty gap between them, so
    /// the body normalises to 0.74 of the accent and every bear comes out a shade of brick.
    /// The median lands in the body, where the answer is.
    ///
    /// Counted into 256 buckets rather than sorted, because this runs over 24 bitmaps at
    /// launch and sorting half a million doubles per bitmap to find one number is not a
    /// reasonable way to start an app.
    ///
    /// Falls back to a mid grey if the source has no coloured pixels at all, which would
    /// otherwise divide by zero and render every bear white.
    private static func bodyLightness(of pixels: [UInt8]) -> Double {
        var buckets = [Int](repeating: 0, count: 256)
        var count = 0

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = Double(pixels[i + 3]) / 255
            guard a > 0.01 else { continue }
            let r = Double(pixels[i]) / 255 / a
            let g = Double(pixels[i + 1]) / 255 / a
            let b = Double(pixels[i + 2]) / 255 / a
            let high = max(r, g, b), low = min(r, g, b)
            guard high - low > 0.14 else { continue }
            buckets[min(Int((high + low) / 2 * 255), 255)] += 1
            count += 1
        }
        guard count > 0 else { return 0.5 }

        var seen = 0
        for (level, tally) in buckets.enumerated() {
            seen += tally
            if seen * 2 >= count { return Double(level) / 255 }
        }
        return 0.5
    }

    // MARK: Motion

    /// One step of the walk: a squash and a lean, anchored at the feet.
    ///
    /// Anchored at the feet because the bear is standing on a street. Scaling about the centre
    /// makes it hover and sink, which is the single most common way a map avatar stops looking
    /// like it is on the ground.
    private static func stepped(_ image: UIImage, phase: Int) -> UIImage {
        let squash: [CGFloat] = [1.0, 0.94, 1.03]
        let lean: [CGFloat] = [0, -3.5, 3.5]
        let size = image.size

        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            cg.translateBy(x: size.width / 2, y: size.height)
            cg.rotate(by: lean[phase] * .pi / 180)
            cg.scaleBy(x: 2 - squash[phase], y: squash[phase])
            cg.translateBy(x: -size.width / 2, y: -size.height)
            image.draw(at: .zero)
        }
    }

    /// The ellipse the bear stands on.
    ///
    /// Drawn flat and hard-edged, and laid on the ground by the layer rather than by this
    /// image -- see `iconPitchAlignment` at the call site. A soft blob would be the one
    /// blurred thing on a screen where nothing else is.
    private static func shadow() -> UIImage {
        let size = CGSize(width: side, height: side * 0.42)
        return UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.setFillColor(UIColor(Ink.text).withAlphaComponent(0.34).cgColor)
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func downscaled(_ image: UIImage, to side: CGFloat) -> UIImage {
        let scale = side / max(image.size.width, image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
