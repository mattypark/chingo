import Testing
@testable import ChinGoEngine

/// Which icons a level has earned.
@Suite("App icons")
struct AppIconTests {

    @Test("Everybody starts with one, and it is the shipped icon")
    func primaryIsFree() {
        let first = AppIcon.all[0]
        #expect(first.name == nil)
        #expect(first.unlocked(atLevel: 1))
    }

    @Test("Only the primary is available at level one")
    func nothingUnlockedYet() {
        let available = AppIcon.all.filter { $0.unlocked(atLevel: 1) }
        #expect(available.count == 1)
        #expect(available[0].name == nil)
    }

    @Test("They unlock in the order they are listed")
    func orderedByLevel() {
        let levels = AppIcon.all.map(\.level)
        #expect(levels == levels.sorted())
    }

    @Test("A level unlocks everything at or below it")
    func unlockingIsCumulative() {
        // Reaching level 4 keeps what levels 2 and 3 gave, rather than swapping it out.
        let atFour = AppIcon.all.filter { $0.unlocked(atLevel: 4) }
        #expect(atFour.count == 4)
        #expect(AppIcon.all.filter { $0.unlocked(atLevel: 99) }.count == AppIcon.all.count)
    }

    @Test("Every alternate has a distinct catalogue name")
    func namesAreUnique() {
        // A duplicate here is silent: the picker shows two rows and both set the same icon.
        let names = AppIcon.all.compactMap(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("An icon that no longer exists falls back to the shipped one")
    func unknownNameFallsBack() {
        // What happens when an icon is dropped in an update while somebody had it selected.
        #expect(AppIcon.named("AppIcon-Removed").name == nil)
        #expect(AppIcon.named(nil).name == nil)
    }

    @Test("A stored name resolves to its own icon")
    func knownNameResolves() {
        #expect(AppIcon.named("AppIcon-Panda").title == "Panda")
    }

    @Test("A level-up can name what it just unlocked")
    func unlockedExactlyAtALevel() {
        #expect(AppIcon.unlocked(exactlyAt: 2).map(\.title) == ["Marmalade"])
        // Level one gives the primary, which is not something to announce.
        #expect(AppIcon.unlocked(exactlyAt: 1).isEmpty)
    }
}
