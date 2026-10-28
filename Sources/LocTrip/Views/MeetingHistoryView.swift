import SwiftUI

public struct MeetingHistoryView: View {
    @ObservedObject var historyVM = MeetingHistoryViewModel.shared
    @ObservedObject var appState = AppViewModel.shared
    @ObservedObject var transcription = TranscriptionViewModel.shared

    let onDismiss: () -> Void

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Meeting History & Summaries")
                                .font(.headline)
                            Text("(\(historyVM.sessions.count))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text("Search past transcripts, export in multiple formats, and generate local summaries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Refresh Button
                Button {
                    historyVM.refreshSessions()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh Sessions")

                // Close Button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content: Split View
            HSplitView {
                // Left Column: Sessions List & Search
                VStack(spacing: 8) {
                    // Search Bar
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search keywords (ID / EN)...", text: $historyVM.searchQuery)
                            .textFieldStyle(.plain)
                            .onChange(of: historyVM.searchQuery) { _, _ in
                                historyVM.refreshSessions()
                            }

                        if !historyVM.searchQuery.isEmpty {
                            Button {
                                historyVM.searchQuery = ""
                                historyVM.refreshSessions()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                    // Sessions List
                    if historyVM.sessions.isEmpty {
                        VStack(spacing: 10) {
                            Spacer()
                            Image(systemName: "tray")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text(historyVM.searchQuery.isEmpty ? "No saved meetings yet.\nRecord or transcribe audio to save sessions." : "No sessions match '\(historyVM.searchQuery)'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(historyVM.sessions) { session in
                                    sessionRow(session)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .frame(minWidth: 260, maxWidth: 320)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))

                // Right Column: Session Details, Summary & Transcript
                if let session = historyVM.selectedSession {
                    sessionDetailView(session)
                        .frame(minWidth: 500)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Select a meeting from the list to view transcript and summaries")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Bottom Status / Notification Banner
            if let message = historyVM.notificationMessage {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(message)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 840, minHeight: 620)
        .task {
            await historyVM.checkOllama()
            historyVM.refreshSessions()
        }
    }

    // MARK: - Session Row Item
    private func sessionRow(_ session: MeetingSession) -> some View {
        let isSelected = historyVM.selectedSession?.id == session.id

        return Button {
            historyVM.selectedSession = session
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.title)
                        .font(.subheadline.bold())
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Spacer()

                    if session.summary != nil {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .yellow : .purple)
                    }
                }

                HStack(spacing: 6) {
                    Text(session.targetAppName)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                        .foregroundColor(isSelected ? .white : .blue)
                        .cornerRadius(4)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(session.formattedDuration)
                        .font(.caption2.monospaced())
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)

                    Spacer()

                    Text(session.formattedDate)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                HStack {
                    Text("\(session.segments.count) segments (\(session.totalWordCount) words)")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)

                    Spacer()

                    Button {
                        historyVM.deleteSession(session)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Session")
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue.opacity(0.8) : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session Detail View
    private func sessionDetailView(_ session: MeetingSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header & Action Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.title3.bold())

                            HStack(spacing: 8) {
                                Label(session.formattedDate, systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("•")
                                    .foregroundColor(.secondary)

                                Label(session.formattedDuration, systemImage: "clock")
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)

                                Text("•")
                                    .foregroundColor(.secondary)

                                Label(session.targetAppName, systemImage: "app.badge")
                                    .font(.caption)
                                    .foregroundColor(.blue)

                                Text("•")
                                    .foregroundColor(.secondary)

                                Text("\(session.totalWordCount) words")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Export & Copy Actions
                        HStack(spacing: 6) {
                            Menu {
                                Button("Export to Markdown (.md)") {
                                    historyVM.exportSelectedSession(format: .markdown)
                                }
                                Button("Export to Plain Text (.txt)") {
                                    historyVM.exportSelectedSession(format: .plainText)
                                }
                                Button("Export Subtitles (.srt)") {
                                    historyVM.exportSelectedSession(format: .srt)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export")
                                }
                                .font(.caption.bold())
                            }
                            .menuStyle(.borderedButton)

                            Menu {
                                Button("Copy Markdown") {
                                    historyVM.copySelectedSessionToClipboard(format: .markdown)
                                }
                                Button("Copy Plain Text") {
                                    historyVM.copySelectedSessionToClipboard(format: .plainText)
                                }
                                Button("Copy Subtitles (.srt)") {
                                    historyVM.copySelectedSessionToClipboard(format: .srt)
                                }
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .menuStyle(.borderedButton)
                            .help("Copy formatted transcript to clipboard")

                            Button {
                                transcription.segments = session.segments
                                onDismiss()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("Open in Live View")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .help("Load this session's transcript into the active live view")
                        }
                    }
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(10)

                // AI Summary Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            Text("Local AI Meeting Summary")
                                .font(.headline)
                        }

                        Spacer()

                        // Engine & Model Controls
                        HStack(spacing: 6) {
                            Picker("", selection: $historyVM.selectedEngine) {
                                ForEach(SummarizationEngine.allCases) { engine in
                                    Text(engine.rawValue).tag(engine)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 220)
                            .disabled(historyVM.isSummarizing)

                            if historyVM.selectedEngine == .ollama && !historyVM.availableOllamaModels.isEmpty {
                                Picker("", selection: $historyVM.selectedOllamaModel) {
                                    ForEach(historyVM.availableOllamaModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 140)
                                .disabled(historyVM.isSummarizing)
                            }

                            Button {
                                Task {
                                    await historyVM.summarizeSelectedSession()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if historyVM.isSummarizing {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                    }
                                    Text(session.summary == nil ? "Generate Summary" : "Regenerate")
                                }
                                .font(.caption.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .disabled(historyVM.isSummarizing || session.segments.isEmpty)
                        }
                    }

                    if historyVM.isSummarizing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(historyVM.summarizationStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    if let summary = session.summary {
                        VStack(alignment: .leading, spacing: 12) {
                            // Executive Summary Card
                            VStack(alignment: .leading, spacing: 6) {
                                Text("📋 RINGKASAN EKSEKUTIF / EXECUTIVE SUMMARY")
                                    .font(.caption.bold())
                                    .foregroundColor(.purple)

                                Text(summary.executiveSummary)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.06))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )

                            // Key Points
                            if !summary.keyPoints.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("🎯 POIN-POIN PENTING / KEY DISCUSSION POINTS")
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)

                                    ForEach(summary.keyPoints, id: \.self) { point in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                                .padding(.top, 2)
                                            Text(point)
                                                .font(.subheadline)
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                )
                            }

                            // Action Items
                            if !summary.actionItems.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("✅ TINDAK LANJUT / ACTION ITEMS & PIC")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)

                                    ForEach(summary.actionItems, id: \.self) { item in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "square")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                                .padding(.top, 2)
                                            Text(item)
                                                .font(.subheadline)
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    } else if !historyVM.isSummarizing {
                        VStack(spacing: 6) {
                            Text("No summary generated yet. Click 'Generate Summary' to automatically extract key discussion points and action items.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(8)
                    }
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)

                // Full Transcript Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(.secondary)
                        Text("Transkrip Lengkap (\(session.segments.count) segmen)")
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if session.segments.isEmpty {
                            Text("No speech segments in this session.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(12)
                        } else {
                            ForEach(session.segments) { segment in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(segment.timestampFormatted)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(5)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                                        )

                                    Text(segment.text)
                                        .font(.system(size: 13.5, weight: .regular))
                                        .lineSpacing(3)
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)

                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
                                )
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.3))
                    .cornerRadius(8)
                }
            }
            .padding(16)
        }
    }
}
