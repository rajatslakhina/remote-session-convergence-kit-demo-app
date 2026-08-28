import SwiftUI
import RemoteSessionConvergenceKit

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ConvergenceConsoleView(configuration: DemoConfiguration.livingRoomSpeaker)
                    .navigationTitle("Convergence")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
