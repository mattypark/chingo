import UIKit

/// Where catch photos live.
///
/// Application Support rather than Documents: these are app data, not documents a person
/// would expect to see in Files. Excluded from iCloud backup — a catch photo is
/// reproducible from the friend's copy, and backing up every photo of every meeting is a
/// cost the user never agreed to.
enum PhotoStore {

    private static var directory: URL { folder("catches") }

    /// Portraits live beside the catches, not among them.
    ///
    /// Two reasons, and the second is the real one. A portrait is not reproducible from
    /// anybody else's copy the way a catch photo is, so the backup argument below does not
    /// transfer to it; and keeping them apart means a future "delete every photo of a person"
    /// can walk the catch folder without having to know which files are faces.
    private static var portraits: URL { folder("portraits") }

    private static func folder(_ name: String) -> URL {
        let base = URL.applicationSupportDirectory.appending(path: name)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            var url = base
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        return base
    }

    /// Returns the bare filename, which is what goes in the store. Absolute paths change
    /// between launches on iOS — a container path saved in a database is a bug that only
    /// shows up after an app update.
    @discardableResult
    static func save(_ image: UIImage) -> String? {
        // 0.8 at up to 1600px: a catch photo is looked at on a card, not printed.
        guard let data = downscaled(image, maxDimension: 1600).jpegData(compressionQuality: 0.8)
        else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: directory.appending(path: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        return UIImage(contentsOfFile: directory.appending(path: name).path)
    }

    static func delete(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: directory.appending(path: name))
    }

    // MARK: Portraits

    /// 512px, not 1600. A portrait is drawn at 38 points on a card and 96 in the profile, and
    /// storing a nine-megapixel selfie to show it at 38 points is a cost nobody agreed to.
    @discardableResult
    static func savePortrait(_ image: UIImage) -> String? {
        guard let data = downscaled(image, maxDimension: 512).jpegData(compressionQuality: 0.85)
        else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: portraits.appending(path: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func loadPortrait(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        return UIImage(contentsOfFile: portraits.appending(path: name).path)
    }

    static func deletePortrait(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: portraits.appending(path: name))
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
