# iPhone Duo & Flexibility (Flex/pose) support

Stiki treats iPhone Duo as a first-class target next to the regular iPhone.

## Public Apple APIs used (iOS 27.1 SDK, Xcode 27.1)

| Need | API | Where |
|---|---|---|
| Hinge status + angle | `View.onHingeChange(isEnabled:_:)`, `DeviceHingeContext.hinge` (`nil` on non-folding devices), `.status` (`closed` / `partiallyOpen` / `fullyOpen`), `.angle` | `App/Features/Adaptive/HingeObserver.swift` |
| Fold location | `GeometryProxy.reservedRegions(kind: .division, options: .includeInactive)` → `frame`, `isActive` | `HingeObserver.swift` |
| Tent vs seated vs book | `CMMotionManager` device-motion gravity (public, no permission) | `DevicePresentationModel.swift` |
| Dual pane | `NavigationSplitView` (Apple: standard components expand into columns on the inner display) | `AdaptiveRootView.swift` |
| Hands-free | `isIdleTimerDisabled`, `persistentSystemOverlays(.hidden)` | `GlanceRootView.swift` |

Sources: Apple Tech Talk "Leverage multiple displays and scenes on iPhone Duo"
(developer.apple.com/videos/play/tech-talks/111464), SwiftUI docs for
`onHingeChange(isEnabled:_:)` and `DeviceHinge`, Apple Newsroom (Oct 2026).

## Build flag

The repo's documented toolchain is the iOS 26 SDK, which does not contain the
Duo APIs. The real API calls are therefore behind `#if STIKI_DUO_SDK` **and**
`if #available(iOS 27.1, *)`. Add `STIKI_DUO_SDK` to
`SWIFT_ACTIVE_COMPILATION_CONDITIONS` in `project.yml` when building with
Xcode 27.1+. Without it, every device resolves to `.standardPhone` and the
classic tab UI is used — no behaviour change on regular iPhones.

## Poses → layout

| Pose | Surface | Root |
|---|---|---|
| `standardPhone` | regular iPhone | `RootTabView` (unchanged) |
| `closed` | outer cover (same aspect ratio as iPhone) | `RootTabView` |
| `fullyOpen` | inner display | `DualPaneRootView` (sidebar + detail) |
| `book` | inner, partially open, fold parallel to gravity | `DualPaneRootView`, crease-safe padding |
| `tent` | partially open, standing on edges | `GlanceRootView` (StandBy-style carousel) |
| `seated` | partially open, lower half flat (Flex) | `GlanceRootView`, carousel on top half, controls on bottom half |

Pure rules live in `Packages/StikiCore/Sources/StikiCore/Layout/DevicePosture.swift`
(`PostureResolver`, `CreaseLayout`) with tests in `DevicePostureTests.swift`.

## Assumptions / unverified

- Exact Swift signatures of the iOS 27.1 APIs were taken from Apple's tech-talk
  sample code and secondary write-ups; they were **not compiled** here (no
  Xcode / Mac). If a name differs, only `HingeObserver.swift` needs updating.
- Apple does not expose named "tent/seated/book" poses; Stiki derives them
  from hinge status + gravity relative to the fold (heuristic, thresholds in
  `DevicePresentationModel.resolve()`).
- Apple recommends `ArrangementView` for custom fold-spanning layouts; Stiki
  uses `NavigationSplitView` (standard component, auto-adapts) plus its own
  `CreaseAwareSplit` for the glance layout.

## Testing

- Unit: `swift test` in `Packages/StikiCore`.
- Simulated poses without hardware: launch with
  `-StikiSimulatedPose fullyOpen|book|tent|seated|closed|standardPhone`.
- Xcode 27.1 Device Hub: open/close/fold the simulated iPhone Duo.
