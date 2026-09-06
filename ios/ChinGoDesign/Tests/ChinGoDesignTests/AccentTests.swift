import Testing
import SwiftUI
@testable import ChinGoDesign

/// The accent is the one colour the app does not choose, so it is the one colour nothing
/// stops from being unreadable. A colour wheel would let someone pick pale yellow and then
/// put cream on it; a curated set only helps if the set is actually checked.
///
/// These measure. The app shipped a level badge at 3.05:1 -- cream on the coral -- for as
/// long as the accent was a single constant nobody could test, which is the argument for
/// the whole suite.
@Suite("Accent")
struct AccentTests {

    /// WCAG relative luminance. `Color.Resolved` already exposes linearised components, so
    /// this is the real formula rather than an approximation of it.
    private func luminance(_ colour: Color) -> Double {
        let c = colour.resolve(in: EnvironmentValues())
        return 0.2126 * Double(c.linearRed)
             + 0.7152 * Double(c.linearGreen)
             + 0.0722 * Double(c.linearBlue)
    }

    private func contrast(_ a: Color, _ b: Color) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    @Test("A label on the accent clears WCAG AA")
    func labelOnAccentIsReadable() {
        for accent in Accent.all {
            let ratio = contrast(accent.onSignal, accent.signal)
            #expect(ratio >= 4.5, "\(accent.name): label on fill is \(String(format: "%.2f", ratio)):1")
        }
    }

    @Test("The deep step is genuinely darker than the signal")
    func deepIsDeeper() {
        for accent in Accent.all {
            #expect(
                luminance(accent.signalDeep) < luminance(accent.signal),
                "\(accent.name): signalDeep is not darker than signal"
            )
        }
    }

    /// Rough chroma: the spread between the strongest and weakest channel. Enough to tell a
    /// saturated hue from a washed-out one, which is the only question being asked here.
    private func chroma(_ colour: Color) -> Double {
        let c = colour.resolve(in: EnvironmentValues())
        let channels = [Double(c.red), Double(c.green), Double(c.blue)]
        return channels.max()! - channels.min()!
    }

    /// The wash goes under the whole city, so it has to be measurably less saturated than
    /// the signal -- an accent at full chroma across the basemap leaves the accent nothing
    /// left to mean.
    ///
    /// Deliberately chroma and not contrast: several of these washes are *darker* than their
    /// signal, which raises their contrast against the pale land while plainly being calmer.
    /// Contrast would have called that failure.
    @Test("The map wash is less saturated than the signal it came from")
    func washIsQuiet() {
        for accent in Accent.all {
            let loud = chroma(accent.signal)
            let quiet = chroma(accent.mapWash)
            #expect(quiet < loud * 0.65, "\(accent.name): wash chroma \(quiet) vs signal \(loud)")
        }
    }

    @Test("Ids are 0 upward, unique, and match their position")
    func idsAreOrdinals() {
        #expect(Accent.all.count == 8)
        for (position, accent) in Accent.all.enumerated() {
            #expect(accent.id == position, "\(accent.name) is at \(position) but claims id \(accent.id)")
        }
        #expect(Set(Accent.all.map(\.id)).count == Accent.all.count)
    }

    @Test("Names are distinct, so two swatches never read as the same choice")
    func namesAreDistinct() {
        #expect(Set(Accent.all.map(\.name)).count == Accent.all.count)
    }

    /// `at` is read every frame from a number that came out of a database. A store written
    /// by a build with more accents, opened by this one, has to render a map.
    @Test("Out-of-range indices clamp instead of trapping")
    func indexClamps() {
        #expect(Accent.at(-1) == Accent.all.first)
        #expect(Accent.at(Int.min) == Accent.all.first)
        #expect(Accent.at(99) == Accent.all.last)
        #expect(Accent.at(Int.max) == Accent.all.last)
        for (position, accent) in Accent.all.enumerated() {
            #expect(Accent.at(position) == accent)
        }
    }

    /// Anyone who never opens the picker must not see their app change.
    @Test("Index 0 is still the coral the app shipped with")
    func firstAccentIsUnchanged() {
        #expect(Accent.fallback == Accent.all[0])
        let shipped = Color(hex: 0xFF5A3C).resolve(in: EnvironmentValues())
        let first = Accent.all[0].signal.resolve(in: EnvironmentValues())
        #expect(first.red == shipped.red && first.green == shipped.green && first.blue == shipped.blue)
    }
}
