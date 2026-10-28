import Foundation
import AppKit
import AVFoundation
import CoreGraphics
import Combine

@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public private(set) var hasScreenCapturePermission: Bool = false
    @Published public private(set) var microphoneStatus: AVAuthorizationStatus = .notDetermined

    public var isMicrophoneGranted: Bool {
        microphoneStatus == .authorized
    }

    public var isAllGranted: Bool {
        hasScreenCapturePermission && isMicrophoneGranted
    }

    private var cancellables = Set<AnyCancellable>()

    public init() {
        checkAllPermissions()
        setupAppActiveObserver()
    }

    /// Re-check all permissions whenever the app regains focus from macOS System Settings
    private func setupAppActiveObserver() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkAllPermissions()
            }
            .store(in: &cancellables)
    }

    public func checkAllPermissions() {
        checkScreenCapturePermission()
        checkMicrophonePermission()
    }

    public func checkScreenCapturePermission() {
        let granted = CGPreflightScreenCaptureAccess()
        if self.hasScreenCapturePermission != granted {
            self.hasScreenCapturePermission = granted
        }
    }

    public func requestScreenCapturePermission() {
        if !CGPreflightScreenCaptureAccess() {
            // Prompts macOS dialog to grant Screen Recording permission in System Settings
            _ = CGRequestScreenCaptureAccess()
        }
        checkScreenCapturePermission()
    }

    public func checkMicrophonePermission() {
        self.microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    public func requestMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.microphoneStatus = granted ? .authorized : .denied
                }
            }
        } else if status == .denied || status == .restricted {
            openMicrophoneSettings()
        }
    }

    public func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
