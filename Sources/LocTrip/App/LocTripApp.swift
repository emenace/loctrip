import SwiftUI
import AppKit

@main
struct LocTripApp: App {
    init() {
        // Setup system menu bar status item
        MenuBarManager.shared.setupMenuBar()

        // Start global keyboard shortcut monitor (Cmd+Shift+R, Cmd+Shift+H, Cmd+Shift+S, Cmd+Shift+C)
        GlobalHotkeyManager.shared.startMonitoring()

        // Graceful termination handler: auto-save unsaved meeting transcripts before app closes
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                let segments = TranscriptionViewModel.shared.segments
                if !segments.isEmpty {
                    let audio = AudioCaptureViewModel.shared
                    let session = MeetingSession(
                        title: "Session (Saved on Quit)",
                        durationSeconds: audio.recordingDuration,
                        targetAppName: audio.selectedTarget.name,
                        languageMode: AppViewModel.shared.selectedLanguage,
                        segments: segments
                    )
                    try? MeetingStorageService.shared.saveSession(session)
                }
            }
        }
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

                Button("Save Session") {
                    let audio = AudioCaptureViewModel.shared
                    let segments = TranscriptionViewModel.shared.segments
                    if !segments.isEmpty {
                        _ = MeetingHistoryViewModel.shared.saveSession(
                            title: nil,
                            duration: audio.recordingDuration,
                            appName: audio.selectedTarget.name,
                            language: AppViewModel.shared.selectedLanguage,
                            segments: segments
                        )
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Copy Transcript") {
                    TranscriptionViewModel.shared.copyTranscriptToClipboard()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
}
