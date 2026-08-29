import AppKit
import AVFoundation
import AVKit

@MainActor
final class VideoPlaybackController: NSObject, NSWindowDelegate {
    static let shared = VideoPlaybackController()

    private var player: AVPlayer?
    private var windowController: NSWindowController?

    var isPresenting: Bool {
        windowController?.window?.isVisible == true
    }

    func present(url: URL, title: String, autoPlay: Bool = true) {
        dismiss()

        let player = AVPlayer(url: url)
        let playerView = AVPlayerView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 560)
        )
        playerView.player = player
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect

        let viewController = NSViewController()
        viewController.view = playerView

        let window = NSWindow(
            contentRect: playerView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = viewController
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 360)
        window.delegate = self
        window.center()

        let controller = NSWindowController(window: window)
        self.player = player
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        if autoPlay {
            player.play()
        }
    }

    func dismiss() {
        player?.pause()
        windowController?.close()
        player = nil
        windowController = nil
    }

    func windowWillClose(_ notification: Notification) {
        player?.pause()
        player = nil
        windowController = nil
    }
}
