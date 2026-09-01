import SwiftUI
import UIKit
import ChinGoDesign

@main
struct ChinGoApp: App {
    @State private var state = MapState()

    init() {
        FontRegistration.assertBundled()
    }

    var body: some Scene {
        WindowGroup {
            MapScreen(state: state)
                .preferredColorScheme(.light)   // one committed look until stage 8
        }
    }
}

/// `Font.custom` falls back to the system face **silently** when a PostScript name misses,
/// so a font that failed to bundle ships as "the app looks slightly generic" rather than as
/// a crash. This turns it into a debug crash instead.
enum FontRegistration {
    static func assertBundled() {
        #if DEBUG
        for name in [Typeface.bagel, Typeface.gloria] {
            assert(
                UIFont(name: name, size: 12) != nil,
                "Font \(name) is not in the bundle. Check UIAppFonts in project.yml and the file in Resources/Fonts."
            )
        }
        #endif
    }
}
