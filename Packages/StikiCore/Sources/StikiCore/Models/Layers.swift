import Foundation

/// A text layer rendered on top of the subject.
public struct TextLayer: Codable, Hashable, Sendable, Identifiable {
    public enum FontStyle: String, Codable, Hashable, Sendable, CaseIterable {
        /// System rounded, heavy — the classic meme caption.
        case rounded
        case serif
        case monospaced
        /// Condensed all-caps, good for long captions on 512 px canvases.
        case condensed

        public var isSystemDefault: Bool { self == .rounded }
    }

    /// Where the baseline of the text sits relative to the subject.
    public enum Curve: String, Codable, Hashable, Sendable, CaseIterable {
        case straight
        /// Bent along an arc, opening upwards.
        case arcUp
        /// Bent along an arc, opening downwards.
        case arcDown
    }

    public var id: UUID
    public var text: String
    public var fontStyle: FontStyle
    /// Cap height as a fraction of the canvas height.
    public var relativeFontSize: Double
    public var color: RecipeColor
    public var strokeColor: RecipeColor
    /// Stroke width relative to the font size; `0` disables the stroke.
    public var strokeWidth: Double
    public var curve: Curve
    public var transform: LayerTransform

    public init(
        id: UUID = UUID(),
        text: String,
        fontStyle: FontStyle = .rounded,
        relativeFontSize: Double = 0.16,
        color: RecipeColor = .white,
        strokeColor: RecipeColor = .black,
        strokeWidth: Double = 0.12,
        curve: Curve = .straight,
        transform: LayerTransform = LayerTransform(position: UnitPoint2D(x: 0.5, y: 0.82))
    ) {
        self.id = id
        self.text = text
        self.fontStyle = fontStyle
        self.relativeFontSize = relativeFontSize
        self.color = color
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.curve = curve
        self.transform = transform
    }

    /// Trimmed text, or `nil` when the layer carries nothing to draw.
    public var renderableText: String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// An emoji stamped onto the canvas as a decoration.
public struct EmojiLayer: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var emoji: String
    /// Glyph height as a fraction of the canvas height.
    public var relativeSize: Double
    public var transform: LayerTransform

    public init(
        id: UUID = UUID(),
        emoji: String,
        relativeSize: Double = 0.22,
        transform: LayerTransform = LayerTransform()
    ) {
        self.id = id
        self.emoji = emoji
        self.relativeSize = relativeSize
        self.transform = transform
    }
}

/// How an animated sticker is sampled out of its source movie.
public struct AnimationSpec: Codable, Hashable, Sendable {
    /// Start of the trimmed range in seconds.
    public var startSeconds: Double
    /// Duration of the trimmed range in seconds.
    public var durationSeconds: Double
    public var framesPerSecond: Int
    /// Applies the first frame's mask to every frame instead of segmenting
    /// each one. Much faster, and good enough for a steady camera.
    public var reusesFirstFrameMask: Bool
    public var loops: Bool

    public init(
        startSeconds: Double = 0,
        durationSeconds: Double = 3,
        framesPerSecond: Int = 24,
        reusesFirstFrameMask: Bool = false,
        loops: Bool = true
    ) {
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
        self.framesPerSecond = framesPerSecond
        self.reusesFirstFrameMask = reusesFirstFrameMask
        self.loops = loops
    }

    /// Number of frames the sampler will request, at least one.
    public var frameCount: Int {
        max(1, Int((durationSeconds * Double(framesPerSecond)).rounded()))
    }

    /// Per-frame duration in milliseconds, which messengers validate.
    public var frameDurationMilliseconds: Int {
        max(1, Int((1000.0 / Double(max(1, framesPerSecond))).rounded()))
    }

    /// Timestamps, in seconds, to extract from the source movie.
    public func frameTimestamps() -> [Double] {
        let count = frameCount
        let step = durationSeconds / Double(count)
        return (0..<count).map { startSeconds + (Double($0) + 0.5) * step }
    }
}
