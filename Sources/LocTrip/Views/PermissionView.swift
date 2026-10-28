import SwiftUI
import AVFoundation

public struct PermissionView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    public var onContinue: (() -> Void)?

    public init(onContinue: (() -> Void)? = nil) {
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 28) {
            // Header
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)

                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("Welcome to LocTrip")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                Text("On-device meeting transcription for Indonesian & English")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 10)

            // Permissions Card List
            VStack(spacing: 16) {
                // 1. Screen Capture (Output Audio via ScreenCaptureKit)
                PermissionCard(
                    title: "Application & System Audio",
                    subtitle: "Uses macOS ScreenCaptureKit to record output sound directly from Zoom, Google Meet, or Chrome without extra virtual audio drivers.",
                    icon: "speaker.wave.3.fill",
                    accentColor: .blue,
                    isGranted: permissionManager.hasScreenCapturePermission,
                    onRequest: {
                        permissionManager.requestScreenCapturePermission()
                    },
                    onOpenSettings: {
                        permissionManager.openScreenCaptureSettings()
                    }
                )

                // 2. Microphone (Your Own Voice)
                PermissionCard(
                    title: "Microphone Access",
                    subtitle: "Captures your own speech alongside meeting participants so both sides of bilingual discussions are accurately transcribed.",
                    icon: "mic.fill",
                    accentColor: .teal,
                    isGranted: permissionManager.isMicrophoneGranted,
                    onRequest: {
                        permissionManager.requestMicrophonePermission()
                    },
                    onOpenSettings: {
                        permissionManager.openMicrophoneSettings()
                    }
                )
            }
            .padding(.horizontal, 8)

            // Privacy Guarantee Notice
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                    .font(.headline)

                Text("100% On-Device & Private. Audio is processed locally on Apple Silicon M2 and never leaves your computer.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)

            // Continue Button
            Button(action: {
                onContinue?()
            }) {
                HStack {
                    Text(permissionManager.isAllGranted ? "Continue to LocTrip" : "Waiting for Permissions")
                        .fontWeight(.semibold)
                    if permissionManager.isAllGranted {
                        Image(systemName: "arrow.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!permissionManager.isAllGranted)
        }
        .padding(32)
        .frame(width: 580)
        .onAppear {
            permissionManager.checkAllPermissions()
        }
    }
}

private struct PermissionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let isGranted: Bool
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                    if isGranted {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isGranted {
                Text("Enabled")
                    .font(.caption.bold())
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
            } else {
                HStack(spacing: 8) {
                    Button("Grant") {
                        onRequest()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .help("Open System Settings")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isGranted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
