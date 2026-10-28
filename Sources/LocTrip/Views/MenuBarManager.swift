import AppKit
import SwiftUI

@MainActor
public final class MenuBarManager: NSObject {
    public static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?

    public override init() {
        super.init()
    }

    public func setupMenuBar() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "LocTrip")
            button.imagePosition = .imageLeft
        }

        let menu = NSMenu()
        menu.delegate = self

        item.menu = menu
        self.statusItem = item
    }

    public func updateIcon(isStreaming: Bool, isSpeechDetected: Bool) {
        guard let button = statusItem?.button else { return }
        if isStreaming {
            let symbol = isSpeechDetected ? "waveform.badge.mic" : "waveform.badge.waveform"
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Streaming")
            button.title = " LIVE"
        } else {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "LocTrip")
            button.title = ""
        }
    }
}

extension MenuBarManager: NSMenuDelegate {
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let audio = AudioCaptureViewModel.shared
        let appState = AppViewModel.shared

        // Status Header
        let statusTitle = audio.isLiveStreaming ? "🟢 Live Streaming Active" : "⚪ LocTrip Idle"
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle Streaming
        let streamTitle = audio.isLiveStreaming ? "Stop Live Transcription" : "Start Live Transcription"
        let streamItem = NSMenuItem(title: streamTitle, action: #selector(toggleStreaming), keyEquivalent: "s")
        streamItem.target = self
        menu.addItem(streamItem)

        // Toggle Floating HUD
        let hudTitle = appState.isFloatingHUDVisible ? "Hide Floating HUD" : "Show Floating HUD"
        let hudItem = NSMenuItem(title: hudTitle, action: #selector(toggleHUD), keyEquivalent: "h")
        hudItem.target = self
        menu.addItem(hudItem)

        menu.addItem(NSMenuItem.separator())

        // Show Main Dashboard Window
        let openItem = NSMenuItem(title: "Open Dashboard Window", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit LocTrip", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func toggleStreaming() {
        let audio = AudioCaptureViewModel.shared
        let app = AppViewModel.shared
        Task {
            if audio.isLiveStreaming {
                await audio.stopLiveStreaming()
            } else {
                await audio.startLiveStreaming(languageCode: app.selectedLanguage)
            }
        }
    }

    @objc private func toggleHUD() {
        HUDWindowManager.shared.toggleHUD()
    }

    @objc private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
