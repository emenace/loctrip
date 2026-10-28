import SwiftUI

@main
struct LocTripApp: App {
    init() {
        // Setup system menu bar status item
        MenuBarManager.shared.setupMenuBar()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 760, height: 680)
        .commands {
            CommandMenu("Transcription") {
                Button("Toggle Floating HUD") {
                    HUDWindowManager.shared.toggleHUD()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Toggle Live Transcription") {
                    let audio = AudioCaptureViewModel.shared
                    let appState = AppViewModel.shared
                    Task {
                        if audio.isLiveStreaming {
                            await audio.stopLiveStreaming()
                        } else {
                            await audio.startLiveStreaming(languageCode: appState.selectedLanguage)
                        }
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
