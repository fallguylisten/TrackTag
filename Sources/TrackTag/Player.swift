import SwiftUI
import AVFoundation
import AppKit

/// One player for the whole app: switching tabs keeps the same track and position.
@MainActor
final class Player: ObservableObject {
    @Published var trackID: String?
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var duration: Double = 0

    private var player: AVPlayer?
    private var observer: Any?

    func play(_ track: Track) {
        guard let url = track.fileURL else { return }
        if trackID == track.id, player != nil { toggle(); return }
        stop()
        let p = AVPlayer(url: url)
        player = p
        trackID = track.id
        position = 0
        duration = 0
        observer = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.position = t.seconds
                if let d = p.currentItem?.duration.seconds, d.isFinite { self.duration = d }
                if let d = p.currentItem?.duration.seconds, d.isFinite, t.seconds >= d - 0.05 { self.isPlaying = false }
            }
        }
        p.play()
        isPlaying = true
    }

    func toggle() {
        guard let p = player else { return }
        if isPlaying { p.pause() } else { p.play() }
        isPlaying.toggle()
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        position = seconds
    }

    func stop() {
        if let o = observer { player?.removeTimeObserver(o) }
        observer = nil
        player?.pause()
        player = nil
        isPlaying = false
    }
}

/// Footer on every tab: play/pause, art, title, scrubber, times.
struct PlayerBar: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var player: Player

    private var track: Track? { store.tracks.first { $0.id == player.trackID } }

    var body: some View {
        HStack(spacing: 16) {
            if let t = track {
                ArtView(id: t.id, has: t.hasArtwork, size: 36, corner: 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(t.title.display.replacingOccurrences(of: t.title.version.map { " [\($0)]" } ?? "", with: ""))
                        .font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Text([t.title.version.map { "[\($0)]" }, t.artist].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                .frame(width: 300, alignment: .leading)
            } else {
                Text("Double-click a track to play it").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    .frame(width: 352, alignment: .leading)
            }
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15)).foregroundStyle(Color(hex: 0x1A1206))
                    .frame(width: 40, height: 40).background(Circle().fill(Theme.orange))
            }
            .buttonStyle(.plain).disabled(track == nil)
            Text(time(player.position)).font(.system(size: 12)).monospacedDigit().foregroundStyle(Theme.muted)
            Slider(value: Binding(get: { player.position }, set: { player.seek(to: $0) }),
                   in: 0...max(1, player.duration))
                .tint(Theme.orange).disabled(track == nil)
            Text(time(player.duration)).font(.system(size: 12)).monospacedDigit().foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 24).padding(.vertical, 10)
        .background(Theme.panel)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private func time(_ s: Double) -> String {
        guard s.isFinite, s > 0 else { return "0:00" }
        let t = Int(s)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// Space plays/pauses the focused track anywhere, except while typing in a text field.
final class SpaceKey {
    static var monitor: Any?
    static func install(_ action: @escaping () -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 49, e.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
               !(NSApp.keyWindow?.firstResponder is NSText) {
                action(); return nil
            }
            return e
        }
    }
}
