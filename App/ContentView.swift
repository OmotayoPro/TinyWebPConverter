import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Tiny WebP Converter")
                .font(.title2)
                .bold()
            Text("Interface coming soon.")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 480, minHeight: 320)
        .padding()
    }
}

#Preview {
    ContentView()
}
