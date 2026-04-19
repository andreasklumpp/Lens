import SwiftUI

@main
struct LensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No regular windows — LSUIElement keeps us out of the Dock.
        // Settings window is opened imperatively from AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
