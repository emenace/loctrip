import SwiftUI

public struct ContentView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @ObservedObject var appState = AppViewModel.shared

    public init() {}

    public var body: some View {
        Group {
            if permissionManager.isAllGranted || appState.hasCompletedOnboarding {
                DashboardView()
            } else {
                PermissionView {
                    appState.hasCompletedOnboarding = true
                }
            }
        }
    }
}
