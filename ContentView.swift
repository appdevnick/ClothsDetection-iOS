import SwiftUI

struct ContentView: View {
    @Environment(\.container) private var container

    var body: some View {
        NavigationStack {
            container.makeClothingDetectionView()
        }
    }
}
