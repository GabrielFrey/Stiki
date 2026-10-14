import StikiCore
import SwiftUI

struct AnimateInspector: View {
    @Bindable var model: CreateViewModel
    var isPro: Bool
    var onLocked: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animate")
                .font(.headline)
            if !isPro {
                Text("Animated stickers are included with Stiki Pro.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("See Stiki Pro") { onLocked() }
                    .buttonStyle(.glassProminent)
            } else if model.session?.videoData == nil {
                Text("This sticker started from a still photo. Import a Live Photo or a video up to 3 seconds to animate it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if var spec = model.session?.recipe.animation {
                GlassInspectorRow(title: "Start", systemImage: "forward.end") {
                    Slider(value: Binding(
                        get: { spec.startSeconds },
                        set: {
                            spec.startSeconds = $0
                            model.session?.recipe.animation = spec
                        }
                    ), in: 0...3)
                    .accessibilityLabel("Trim start")
                }
                GlassInspectorRow(title: "Length", systemImage: "timer") {
                    Slider(value: Binding(
                        get: { spec.durationSeconds },
                        set: {
                            spec.durationSeconds = $0
                            model.session?.recipe.animation = spec
                        }
                    ), in: 0.2...3)
                    .accessibilityLabel("Trim length")
                }
                Toggle("Reuse first-frame mask", isOn: Binding(
                    get: { spec.reusesFirstFrameMask },
                    set: {
                        spec.reusesFirstFrameMask = $0
                        model.session?.recipe.animation = spec
                    }
                ))
            } else {
                Button("Use 3-second clip") {
                    model.session?.recipe.animation = AnimationSpec()
                }
                .buttonStyle(.glass)
            }
        }
    }
}
