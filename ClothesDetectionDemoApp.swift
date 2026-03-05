import SwiftUI

@main
struct FashionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.container, DIContainer.shared)
        }
    }
}
