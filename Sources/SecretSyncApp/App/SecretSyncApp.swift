import SecretSyncKit
import SwiftUI

@main
struct SecretSyncApp: App {
    private let container = AppContainer.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
