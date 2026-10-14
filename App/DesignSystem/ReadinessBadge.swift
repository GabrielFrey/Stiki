import StikiCore
import SwiftUI

/// The per-target traffic light shown on packs, stickers and the export sheet.
///
/// This badge is the product's answer to the most common one-star review in
/// the category: the user learns a pack will be rejected *while building it*,
/// not when the messenger refuses the hand-off.
struct ReadinessBadge: View {
    var target: ExportTarget
    var readiness: Readiness
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: readiness.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(readiness.tint)
            if !isCompact {
                Text(target.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, isCompact ? 8 : 12)
        .padding(.vertical, 7)
        .stikiGlass(.regular)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(target.displayName))
        .accessibilityValue(Text(readiness.accessibilityValue))
    }
}

/// A horizontal run of badges for every target, merged into one glass group.
struct ReadinessBadgeRow: View {
    var readinessByTarget: [ExportTarget: Readiness]
    var isCompact: Bool = false

    var body: some View {
        GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
            HStack(spacing: 8) {
                ForEach(ExportTarget.badgedTargets) { target in
                    ReadinessBadge(
                        target: target,
                        readiness: readinessByTarget[target] ?? .blocked,
                        isCompact: isCompact
                    )
                }
            }
        }
    }
}

extension Readiness {
    var systemImage: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .fixable: return "wand.and.sparkles"
        case .blocked: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready: return .green
        case .fixable: return .orange
        case .blocked: return .red
        }
    }

    /// Spoken by VoiceOver in place of the colour, which carries the meaning
    /// visually.
    var accessibilityValue: LocalizedStringKey {
        switch self {
        case .ready: return "Ready"
        case .fixable: return "Needs a quick fix"
        case .blocked: return "Not ready"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .ready: return "Ready to export"
        case .fixable: return "Stiki can fix this for you"
        case .blocked: return "Needs your attention"
        }
    }
}

extension ExportTarget {
    /// Localized product name. Brand names are not translated, but the Photos
    /// and Files destination is.
    var displayName: LocalizedStringKey {
        switch self {
        case .iMessage: return "iMessage"
        case .whatsApp: return "WhatsApp"
        case .telegram: return "Telegram"
        case .photosAndFiles: return "Photos & Files"
        }
    }

    var systemImage: String {
        switch self {
        case .iMessage: return "message.fill"
        case .whatsApp: return "phone.bubble.fill"
        case .telegram: return "paperplane.fill"
        case .photosAndFiles: return "square.and.arrow.down"
        }
    }
}

#Preview("Readiness") {
    ZStack {
        LinearGradient(colors: [.mint, .indigo], startPoint: .top, endPoint: .bottom)
        VStack(spacing: 20) {
            ReadinessBadgeRow(readinessByTarget: [
                .iMessage: .ready,
                .whatsApp: .fixable,
                .telegram: .blocked
            ])
            ReadinessBadgeRow(
                readinessByTarget: [.iMessage: .ready, .whatsApp: .ready, .telegram: .ready],
                isCompact: true
            )
        }
    }
    .ignoresSafeArea()
}
