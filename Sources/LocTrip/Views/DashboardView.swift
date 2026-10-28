import SwiftUI

public struct DashboardView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @ObservedObject var appState = AppViewModel.shared
    @ObservedObject var audioCapture = AudioCaptureViewModel.shared
    @ObservedObject var transcription = TranscriptionViewModel.shared
    @ObservedObject var historyVM = MeetingHistoryViewModel.shared

    public init() {}

    private var filteredSegments: [TranscriptSegment] {
        if appState.transcriptSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return transcription.segments
        } else {
            return transcription.segments.filter {
                $0.text.localizedCaseInsensitiveContains(appState.transcriptSearchQuery)
            }
        }
    }

    private var totalWordCount: Int {
        transcription.segments.reduce(0) { total, segment in
            total + segment.text.split(separator: " ").count
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Navigation Bar
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("LocTrip")
                                .font(.headline)
                            Text("Local Audio Transcriber • Apple Silicon M2")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // History Button
                    Button {
                        historyVM.refreshSessions()
                        appState.showHistoryModal = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                            Text("History")
                                .font(.caption.bold())
                            if !historyVM.sessions.isEmpty {
                                Text("\(historyVM.sessions.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .help("View Past Saved Meetings, Summaries & Search")

                    // Floating HUD Toggle Button
                    Button {
                        HUDWindowManager.shared.toggleHUD()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: appState.isFloatingHUDVisible ? "pip.exit" : "pip.enter")
                                .foregroundColor(.purple)
                            Text(appState.isFloatingHUDVisible ? "Hide HUD" : "Floating HUD")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .help("Toggle Always-on-Top Floating HUD (Cmd+Shift+H)")

                    // Language Mode Selector
                    Picker("Language", selection: $appState.selectedLanguage) {
                        Text("Auto (ID / EN)").tag("auto")
                        Text("Bahasa Indonesia").tag("id")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    .disabled(audioCapture.isLiveStreaming)

                    // Permissions Status Pill
                    Button {
                        appState.showSettingsModal = true
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(permissionManager.isAllGranted ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(permissionManager.isAllGranted ? "Permissions Active" : "Check Permissions")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                Divider()

                // Section 1: Audio Source & Dual-Channel Mixing
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("1. Audio Capture & Source Target")
                                .font(.headline)
                            Text("ScreenCaptureKit output audio + optional microphone mixing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Target App Dropdown
                        Menu {
                            ForEach(audioCapture.availableTargets) { target in
                                Button {
                                    audioCapture.selectedTarget = target
                                } label: {
                                    HStack {
                                        Text(target.name)
                                        if target.id == audioCapture.selectedTarget.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: audioCapture.selectedTarget.iconName)
                                    .foregroundColor(.blue)
                                Text(audioCapture.selectedTarget.name)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                    .menuStyle(.borderedButton)
                    .disabled(audioCapture.isRecording || audioCapture.isLiveStreaming)

                    // Refresh Apps Button
                    Button {
                        Task {
                            await audioCapture.loadTargets()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh running applications")
                    .disabled(audioCapture.isRecording || audioCapture.isLiveStreaming)
                }

                // Toggles & VAD Status Row
                HStack(spacing: 16) {
                    // Microphone Mixing Toggle
                    Toggle(isOn: $audioCapture.includeMicrophone) {
                        HStack(spacing: 6) {
                            Image(systemName: "mic.badge.plus")
                                .foregroundColor(.teal)
                            Text("Include Microphone (Two-Way Meeting)")
                                .font(.subheadline)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(audioCapture.isLiveStreaming || audioCapture.isRecording)

                    Spacer()

                    // Voice Activity Detection (VAD) Pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(audioCapture.isSpeechDetected ? Color.green : Color.gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(audioCapture.isSpeechDetected ? "Speech Active" : "Silence (VAD Idle)")
                            .font(.caption.bold())
                            .foregroundColor(audioCapture.isSpeechDetected ? .green : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
                }

                // Live VU Level Meter
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.separatorColor).opacity(0.25))
                                .frame(height: 10)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .yellow, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width * CGFloat(audioCapture.audioLevel), geo.size.width)), height: 10)
                                .animation(.easeOut(duration: 0.08), value: audioCapture.audioLevel)
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        Text("16kHz Mono Float32 Stream")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(audioCapture.statusMessage)
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Section 2: Real-Time Streaming & AI Controls (Part 4)
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("2. Live Streaming Pipeline (WhisperKit + VAD)")
                            .font(.headline)
                        Text("Continuous sliding-window transcription powered by Apple Neural Engine")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Model Selector Dropdown
                    Picker("", selection: $transcription.selectedModel) {
                        ForEach(TranscriptionModel.allCases) { model in
                            Text("\(model.displayName) (\(model.downloadSizeDescription))").tag(model)
                        }
                    }
                    .frame(width: 300)
                    .disabled(transcription.isTranscribing || audioCapture.isLiveStreaming)

                    // Load Model Button
                    Button {
                        Task {
                            await transcription.loadModel()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if case .downloading = transcription.modelStatus {
                                ProgressView()
                                    .controlSize(.small)
                            } else if transcription.isModelReady {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }

                            Text(transcription.isModelReady ? "Ready" : "Load Model")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(transcription.isTranscribing || audioCapture.isLiveStreaming)

                    if transcription.isModelReady && !audioCapture.isLiveStreaming {
                        Button {
                            Task {
                                await transcription.unloadModel()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eject")
                                Text("Free RAM")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Unload model from RAM")
                    }
                }

                // M2 Hardware & Memory Telemetry Banner
                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        Image(systemName: "cpu")
                            .foregroundColor(.purple)
                        Text("Engine:")
                            .font(.caption2.bold())
                        Text("Apple Neural Engine (ANE) + Metal")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text("•")
                        .foregroundColor(.secondary)

                    HStack(spacing: 5) {
                        Image(systemName: "memorychip")
                            .foregroundColor(.green)
                        Text("Resident RAM:")
                            .font(.caption2.bold())
                        Text("\(ProcessMemoryInfo.shared.memoryFootprintString) (Budget < 1GB ✓)")
                            .font(.caption2.monospaced())
                            .foregroundColor(ProcessMemoryInfo.shared.isWithinTargetBudget ? .green : .orange)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "command")
                            .font(.caption2)
                        Text("Hotkeys: ⌘⇧R Record • ⌘⇧H HUD • ⌘⇧S Save • ⌘⇧C Copy")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)

                // Model Download Progress Bar (if downloading)
                if case .downloading(let progress) = transcription.modelStatus {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                        HStack {
                            Text(transcription.statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.caption.bold())
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(10)
                }

                // Live Streaming Action Control
                HStack(spacing: 14) {
                    Button {
                        Task {
                            if audioCapture.isLiveStreaming {
                                await audioCapture.stopLiveStreaming()
                            } else {
                                await audioCapture.startLiveStreaming(languageCode: appState.selectedLanguage)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: audioCapture.isLiveStreaming ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(audioCapture.isLiveStreaming ? "Stop Live Transcription" : "Start Live Continuous Transcription")
                                    .fontWeight(.semibold)

                                if audioCapture.isLiveStreaming {
                                    Text("Streaming live speech to text...")
                                        .font(.caption2)
                                }
                            }

                            Spacer()

                            if audioCapture.isLiveStreaming {
                                Text(formatDuration(audioCapture.recordingDuration))
                                    .font(.system(.subheadline, design: .monospaced).bold())
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(audioCapture.isLiveStreaming ? .red : .purple)
                    .controlSize(.large)
                    .disabled(!transcription.isModelReady || audioCapture.isRecording)
                }

                if !transcription.isModelReady {
                    Text("Please click 'Load Model' above to initialize the AI engine before streaming.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(audioCapture.isLiveStreaming ? Color.purple.opacity(0.4) : Color.purple.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Section 3: Live Transcript Stream Display (Part 5 Polish)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        Text("Live Meeting Transcript")
                            .font(.headline)

                        if audioCapture.isLiveStreaming {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption2.bold())
                                .foregroundColor(.red)
                        }

                        if !transcription.segments.isEmpty {
                            Text("• \(transcription.segments.count) segments (\(totalWordCount) words)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Search / Filter Field
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        TextField("Search...", text: $appState.transcriptSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .frame(width: 100)

                        if !appState.transcriptSearchQuery.isEmpty {
                            Button {
                                appState.transcriptSearchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                    if !transcription.segments.isEmpty {
                        // Save to History Button
                        Button {
                            _ = historyVM.saveSession(
                                title: nil,
                                duration: audioCapture.recordingDuration,
                                appName: audioCapture.selectedTarget.name,
                                language: appState.selectedLanguage,
                                segments: transcription.segments
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Session")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Save transcript to local session history")

                        // Export Menu
                        Menu {
                            Button("Export to Markdown (.md)") {
                                let session = MeetingSession(
                                    durationSeconds: audioCapture.recordingDuration,
                                    targetAppName: audioCapture.selectedTarget.name,
                                    languageMode: appState.selectedLanguage,
                                    segments: transcription.segments
                                )
                                let md = ExportService.shared.generateMarkdown(session: session)
                                _ = ExportService.shared.exportToFile(content: md, defaultFilename: "LocTrip_Meeting", fileExtension: "md")
                            }
                            Button("Export to Plain Text (.txt)") {
                                let session = MeetingSession(
                                    durationSeconds: audioCapture.recordingDuration,
                                    targetAppName: audioCapture.selectedTarget.name,
                                    languageMode: appState.selectedLanguage,
                                    segments: transcription.segments
                                )
                                let txt = ExportService.shared.generatePlainText(session: session)
                                _ = ExportService.shared.exportToFile(content: txt, defaultFilename: "LocTrip_Meeting", fileExtension: "txt")
                            }
                            Button("Export Subtitles (.srt)") {
                                let session = MeetingSession(
                                    durationSeconds: audioCapture.recordingDuration,
                                    targetAppName: audioCapture.selectedTarget.name,
                                    languageMode: appState.selectedLanguage,
                                    segments: transcription.segments
                                )
                                let srt = ExportService.shared.generateSRT(session: session)
                                _ = ExportService.shared.exportToFile(content: srt, defaultFilename: "LocTrip_Meeting", fileExtension: "srt")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                            }
                        }
                        .menuStyle(.borderedButton)
                        .controlSize(.small)

                        Button {
                            transcription.copyTranscriptToClipboard()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: transcription.copiedToClipboard ? "checkmark" : "doc.on.doc")
                                Text(transcription.copiedToClipboard ? "Copied!" : "Copy")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            transcription.clearTranscript()
                        } label: {
                            Image(systemName: "trash")
                            Text("Clear")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Transcript Text Box
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if filteredSegments.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "text.bubble")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text(appState.transcriptSearchQuery.isEmpty ? "No speech transcribed yet.\nStart live continuous transcription or play meeting audio to begin." : "No segments match '\(appState.transcriptSearchQuery)'")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                            } else {
                                ForEach(filteredSegments) { segment in
                                    let isLatest = (segment.id == filteredSegments.last?.id)

                                    HStack(alignment: .top, spacing: 12) {
                                        // Timestamp pill badge
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(isLatest && audioCapture.isLiveStreaming ? Color.green : Color.blue)
                                                .frame(width: 5, height: 5)
                                            Text(segment.timestampFormatted)
                                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                                        )

                                        // Clean spoken transcript text
                                        Text(segment.text)
                                            .font(.system(size: 13.5, weight: .regular, design: .default))
                                            .lineSpacing(3)
                                            .foregroundColor(.primary)
                                            .textSelection(.enabled)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isLatest && audioCapture.isLiveStreaming ? Color.purple.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.4))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isLatest && audioCapture.isLiveStreaming ? Color.purple.opacity(0.35) : Color.gray.opacity(0.1), lineWidth: 1)
                                    )
                                    .id(segment.id)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 180, maxHeight: 320)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    .onChange(of: transcription.segments.count) { _, _ in
                        if let last = transcription.segments.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)

            // Footer
            HStack {
                Text("LocTrip • Part 7: M2 Performance, Global Hotkeys & Final Polish")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Review Permissions") {
                    appState.showSettingsModal = true
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
        }
    }
    .frame(minWidth: 760, minHeight: 680)
    .task {
        await audioCapture.loadTargets()
    }
    .sheet(isPresented: $appState.showSettingsModal) {
        PermissionView {
            appState.showSettingsModal = false
        }
    }
    .sheet(isPresented: $appState.showHistoryModal) {
        MeetingHistoryView {
            appState.showHistoryModal = false
        }
    }
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
    return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
}
}
