import Foundation

/// Hardware hinge status, mirroring SwiftUI `DeviceHinge.Status` /
/// UIKit `UIHinge.Status` (iOS 27.1). Kept platform-free so the posture
/// rules are unit-testable on any SDK.
public enum HingeStatus: String, Sendable, Codable, CaseIterable {
    case closed
    case partiallyOpen
    case fullyOpen
    /// UIKit-only; Apple recommends treating it as `fullyOpen`.
    case unknown
}

/// The physical pose Stiki adapts to.
public enum HingePose: String, Sendable, Codable, CaseIterable {
    /// A non-folding iPhone (or iPad). Behaviour must stay unchanged.
    case standardPhone
    /// iPhone Duo folded shut; the app runs on the outer cover display.
    case closed
    /// Flat open on the large inner display.
    case fullyOpen
    /// Partially open, held like a book (fold is vertical).
    case book
    /// Partially open, standing on its edges like a tent (hands-free).
    case tent
    /// Partially open, bottom half resting on a table, top half upright
    /// (laptop-like "Flex" pose; hands-free top, touch bottom).
    case seated

    /// Poses where nobody is expected to hold the device.
    public var isHandsFree: Bool { self == .tent || self == .seated }
    /// Poses where an active fold splits the screen.
    public var hasActiveCrease: Bool { self == .book || self == .tent || self == .seated }
}

/// Which physical display the scene is on.
public enum DisplaySurface: String, Sendable, Codable {
    case standard
    case outerCover
    case inner
}

/// Orientation of the fold line relative to the scene.
public enum CreaseAxis: String, Sendable, Codable {
    /// Fold runs top-to-bottom (left/right panes).
    case vertical
    /// Fold runs left-to-right (top/bottom panes).
    case horizontal
}

/// Pure snapshot of everything layout needs.
public struct DevicePresentation: Sendable, Equatable, Codable {
    public var pose: HingePose
    public var surface: DisplaySurface
    /// Fold rectangle in scene coordinates, if a division region exists.
    public var crease: CGRectCodable?
    public var creaseIsActive: Bool
    public var hingeAngleDegrees: Double?

    public init(
        pose: HingePose,
        surface: DisplaySurface,
        crease: CGRectCodable? = nil,
        creaseIsActive: Bool = false,
        hingeAngleDegrees: Double? = nil
    ) {
        self.pose = pose
        self.surface = surface
        self.crease = crease
        self.creaseIsActive = creaseIsActive
        self.hingeAngleDegrees = hingeAngleDegrees
    }

    public static let standardPhone = DevicePresentation(pose: .standardPhone, surface: .standard)

    /// Should the root use a dual pane (sidebar + detail)?
    public var prefersDualPane: Bool {
        surface == .inner && (pose == .fullyOpen || pose == .book)
    }

    /// Should the root show the glanceable StandBy-style surface?
    public var prefersGlanceable: Bool { pose.isHandsFree }

    public var creaseAxis: CreaseAxis? {
        guard let crease else { return nil }
        return crease.height >= crease.width ? .vertical : .horizontal
    }
}

/// Codable rect so the package stays free of CoreGraphics on Linux tests.
public struct CGRectCodable: Sendable, Equatable, Codable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
}

