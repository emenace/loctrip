import Foundation
import Combine

@MainActor
public final class AppViewModel: ObservableObject {
    public static let shared = AppViewModel()

    @Published public var selectedLanguage: String = "auto"
    @Published public var showSettingsModal: Bool = false
    @Published public var hasCompletedOnboarding: Bool = false

    public init() {}
}
