import Foundation

/// The icons you can put on your home screen, and what earns them.
///
/// Not in `ChinGoDesign` and not in a view: which icon a level unlocks is a rule, and rules
/// live where they can be tested without a simulator. The catalogue names are strings here
/// rather than images — the engine never needs to draw one, and keeping `UIKit` out is what
/// lets this compile on macOS with everything else.
public struct AppIcon: Identifiable, Equatable, Sendable {

    /// The asset-catalogue name, or nil for the icon the app ships with.
    ///
    /// Nil rather than a name, because that is exactly what `setAlternateIconName` wants for
    /// "put it back" — a separate `isPrimary` flag would be a second way to say the same thing
    /// and a chance for the two to disagree.
    public let name: String?
    /// What it is called in the picker.
    public let title: String
    /// The level it becomes selectable at. 1 for the one everybody starts with.
    public let level: Int

    public var id: String { name ?? "primary" }

    /// The image to draw in a picker.
    ///
    /// A separate imageset, not the appiconset. `UIImage(named:)` cannot read an appiconset --
    /// it silently answers with the *primary* icon for every name you ask it, so a picker
    /// built on it shows the same tile six times and looks like the alternates never shipped.
    /// The catalogue carries a small copy of each under this name for the picker to draw.
    public var previewAsset: String { "IconPreview-\(title)" }

    public init(name: String?, title: String, level: Int) {
        self.name = name
        self.title = title
        self.level = level
    }

    /// Every icon, in the order they unlock.
    ///
    /// Five alternates, paced across the first handful of levels rather than the whole curve.
    /// `Progression` is quadratic — level 6 is about sixty catches — so anything further out
    /// would be a reward nobody in the first month ever sees, and an icon you cannot picture
    /// earning is not an incentive, it is a locked row.
    public static let all: [AppIcon] = [
        AppIcon(name: nil, title: "ChinGo", level: 1),
        AppIcon(name: "AppIcon-Marmalade", title: "Marmalade", level: 2),
        AppIcon(name: "AppIcon-Dozer", title: "Dozer", level: 3),
        AppIcon(name: "AppIcon-Penguin", title: "Penguin", level: 4),
        AppIcon(name: "AppIcon-Panda", title: "Panda", level: 5),
        AppIcon(name: "AppIcon-Midnight", title: "Midnight", level: 6),
    ]

    /// Whether this one can be chosen yet.
    public func unlocked(atLevel level: Int) -> Bool { level >= self.level }

    /// The icon a stored name refers to, or the primary if it refers to nothing.
    ///
    /// Falls back rather than failing. A name that no longer exists means an icon was removed
    /// in an update while somebody had it selected, and the honest answer to that is the
    /// shipped icon — not a crash, and not an empty picker.
    public static func named(_ name: String?) -> AppIcon {
        all.first { $0.name == name } ?? all[0]
    }

    /// Icons unlocked by reaching `level` and not before it, so a level-up can say what it
    /// just gave you rather than making somebody go and look.
    public static func unlocked(exactlyAt level: Int) -> [AppIcon] {
        all.filter { $0.level == level && $0.name != nil }
    }
}
