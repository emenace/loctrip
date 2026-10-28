import Foundation
import Combine
import AppKit

@MainActor
public final class MeetingHistoryViewModel: ObservableObject {
    public static let shared = MeetingHistoryViewModel()

    private let storage = MeetingStorageService.shared
    private let summarizationService = LocalSummarizationService.shared
    private let exportService = ExportService.shared

    @Published public var sessions: [MeetingSession] = []
    @Published public var selectedSession: MeetingSession?
    @Published public var searchQuery: String = ""
    @Published public var isSummarizing: Bool = false
    @Published public var summarizationStatus: String = ""
    @Published public var availableOllamaModels: [String] = []
    @Published public var selectedEngine: SummarizationEngine = .builtInOffline
    @Published public var selectedOllamaModel: String = "llama3:latest"
    @Published public var notificationMessage: String?
    @Published public var isExporting: Bool = false

    public init() {
        refreshSessions()
    }

    /// Reloads all saved sessions from disk, applying active search filter
    public func refreshSessions() {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            self.sessions = storage.loadAllSessions()
        } else {
            self.sessions = storage.searchSessions(query: searchQuery)
        }

        // Keep selection if still valid, otherwise pick first
        if let current = selectedSession {
            if let updated = sessions.first(where: { $0.id == current.id }) {
                self.selectedSession = updated
            } else {
                self.selectedSession = sessions.first
            }
        } else {
            self.selectedSession = sessions.first
        }
    }

    /// Checks Ollama daemon availability
    public func checkOllama() async {
        let models = await summarizationService.fetchAvailableOllamaModels()
        self.availableOllamaModels = models
        if let first = models.first, !models.contains(selectedOllamaModel) {
            self.selectedOllamaModel = first
        }
    }

    /// Saves a newly recorded session to storage
    public func saveSession(
        title: String? = nil,
        duration: Double,
        appName: String,
        language: String,
        segments: [TranscriptSegment]
    ) -> MeetingSession {
        let session = MeetingSession(
            title: title,
            date: Date(),
            durationSeconds: duration,
            targetAppName: appName,
            languageMode: language,
            segments: segments
        )

        try? storage.saveSession(session)
        refreshSessions()
        self.selectedSession = session
        showNotification("Meeting session saved locally.")
        return session
    }

    /// Deletes a session from disk
    public func deleteSession(_ session: MeetingSession) {
        try? storage.deleteSession(id: session.id)
        if selectedSession?.id == session.id {
            selectedSession = nil
        }
        refreshSessions()
        showNotification("Session deleted.")
    }

    /// Generates summary for the currently selected session
    public func summarizeSelectedSession() async {
        guard let session = selectedSession else { return }

        isSummarizing = true
        summarizationStatus = "Generating summary with \(selectedEngine.rawValue)..."

        do {
            let summary = try await summarizationService.summarize(
                session: session,
                engine: selectedEngine,
                ollamaModel: selectedOllamaModel
            )

            var updatedSession = session
            updatedSession.summary = summary
            try storage.saveSession(updatedSession)

            self.selectedSession = updatedSession
            refreshSessions()
            self.isSummarizing = false
            self.summarizationStatus = "Summary generated successfully!"
            showNotification("Summary generated & saved.")
        } catch {
            self.isSummarizing = false
            self.summarizationStatus = "Summarization error: \(error.localizedDescription)"
            showNotification("Failed: \(error.localizedDescription)")
        }
    }

    /// Exports selected session to Markdown, Plain Text, or Subtitle format via macOS Save Panel
    public func exportSelectedSession(format: ExportFormat) {
        guard let session = selectedSession else { return }

        let content: String
        switch format {
        case .markdown:
            content = exportService.generateMarkdown(session: session)
        case .plainText:
            content = exportService.generatePlainText(session: session)
        case .srt:
            content = exportService.generateSRT(session: session)
        }

        let defaultName = session.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        if let savedURL = exportService.exportToFile(content: content, defaultFilename: defaultName, fileExtension: format.fileExtension) {
            showNotification("Exported to \(savedURL.lastPathComponent)")
        }
    }

    /// Copies selected session's formatted content to macOS clipboard
    public func copySelectedSessionToClipboard(format: ExportFormat) {
        guard let session = selectedSession else { return }

        let content: String
        switch format {
        case .markdown:
            content = exportService.generateMarkdown(session: session)
        case .plainText:
            content = exportService.generatePlainText(session: session)
        case .srt:
            content = exportService.generateSRT(session: session)
        }

        exportService.copyToClipboard(content)
        showNotification("Copied \(format.rawValue) to clipboard!")
    }

    private func showNotification(_ message: String) {
        self.notificationMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.notificationMessage == message {
                self.notificationMessage = nil
            }
        }
    }
}
