import Foundation

public enum SummarizationEngine: String, CaseIterable, Identifiable {
    case builtInOffline = "Built-in Offline (Zero Dependency)"
    case ollama = "Local Ollama LLM (Port 11434)"

    public var id: String { rawValue }
}

public final class LocalSummarizationService: @unchecked Sendable {
    public static let shared = LocalSummarizationService()

    private let ollamaBaseURL = "http://127.0.0.1:11434"

    private init() {}

    /// Checks if local Ollama daemon is running and returns installed model names
    public func fetchAvailableOllamaModels() async -> [String] {
        guard let url = URL(string: "\(ollamaBaseURL)/api/tags") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0 // Fast timeout so UI doesn't freeze if Ollama isn't running

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }

            struct TagsResponse: Codable {
                struct ModelItem: Codable {
                    let name: String
                }
                let models: [ModelItem]?
            }

            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            return decoded.models?.map { $0.name } ?? []
        } catch {
            return []
        }
    }

    /// Generates structured meeting summary using either Local Ollama or Built-in Offline Heuristic
    public func summarize(
        session: MeetingSession,
        engine: SummarizationEngine = .builtInOffline,
        ollamaModel: String = "llama3:latest"
    ) async throws -> MeetingSummary {
        guard !session.segments.isEmpty else {
            return MeetingSummary(
                executiveSummary: "Tidak ada transkrip audio yang dapat diringkas / No audio transcript available to summarize.",
                keyPoints: [],
                actionItems: []
            )
        }

        switch engine {
        case .ollama:
            return try await summarizeWithOllama(session: session, modelName: ollamaModel)
        case .builtInOffline:
            return summarizeWithOfflineHeuristics(session: session)
        }
    }

    // MARK: - Ollama Integration

    private func summarizeWithOllama(session: MeetingSession, modelName: String) async throws -> MeetingSummary {
        guard let url = URL(string: "\(ollamaBaseURL)/api/generate") else {
            throw NSError(domain: "LocTrip.Ollama", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL"])
        }

        let fullTranscript = session.segments.map { "\($0.timestampFormatted) \($0.text)" }.joined(separator: "\n")

        let prompt = """
        You are an expert bilingual meeting assistant for Indonesian and English ("Jaksel" tech meetings, sprints, reviews).
        Analyze the following meeting transcript and generate a structured JSON summary.

        Target Audio Source: \(session.targetAppName)
        Duration: \(session.formattedDuration)

        Transcript:
        \(fullTranscript)

        Respond ONLY with a valid JSON object matching this exact schema:
        {
          "executiveSummary": "2 to 3 sentences summarizing the meeting purpose and outcome in the dominant language used in the call (Indonesian/English).",
          "keyPoints": [
            "Discussion point 1",
            "Discussion point 2"
          ],
          "actionItems": [
            "[PIC or Team] Action item description with deadline if mentioned",
            "[PIC] Another action item"
          ]
        }
        Do not wrap your response in markdown code fences or backticks. Return raw JSON only.
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90.0

        let payload: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "format": "json"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LocTrip.Ollama", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ollama returned an error status."])
        }

        struct GenerateResponse: Codable {
            let response: String
        }

        let genResponse = try JSONDecoder().decode(GenerateResponse.self, from: data)
        let responseText = genResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)

        if let jsonData = responseText.data(using: .utf8),
           let summary = try? JSONDecoder().decode(MeetingSummary.self, from: jsonData) {
            return summary
        }

        // Fallback: parse raw response if model didn't follow strict JSON
        return parseRawLLMResponse(responseText)
    }

    private func parseRawLLMResponse(_ text: String) -> MeetingSummary {
        var exec = ""
        var points: [String] = []
        var actions: [String] = []

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("summary:") || trimmed.lowercased().contains("ringkasan:") {
                exec = trimmed
            } else if trimmed.starts(with: "- [ ]") || trimmed.lowercased().contains("action") {
                actions.append(trimmed.replacingOccurrences(of: "- [ ]", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.starts(with: "-") || trimmed.starts(with: "•") {
                points.append(trimmed.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespaces))
            }
        }

        if exec.isEmpty {
            exec = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "Meeting completed."
        }

        return MeetingSummary(
            executiveSummary: exec,
            keyPoints: points.isEmpty ? ["Pembahasan agenda utama / Discussion of main topics"] : points,
            actionItems: actions.isEmpty ? ["Review transkrip dan koordinasi lanjutan / Follow up review"] : actions
        )
    }

    // MARK: - Built-in Intelligent Offline Heuristic Summarizer (Zero Dependencies)

    private func summarizeWithOfflineHeuristics(session: MeetingSession) -> MeetingSummary {
        let segments = session.segments
        let allSentences = segments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Action detection keywords in Indonesian & English
        let actionKeywords = [
            "perlu", "harus", "tolong", "nanti", "besok", "minggu depan", "deadline",
            "pic", "action item", "todo", "siapkan", "kerjakan", "kirim", "revisi",
            "update", "need to", "must", "action items", "assign", "follow up", "will",
            "deliverable", "schedule", "deploy", "fix", "testing", "meeting lagi"
        ]

        // Discussion topic keywords
        let topicKeywords = [
            "bahas", "diskusi", "masalah", "issue", "solusi", "fitur", "arsitektur",
            "progress", "target", "budget", "plan", "roadmap", "design", "backend",
            "frontend", "database", "api", "release", "sprint", "client", "user"
        ]

        var detectedActions: [String] = []
        var detectedKeyPoints: [String] = []

        for sentence in allSentences {
            let lower = sentence.lowercased()

            // Check if sentence indicates an action item
            if actionKeywords.contains(where: { lower.contains($0) }) {
                if !detectedActions.contains(sentence) && sentence.count > 10 {
                    detectedActions.append(sentence)
                }
            }

            // Check if sentence indicates a key topic discussion
            if topicKeywords.contains(where: { lower.contains($0) }) {
                if !detectedKeyPoints.contains(sentence) && sentence.count > 12 {
                    detectedKeyPoints.append(sentence)
                }
            }
        }

        // Limit results to top 5 most relevant items
        if detectedKeyPoints.count > 5 {
            detectedKeyPoints = Array(detectedKeyPoints.prefix(5))
        }

        if detectedActions.count > 5 {
            detectedActions = Array(detectedActions.prefix(5))
        }

        // Fallbacks if conversation didn't hit explicit markers
        if detectedKeyPoints.isEmpty {
            let count = min(3, allSentences.count)
            detectedKeyPoints = Array(allSentences.prefix(count))
        }

        if detectedActions.isEmpty {
            detectedActions = [
                "Lakukan review transkrip dan konfirmasi poin diskusi dengan tim / Review transcript and confirm discussion points."
            ]
        }

        // Generate bilingual Executive Summary synthesis
        let appName = session.targetAppName
        let duration = session.formattedDuration
        let wordCount = session.totalWordCount

        let summaryText: String
        if session.languageMode == "id" {
            summaryText = "Sesi rapat audio '\(session.title)' dari \(appName) berlangsung selama \(duration) (\(wordCount) kata). Diskusi mencakup \(detectedKeyPoints.count) poin utama dengan \(detectedActions.count) tindak lanjut yang perlu diselesaikan."
        } else if session.languageMode == "en" {
            summaryText = "Meeting session '\(session.title)' captured from \(appName) lasted \(duration) (\(wordCount) words). The discussion highlighted \(detectedKeyPoints.count) core topics with \(detectedActions.count) actionable follow-up items."
        } else {
            summaryText = "Sesi rapat '\(session.title)' (\(appName), durasi \(duration), \(wordCount) kata) mencakup koordinasi teknis dan operasional. Diskusi menyoroti \(detectedKeyPoints.count) poin utama dan \(detectedActions.count) tindak lanjut / action items penting."
        }

        return MeetingSummary(
            executiveSummary: summaryText,
            keyPoints: detectedKeyPoints,
            actionItems: detectedActions
        )
    }
}
