import SwiftUI
import SwiftData

@main
struct FashionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.container, DIContainer.shared)
        }
        .modelContainer(for: [ClothingItemRecord.self])
    }
}
