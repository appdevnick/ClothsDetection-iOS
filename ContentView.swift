import SwiftUI

struct ContentView: View {
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            container.makeClothingDetectionView(modelContext: modelContext)
        }
    }
}
