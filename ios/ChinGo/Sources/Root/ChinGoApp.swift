import SwiftUI
import SwiftData
import UIKit
import ChinGoDesign

@main
struct ChinGoApp: App {
    @State private var state = MapState()
    @State private var location = LocationService()

    /// Built by hand rather than with `.modelContainer(for:)` so debug seeding has a
    /// context to write into before the first view appears.
    private let container: ModelContainer

    init() {
        FontRegistration.assertBundled()

        do {
            container = try ModelContainer(
                for: FriendRecord.self, CatchRecord.self, MemoryRecord.self
            )
        } catch {
            // Local-first means the store is the app. If it cannot open there is nothing
            // useful to degrade to, and failing loudly in development beats shipping a
            // silent read-only mode nobody notices.
            fatalError("Could not open the local store: \(error)")
        }

        #if DEBUG
        DemoSeed.populate(ModelContext(container))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(state: state, location: location)
                .preferredColorScheme(.light)   // one committed look until the theme pass
        }
        // Local-first: a catch is real on this device the moment it happens, with no
        // account and no network. Sync is something that catches up afterwards, never
        // something the moment depends on.
        .modelContainer(container)
    }
}

/// The map, with the opening laid over it.
///
/// The map is built and running underneath from the first frame rather than after the splash
/// — so by the time the ground lifts, tiles have already loaded and the world is there. A
/// splash that hides a loading screen is just a loading screen wearing a hat.
private struct RootView: View {
    let state: MapState
    let location: LocationService

    @State private var showingSplash = true

    var body: some View {
        ZStack {
            MapScreen(state: state, location: location)

            if showingSplash {
                SplashView { showingSplash = false }
                    .transition(.identity)   // SplashView animates its own exit
            }
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
                "Font \(name) is not in the bundle. Check UIAppFonts in project.yml and Resources/Fonts."
            )
        }
        #endif
    }
}
