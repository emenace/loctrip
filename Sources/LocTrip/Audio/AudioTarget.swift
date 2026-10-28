import Foundation
import ScreenCaptureKit

public struct AudioTarget: Identifiable, Hashable {
    public enum TargetType: Hashable {
        case entireSystem
        case application(bundleID: String, name: String, processID: pid_t)
    }

    public let id: String
    public let name: String
    public let type: TargetType
    public let iconName: String
    public var runningApplication: SCRunningApplication?

    public init(id: String, name: String, type: TargetType, iconName: String = "app.fill", runningApplication: SCRunningApplication? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.iconName = iconName
        self.runningApplication = runningApplication
    }

    public static let entireSystem = AudioTarget(
        id: "system.all",
        name: "Entire System Audio",
        type: .entireSystem,
        iconName: "speaker.wave.3.fill"
    )

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AudioTarget, rhs: AudioTarget) -> Bool {
        lhs.id == rhs.id
    }
}
