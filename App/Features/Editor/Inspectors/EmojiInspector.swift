import StikiCore
import SwiftUI

struct EmojiInspector: View {
    @Binding var recipe: EditRecipe

    private let palette = ["😀", "😂", "🔥", "❤️", "✨", "👍", "🎉", "😎", "🐱", "🌈"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emoji")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                ForEach(palette, id: \.self) { emoji in
                    Button {
                        recipe.emojiLayers.append(
                            EmojiLayer(
                                emoji: emoji,
                                transform: LayerTransform(position: UnitPoint2D(x: 0.8, y: 0.2))
                            )
                        )
                    } label: {
                        Text(emoji)
                            .font(.largeTitle)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(emoji)")
                }
            }
            if !recipe.emojiLayers.isEmpty {
                Button("Remove last", role: .destructive) {
                    _ = recipe.emojiLayers.popLast()
                }
                .buttonStyle(.glass)
            }
        }
    }
}
