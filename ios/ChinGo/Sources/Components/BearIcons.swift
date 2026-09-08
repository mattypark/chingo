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
            let scale = lightness / max((tr + tg + tb) / 3, 0.001)
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
