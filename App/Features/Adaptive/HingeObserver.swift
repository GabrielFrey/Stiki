import StikiCore
import SwiftUI

/// Bridges the iOS 27.1 iPhone Duo APIs into `DevicePresentationModel`.
///
/// Public APIs used when `STIKI_DUO_SDK` is defined (Xcode 27.1+ / iOS 27.1 SDK):
/// - `View.onHingeChange(isEnabled:_:)` → `DeviceHingeContext.hinge` (`nil` on
///   non-folding devices), `.status`, `.angle`.
/// - `GeometryProxy.reservedRegions(kind: .division, options: .includeInactive)`
///   → fold frame and `isActive`.
/// Without the flag this is a no-op, so the project still builds on the
/// iOS 26 SDK and standard iPhones behave exactly as before.
struct HingeObserver: ViewModifier {
    let model: DevicePresentationModel

    func body(content: Content) -> some View {
        #if STIKI_DUO_SDK
        if #available(iOS 27.1, *) {
            content
                .background {
                    GeometryReader { proxy in
                        let division = proxy.reservedRegions(kind: .division, options: .includeInactive).first
                        Color.clear
                            .onAppear { report(division: division, size: proxy.size) }
                            .onChange(of: proxy.size) { _, size in report(division: division, size: size) }
                    }
                }
                .onHingeChange { _, context in
                    guard let hinge = context.hinge else {
                        model.updateHinge(hasHinge: false, status: .fullyOpen, angleDegrees: nil)
                        return
                    }
                    let status: HingeStatus = switch hinge.status {
                    case .closed: .closed
                    case .partiallyOpen: .partiallyOpen
                    case .fullyOpen: .fullyOpen
                    @unknown default: .unknown
                    }
                    model.updateHinge(hasHinge: true, status: status, angleDegrees: hinge.angle.degrees)
                }
        } else {
            content
        }
        #else
        content
        #endif
    }

    #if STIKI_DUO_SDK
    @available(iOS 27.1, *)
    private func report(division: GeometryProxy.ReservedRegion?, size: CGSize) {
        // A division region only exists on the inner display.
        model.updateDivision(
            frame: division?.frame,
            isActive: division?.isActive ?? false,
            isInnerDisplay: division != nil
        )
    }
    #endif
}

extension View {
    func observingHinge(_ model: DevicePresentationModel) -> some View {
        modifier(HingeObserver(model: model))
    }
}