/// Turns raw hinge/scene signals into a `DevicePresentation`.
public enum PostureResolver {
    /// - Parameters:
    ///   - hasHinge: `false` when the SDK reports no hinge (`context.hinge == nil`).
    ///   - status: hinge status.
    ///   - angleDegrees: 0 = closed, 180 = flat.
    ///   - sceneWidth/sceneHeight: scene size in points.
    ///   - isInnerDisplay: whether the scene lives on the large inner display.
    ///   - gravityDownAlongFold: `true` when gravity points along the fold
    ///     line (book), `false` when across it (tent / seated). `nil` = unknown.
    ///   - lowerHalfIsFlat: in an across-fold pose, `true` when one half lies
    ///     flat on a surface (seated) rather than both halves angled (tent).
    public static func resolve(
        hasHinge: Bool,
        status: HingeStatus,
        angleDegrees: Double?,
        isInnerDisplay: Bool,
        crease: CGRectCodable?,
        creaseIsActive: Bool,
        gravityDownAlongFold: Bool? = nil,
        lowerHalfIsFlat: Bool? = nil
    ) -> DevicePresentation {
        guard hasHinge else { return .standardPhone }
        let effective: HingeStatus = status == .unknown ? .fullyOpen : status
        switch effective {
        case .closed:
            return DevicePresentation(pose: .closed, surface: .outerCover, hingeAngleDegrees: angleDegrees)
        case .fullyOpen, .unknown:
            return DevicePresentation(
                pose: .fullyOpen,
                surface: isInnerDisplay ? .inner : .outerCover,
                crease: crease,
                creaseIsActive: false,
                hingeAngleDegrees: angleDegrees
            )
        case .partiallyOpen:
            let pose: HingePose
            if gravityDownAlongFold ?? true {
                pose = .book
            } else if lowerHalfIsFlat ?? false {
                pose = .seated
            } else {
                pose = .tent
            }
            return DevicePresentation(
                pose: pose,
                surface: isInnerDisplay ? .inner : .outerCover,
                crease: crease,
                creaseIsActive: creaseIsActive,
                hingeAngleDegrees: angleDegrees
            )
        }
    }
}

/// Crease-aware geometry: keep primary controls off the fold.
public enum CreaseLayout {
    /// Splits a container into the two panes on either side of the crease.
    /// Returns a single full pane when there is no crease.
    public static func panes(
        containerWidth: Double,
        containerHeight: Double,
        crease: CGRectCodable?
    ) -> [CGRectCodable] {
        let full = CGRectCodable(x: 0, y: 0, width: containerWidth, height: containerHeight)
        guard let crease, crease.width > 0 || crease.height > 0 else { return [full] }
        if crease.height >= crease.width {
            let left = CGRectCodable(x: 0, y: 0, width: max(0, crease.minX), height: containerHeight)
            let right = CGRectCodable(
                x: crease.maxX, y: 0,
                width: max(0, containerWidth - crease.maxX), height: containerHeight
            )
            return [left, right].filter { $0.width > 0 }
        } else {
            let top = CGRectCodable(x: 0, y: 0, width: containerWidth, height: max(0, crease.minY))
            let bottom = CGRectCodable(
                x: 0, y: crease.maxY,
                width: containerWidth, height: max(0, containerHeight - crease.maxY)
            )
            return [top, bottom].filter { $0.height > 0 }
        }
    }

    /// `true` if `control` overlaps the crease (plus a safety margin).
    public static func intersectsCrease(
        _ control: CGRectCodable,
        crease: CGRectCodable?,
        margin: Double = 8
    ) -> Bool {
        guard let crease else { return false }
        return control.minX < crease.maxX + margin && control.maxX > crease.minX - margin
            && control.minY < crease.maxY + margin && control.maxY > crease.minY - margin
    }

    /// Shifts `control` to the nearest side of the crease so it no longer
    /// straddles it. Returns the control unchanged when there is no overlap.
    public static func nudgedOffCrease(
        _ control: CGRectCodable,
        crease: CGRectCodable?,
        margin: Double = 8
    ) -> CGRectCodable {
        guard let crease, intersectsCrease(control, crease: crease, margin: margin) else { return control }
        var moved = control
        if crease.height >= crease.width {
            let center = control.x + control.width / 2
            let creaseCenter = crease.x + crease.width / 2
            moved.x = center < creaseCenter
                ? crease.minX - margin - control.width
                : crease.maxX + margin
        } else {
            let center = control.y + control.height / 2
            let creaseCenter = crease.y + crease.height / 2
            moved.y = center < creaseCenter
                ? crease.minY - margin - control.height
                : crease.maxY + margin
        }
        return moved
    }
}
