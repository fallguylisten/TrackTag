import SwiftUI
import AppKit
import iTunesLibrary

/// Album art from Music (read-only). Items are kept from the library load; images are decoded on demand and cached.
final class ArtworkCache: @unchecked Sendable {
    static let shared = ArtworkCache()
    private var items: [String: ITLibMediaItem] = [:]
    private let cache = NSCache<NSString, NSImage>()
    private let lock = NSLock()

    func register(_ id: String, _ item: ITLibMediaItem) { lock.lock(); items[id] = item; lock.unlock() }

    func image(_ id: String) -> NSImage? {
        if let c = cache.object(forKey: id as NSString) { return c }
        lock.lock(); let item = items[id]; lock.unlock()
        guard let img = item?.artwork?.image else { return nil }
        cache.setObject(img, forKey: id as NSString)
        return img
    }
}

/// Square album art, or an outlined empty square when the track has none.
struct ArtView: View {
    let id: String
    let has: Bool
    var size: CGFloat = 22
    var corner: CGFloat = 4
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().interpolation(.medium).aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: corner).stroke(has ? Theme.borderStrong : Theme.muted, lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .help(has ? "" : "No album art")
        .task(id: id) {
            guard has else { image = nil; return }
            let key = id
            image = await Task.detached(priority: .utility) { ArtworkCache.shared.image(key) }.value
        }
    }
}
