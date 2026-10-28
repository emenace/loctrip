import SwiftUI

public struct DashboardView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @ObservedObject var appState = AppViewModel.shared
    @ObservedObject var audioCapture = AudioCaptureViewModel.shared
    @ObservedObject var transcription = TranscriptionViewModel.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Bar
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

                    // Language Mode Selector
                    Picker("Language", selection: $appState.selectedLanguage) {
                        Text("Auto (ID / EN)").tag("auto")
                        Text("Bahasa Indonesia").tag("id")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)

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

                // 1. Audio Ingestion Section (Part 2)
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("1. Audio Ingestion (ScreenCaptureKit)")
                                .font(.headline)
                            Text("Capture internal sound from Zoom, Google Meet, or entire system without drivers")
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
                        .disabled(audioCapture.isRecording)

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
                        .disabled(audioCapture.isRecording)
                    }

                    // Recording Controls & VU Meter Bar
                    VStack(spacing: 12) {
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(audioCapture.isRecording ? Color.red : Color.gray.opacity(0.5))
                                    .frame(width: 10, height: 10)
                                Text(audioCapture.statusMessage)
                                    .font(.subheadline.weight(.medium))
                            }

                            Spacer()

                            if audioCapture.isRecording {
                                Text(formatDuration(audioCapture.recordingDuration))
                                    .font(.system(.title3, design: .monospaced).weight(.bold))
                                    .foregroundColor(.red)
                            }
                        }

                        // VU Meter
                        VStack(alignment: .leading, spacing: 4) {
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
                        }

                        // Record Button
                        Button {
                            Task {
                                if audioCapture.isRecording {
                                    await audioCapture.stopTestRecording()
                                } else {
                                    await audioCapture.startTestRecording()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: audioCapture.isRecording ? "stop.fill" : "record.circle.fill")
                                Text(audioCapture.isRecording ? "Stop Capture Test" : "Record Output Audio Test")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(audioCapture.isRecording ? .red : .blue)
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(audioCapture.isRecording ? Color.red.opacity(0.4) : Color.gray.opacity(0.12), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)

                // 2. AI Model & Local Inference Section (Part 3)
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("2. On-Device AI Engine (WhisperKit CoreML)")
                                .font(.headline)
                            Text("Apple Neural Engine (ANE) acceleration • Multilingual ID + EN")
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
                        .frame(width: 310)
                        .disabled(transcription.isTranscribing)

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
                        .disabled(transcription.isTranscribing)
                    }

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

                    // Transcribe Action Bar
                    HStack(spacing: 12) {
                        Button {
                            if let url = audioCapture.lastSavedWavURL {
                                Task {
                                    await transcription.transcribeAudioFile(at: url, languageCode: appState.selectedLanguage)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if transcription.isTranscribing {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Transcribing Locally...")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Transcribe Captured Sound")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.large)
                        .disabled(!transcription.isModelReady || audioCapture.lastSavedWavURL == nil || transcription.isTranscribing)

                        if audioCapture.lastSavedWavURL != nil {
                            Button {
                                audioCapture.playLastRecording()
                            } label: {
                                Image(systemName: "play.circle")
                                Text("Play Audio")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if audioCapture.lastSavedWavURL == nil {
                        Text("Record a test audio sample above first to run on-device transcription.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                // 3. Live Transcript Output Area
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Transcription Result")
                            .font(.headline)

                        if transcription.lastInferenceTime > 0 {
                            Text("(\(String(format: "%.2f", transcription.lastInferenceTime))s on ANE)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        if !transcription.segments.isEmpty {
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
                        }
                    }

                    // Transcript Text Box
                    VStack(alignment: .leading, spacing: 8) {
                        if transcription.segments.isEmpty {
                            Text("No transcript yet. Record output audio and tap 'Transcribe Captured Sound' to test local Whisper inference.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                        } else {
                            ForEach(transcription.segments) { segment in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(segment.timestampFormatted)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)

                                    Text(segment.text)
                                        .font(.body)
                                        .textSelection(.enabled)

                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 20)

                // Footer
                HStack {
                    Text("LocTrip • Part 3: Local WhisperKit Inference")
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
        .frame(minWidth: 720, minHeight: 620)
        .task {
            await audioCapture.loadTargets()
        }
        .sheet(isPresented: $appState.showSettingsModal) {
            PermissionView {
                appState.showSettingsModal = false
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
