import AppKit
import SwiftUI

@MainActor
public final class HUDWindowManager: ObservableObject {
    public static let shared = HUDWindowManager()

    private var hudPanel: NSPanel?

    private init() {}

    public var isVisible: Bool {
        hudPanel?.isVisible ?? false
    }

    public func toggleHUD() {
        if isVisible {
            hideHUD()
        } else {
            showHUD()
        }
    }

    public func showHUD() {
        if hudPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 120, y: 150, width: 440, height: 260),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .utilityWindow, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false

            let hostingView = NSHostingView(rootView: FloatingHUDView())
            panel.contentView = hostingView
            self.hudPanel = panel
        }

        hudPanel?.orderFrontRegardless()
        AppViewModel.shared.isFloatingHUDVisible = true
    }

    public func hideHUD() {
        hudPanel?.orderOut(nil)
        AppViewModel.shared.isFloatingHUDVisible = false
    }
}
