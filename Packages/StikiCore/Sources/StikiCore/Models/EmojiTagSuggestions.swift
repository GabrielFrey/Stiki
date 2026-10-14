import Foundation

/// Emoji the app assigns when a target demands tags the user never set.
///
/// WhatsApp rejects a pack whose stickers carry no emoji, which is one of the
/// silent hand-off failures users blame on the messenger. Rather than block
/// the export we fill in sensible defaults and tell the user we did.
public enum EmojiTagSuggestions {
    /// Ordered by how broadly they apply, so taking a prefix gives a usable set.
    public static let fallback: [String] = ["😀", "✨", "❤️", "😂", "🔥", "👍", "🎉", "😎"]

    /// Returns `count` emoji not already present in `existing`.
    public static func suggestions(excluding existing: [String], count: Int) -> [String] {
        guard count > 0 else { return [] }
        let taken = Set(existing)
        return Array(fallback.lazy.filter { !taken.contains($0) }.prefix(count))
    }

    /// Normalises a tag list to a target's range: pads with defaults, trims
    /// the excess, and drops duplicates while keeping the user's order.
    public static func normalized(_ tags: [String], to range: ClosedRange<Int>?) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            unique.append(trimmed)
        }
        guard let range else { return unique }
        if unique.count > range.upperBound {
            return Array(unique.prefix(range.upperBound))
        }
        if unique.count < range.lowerBound {
            unique.append(
                contentsOf: suggestions(excluding: unique, count: range.lowerBound - unique.count)
            )
        }
        return unique
    }
}
