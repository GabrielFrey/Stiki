import SwiftData
import SwiftUI

/// Stiki's entry point.
@main
struct StikiApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.stiki, environment)
                .environment(\.undoManager, UndoManager())
        }
        .modelContainer(environment.modelContainer)
    }
}
