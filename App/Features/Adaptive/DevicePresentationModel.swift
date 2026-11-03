import CoreMotion
import Observation
import StikiCore
import SwiftUI

/// Live source of truth for the device's pose (iPhone Duo / Flexibility).
///
/// Inputs, in priority order:
/// 1. A debug/UI-test override (`-StikiSimulatedPose <pose>` launch argument).
/// 2. The iOS 27.1 hinge + reserved-region APIs, compiled only when the
///    `STIKI_DUO_SDK` flag is set (see docs/duo-flexibility.md).
/// 3. Nothing: on every non-folding iPhone the hinge is absent and the
///    presentation stays `.standardPhone`, so the classic tab UI is untouched.
@MainActor
@Observable
final class DevicePresentationModel {
    private(set) var presentation: DevicePresentation = .standardPhone

    @ObservationIgnored private let override: HingePose?
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var gravity: (x: Double, y: Double, z: Double)?

    // Last raw hinge inputs, re-resolved when gravity changes.
    @ObservationIgnored private var hasHinge = false
    @ObservationIgnored private var status: HingeStatus = .fullyOpen
    @ObservationIgnored private var angle: Double?
    @ObservationIgnored private var crease: CGRectCodable?
    @ObservationIgnored private var creaseIsActive = false
    @ObservationIgnored private var isInnerDisplay = false

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if let index = arguments.firstIndex(of: "-StikiSimulatedPose"),
           arguments.indices.contains(index + 1),
           let pose = HingePose(rawValue: arguments[index + 1]) {
            override = pose
            presentation = Self.simulated(pose)
        } else {
            override = nil
        }
    }

    /// Preview / test factory.
    static func fixed(_ pose: HingePose) -> DevicePresentationModel {
        DevicePresentationModel(arguments: ["-StikiSimulatedPose", pose.rawValue])
    }

    /// Feed from the hinge API (`DeviceHingeContext`), translated to plain values.
    func updateHinge(hasHinge: Bool, status: HingeStatus, angleDegrees: Double?) {
        self.hasHinge = hasHinge
        self.status = status
        self.angle = angleDegrees
        if hasHinge && status == .partiallyOpen { startMotion() } else { stopMotion() }
        resolve()
    }

    /// Feed from `GeometryProxy.reservedRegions(kind: .division, …)`.
    func updateDivision(frame: CGRect?, isActive: Bool, isInnerDisplay: Bool) {
        crease = frame.map {
            CGRectCodable(x: $0.minX, y: $0.minY, width: $0.width, height: $0.height)
        }
        creaseIsActive = isActive
        self.isInnerDisplay = isInnerDisplay
        resolve()
    }

    private func resolve() {
        guard override == nil else { return }
        var alongFold: Bool?
        var lowerFlat: Bool?
        if let gravity, let axis = crease.map({ $0.height >= $0.width ? CreaseAxis.vertical : .horizontal }) {
            // Book: gravity runs parallel to the fold line.
            // Tent/seated: gravity runs across it. Seated when the sensor half
            // (the lower half on iPhone Duo) lies nearly flat (|z| ≈ 1 g).
            let parallel = axis == .vertical ? abs(gravity.y) : abs(gravity.x)
            let across = axis == .vertical ? abs(gravity.x) : abs(gravity.y)
            alongFold = parallel >= across
            lowerFlat = abs(gravity.z) > 0.8
        }
        let next = PostureResolver.resolve(
            hasHinge: hasHinge,
            status: status,
            angleDegrees: angle,
            isInnerDisplay: isInnerDisplay,
            crease: crease,
            creaseIsActive: creaseIsActive,
            gravityDownAlongFold: alongFold,
            lowerHalfIsFlat: lowerFlat
        )
        if next != presentation {
            withAnimation(.smooth) { presentation = next }
        }
    }

    private func startMotion() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.25
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            MainActor.assumeIsolated {
                self.gravity = (g.x, g.y, g.z)
                self.resolve()
            }
        }
    }

    private func stopMotion() {
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        gravity = nil
    }

    private static func simulated(_ pose: HingePose) -> DevicePresentation {
        switch pose {
        case .standardPhone: return .standardPhone
        case .closed: return DevicePresentation(pose: .closed, surface: .outerCover)
        case .fullyOpen: return DevicePresentation(pose: .fullyOpen, surface: .inner)
        case .book, .tent, .seated:
            return DevicePresentation(pose: pose, surface: .inner, creaseIsActive: true, hingeAngleDegrees: 110)
        }
    }
}

private enum DevicePresentationKey: EnvironmentKey {
    static let defaultValue = DevicePresentation.standardPhone
}

extension EnvironmentValues {
    /// Current pose snapshot; `.standardPhone` everywhere by default.
    var devicePresentation: DevicePresentation {
        get { self[DevicePresentationKey.self] }
        set { self[DevicePresentationKey.self] = newValue }
    }
}
