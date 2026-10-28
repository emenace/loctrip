import AppKit
import Foundation

@MainActor
public final class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var isStarted: Bool = false

    private init() {}

    /// Starts monitoring for global and local keyboard shortcuts
    public func startMonitoring() {
        guard !isStarted else { return }
        isStarted = true

        // 1. Local event monitor (when LocTrip or Floating HUD is frontmost)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume event
            }
            return event
        }

        // 2. Global event monitor (when another app like Zoom/Meet/Chrome is frontmost)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }
    }

    /// Stops event monitors
    public func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        isStarted = false
    }

    /// Evaluates key event and triggers corresponding action
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCmdShift = flags.contains([.command, .shift])

        guard hasCmdShift, let chars = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }

        switch chars {
        case "r":
            // Cmd+Shift+R: Toggle Live Transcription
            toggleLiveTranscription()
            return true

        case "h":
            // Cmd+Shift+H: Toggle Floating HUD
            HUDWindowManager.shared.toggleHUD()
            return true

        case "s":
            // Cmd+Shift+S: Quick Save Current Meeting Session
            quickSaveCurrentSession()
            return true

        case "c":
            // Cmd+Shift+C: Quick Copy Transcript to Clipboard
            TranscriptionViewModel.shared.copyTranscriptToClipboard()
            return true

        default:
            return false
        }
    }

    private func toggleLiveTranscription() {
        let audio = AudioCaptureViewModel.shared
        let appState = AppViewModel.shared

        Task { @MainActor in
            if audio.isLiveStreaming {
                await audio.stopLiveStreaming()
            } else {
                await audio.startLiveStreaming(languageCode: appState.selectedLanguage)
            }
        }
    }

    private func quickSaveCurrentSession() {
        let audio = AudioCaptureViewModel.shared
        let segments = TranscriptionViewModel.shared.segments
        guard !segments.isEmpty else { return }

        _ = MeetingHistoryViewModel.shared.saveSession(
            title: nil,
            duration: audio.recordingDuration,
            appName: audio.selectedTarget.name,
            language: AppViewModel.shared.selectedLanguage,
            segments: segments
        )
    }
}
