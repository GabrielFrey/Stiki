import SwiftUI

/// A small selectable glass pill, used for filters, outline styles and emoji
/// tags.
struct GlassChip: View {
    var title: LocalizedStringKey
    var systemImage: String?
    var isSelected: Bool
    var isLocked: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .lineLimit(1)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(HierarchicalShapeStyle.primary))
        .stikiGlass(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isLocked ? "Included with Stiki Pro" : "")
    }
}

/// A chip that displays a plain string rather than a localized key, for
/// user-authored content such as emoji tags and pack names.
struct GlassTextChip: View {
    var text: String
    var isSelected: Bool = false
    var onRemove: (() -> Void)?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.subheadline.weight(.semibold))
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.capsule)
        .stikiGlass(isSelected ? .regular.tint(.accentColor) : .regular)
        .onTapGesture { action?() }
    }
}

#Preview("Chips") {
    ZStack {
        LinearGradient(colors: [.indigo, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
            VStack(spacing: 12) {
                HStack(spacing: GlassMetrics.paletteSpacing) {
                    GlassChip(title: "Vivid", systemImage: "wand.and.stars", isSelected: true) {}
                    GlassChip(title: "Comic", systemImage: "book", isSelected: false, isLocked: true) {}
                }
                HStack(spacing: GlassMetrics.paletteSpacing) {
                    GlassTextChip(text: "😀", onRemove: {})
                    GlassTextChip(text: "🔥", isSelected: true)
                }
            }
        }
    }
    .ignoresSafeArea()
}
