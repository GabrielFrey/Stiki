import Foundation
import SwiftUI

enum EditorTool: String, Hashable, CaseIterable, Identifiable {
    case cutout
    case outline
    case text
    case emoji
    case filters
    case animate

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .cutout: return "Cut out"
        case .outline: return "Outline"
        case .text: return "Text"
        case .emoji: return "Emoji"
        case .filters: return "Filters"
        case .animate: return "Animate"
        }
    }

    var systemImage: String {
        switch self {
        case .cutout: return "scissors"
        case .outline: return "circle.dashed"
        case .text: return "textformat"
        case .emoji: return "face.smiling"
        case .filters: return "wand.and.stars"
        case .animate: return "play.circle"
        }
    }

    var requiresPro: Bool {
        switch self {
        case .animate: return true
        case .cutout, .outline, .text, .emoji, .filters: return false
        }
    }

    var glassTool: GlassTool {
        GlassTool(id: rawValue, systemImage: systemImage, label: label, isLocked: requiresPro)
    }
}
