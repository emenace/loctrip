import SwiftUI

public struct FloatingHUDView: View {
    @ObservedObject var audioCapture = AudioCaptureViewModel.shared
    @ObservedObject var transcription = TranscriptionViewModel.shared
    @ObservedObject var appState = AppViewModel.shared

    public init() {}

    public var body: some View {
        ZStack {
            // Glassmorphism background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(appState.hudOpacity)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)

            VStack(spacing: 12) {
                // Header (Draggable)
                HStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(.purple)
                        .font(.headline)

                    Text("LocTrip HUD")
                        .font(.subheadline.bold())

                    Spacer()

                    // VAD Speech Indicator
                    HStack(spacing: 5) {
                        Circle()
                            .fill(audioCapture.isSpeechDetected ? Color.green : Color.gray.opacity(0.4))
                            .frame(width: 7, height: 7)
                        Text(audioCapture.isSpeechDetected ? "Speech" : "Idle")
                            .font(.caption2.bold())
                            .foregroundColor(audioCapture.isSpeechDetected ? .green : .secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)

                    // Recording Duration
                    if audioCapture.isLiveStreaming {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text(formatDuration(audioCapture.recordingDuration))
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(6)
                    }

                    // Close HUD button
                    Button {
                        HUDWindowManager.shared.hideHUD()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                // Mini Waveform Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .yellow, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width * CGFloat(audioCapture.audioLevel), geo.size.width)), height: 4)
                            .animation(.easeOut(duration: 0.08), value: audioCapture.audioLevel)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 14)

                // Live Transcript Bubbles
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if transcription.segments.isEmpty {
                                Text(audioCapture.isLiveStreaming ? "Listening for speech..." : "Live streaming stopped.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
                            } else {
                                ForEach(transcription.segments.suffix(15)) { segment in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(segment.timestampFormatted)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)

                                        Text(segment.text)
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                    .padding(.vertical, 1)
                                    .id(segment.id)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .frame(maxHeight: .infinity)
                    .onChange(of: transcription.segments.count) { _, _ in
                        if let last = transcription.segments.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Controls Footer
                HStack(spacing: 10) {
                    Button {
                        Task {
                            if audioCapture.isLiveStreaming {
                                await audioCapture.stopLiveStreaming()
                            } else {
                                await audioCapture.startLiveStreaming(languageCode: appState.selectedLanguage)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: audioCapture.isLiveStreaming ? "stop.fill" : "play.fill")
                            Text(audioCapture.isLiveStreaming ? "Stop" : "Stream")
                        }
                        .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(audioCapture.isLiveStreaming ? .red : .purple)
                    .controlSize(.small)

                    Button {
                        transcription.copyTranscriptToClipboard()
                    } label: {
                        Image(systemName: transcription.copiedToClipboard ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Copy transcript")

                    Spacer()

                    // Transparency Slider
                    HStack(spacing: 4) {
                        Image(systemName: "sun.min")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Slider(value: $appState.hudOpacity, in: 0.4...1.0)
                            .frame(width: 70)
                            .controlSize(.mini)
                        Image(systemName: "sun.max")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 440, height: 260)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
