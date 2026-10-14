import SwiftUI

/// A glass panel that groups related content, with an optional title row.
struct GlassCard<Content: View>: View {
    var title: LocalizedStringKey?
    var systemImage: String?
    var footnote: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label {
                    Text(title)
                        .font(.headline)
                } icon: {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(.tint)
                    }
                }
                .labelStyle(.titleAndIcon)
            }

            content

            if let footnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stikiGlassPanel()
    }
}

/// The empty state used by the library, packs and import screens.
///
/// Empty states are a product surface here, not a placeholder: the first-run
/// library is where we teach the one-tap cutout that competitors bury.
struct GlassEmptyState<Actions: View>: View {
    var systemImage: String
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    @ViewBuilder var actions: Actions

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 54

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions
        }
        .padding(28)
        .frame(maxWidth: 420)
        .stikiGlassPanel(cornerRadius: 32)
        .padding(.horizontal, 24)
    }
}

/// A labelled row for inspector panels, keeping label and control aligned as
/// Dynamic Type grows.
struct GlassInspectorRow<Control: View>: View {
    var title: LocalizedStringKey
    var systemImage: String?
    @ViewBuilder var control: Control

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 14))

        layout {
            Label {
                Text(title)
                    .font(.subheadline.weight(.medium))
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage)
                }
            }
            .frame(minWidth: 96, alignment: .leading)

            control
        }
    }
}

#Preview("Cards") {
    ZStack {
        LinearGradient(colors: [.teal, .blue], startPoint: .top, endPoint: .bottom)
        GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
            VStack(spacing: 16) {
                GlassCard(
                    title: "WhatsApp",
                    systemImage: "checkmark.seal",
                    footnote: "512×512 WebP, up to 100 KB per sticker."
                ) {
                    Text("Ready to send")
                        .font(.subheadline)
                }
                GlassEmptyState(
                    systemImage: "sparkles",
                    title: "No stickers yet",
                    message: "Pick a photo and Stiki lifts the subject out for you."
                ) {
                    GlassActionButton(systemImage: "photo", title: "Choose a photo", isProminent: true) {}
                }
            }
            .padding()
        }
    }
    .ignoresSafeArea()
}
