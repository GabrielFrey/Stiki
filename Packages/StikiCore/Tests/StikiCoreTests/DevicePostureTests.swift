import Testing
@testable import StikiCore

@Suite struct DevicePostureTests {
    let crease = CGRectCodable(x: 395, y: 0, width: 10, height: 600)

    @Test func noHingeIsStandardPhone() {
        let p = PostureResolver.resolve(hasHinge: false, status: .fullyOpen, angleDegrees: nil,
                                        isInnerDisplay: false, crease: nil, creaseIsActive: false)
        #expect(p == .standardPhone)
        #expect(!p.prefersDualPane)
        #expect(!p.prefersGlanceable)
    }

    @Test func closedUsesOuterCover() {
        let p = PostureResolver.resolve(hasHinge: true, status: .closed, angleDegrees: 0,
                                        isInnerDisplay: false, crease: nil, creaseIsActive: false)
        #expect(p.pose == .closed)
        #expect(p.surface == .outerCover)
    }

    @Test func fullyOpenInnerPrefersDualPane() {
        let p = PostureResolver.resolve(hasHinge: true, status: .fullyOpen, angleDegrees: 180,
                                        isInnerDisplay: true, crease: crease, creaseIsActive: false)
        #expect(p.pose == .fullyOpen)
        #expect(p.prefersDualPane)
        #expect(!p.creaseIsActive)
    }

    @Test func unknownTreatedAsFullyOpen() {
        let p = PostureResolver.resolve(hasHinge: true, status: .unknown, angleDegrees: nil,
                                        isInnerDisplay: true, crease: nil, creaseIsActive: false)
        #expect(p.pose == .fullyOpen)
    }

    @Test func partialPoses() {
        func r(_ along: Bool?, _ flat: Bool?) -> HingePose {
            PostureResolver.resolve(hasHinge: true, status: .partiallyOpen, angleDegrees: 100,
                                    isInnerDisplay: true, crease: crease, creaseIsActive: true,
                                    gravityDownAlongFold: along, lowerHalfIsFlat: flat).pose
        }
        #expect(r(true, nil) == .book)
        #expect(r(nil, nil) == .book)
        #expect(r(false, false) == .tent)
        #expect(r(false, true) == .seated)
        #expect(HingePose.tent.isHandsFree && HingePose.seated.isHandsFree)
        #expect(!HingePose.book.isHandsFree)
    }

    @Test func panesSplitAroundVerticalCrease() {
        let panes = CreaseLayout.panes(containerWidth: 800, containerHeight: 600, crease: crease)
        #expect(panes.count == 2)
        #expect(panes[0].width == 395)
        #expect(panes[1].x == 405 && panes[1].width == 395)
    }

    @Test func panesWithoutCreaseIsFull() {
        let panes = CreaseLayout.panes(containerWidth: 800, containerHeight: 600, crease: nil)
        #expect(panes == [CGRectCodable(x: 0, y: 0, width: 800, height: 600)])
    }

    @Test func horizontalCreaseSplitsTopBottom() {
        let h = CGRectCodable(x: 0, y: 295, width: 800, height: 10)
        let panes = CreaseLayout.panes(containerWidth: 800, containerHeight: 600, crease: h)
        #expect(panes.count == 2 && panes[0].height == 295 && panes[1].y == 305)
    }

    @Test func nudgesControlOffCrease() {
        let button = CGRectCodable(x: 380, y: 500, width: 44, height: 44)
        #expect(CreaseLayout.intersectsCrease(button, crease: crease))
        let moved = CreaseLayout.nudgedOffCrease(button, crease: crease)
        #expect(!CreaseLayout.intersectsCrease(moved, crease: crease))
        let far = CGRectCodable(x: 10, y: 10, width: 44, height: 44)
        #expect(CreaseLayout.nudgedOffCrease(far, crease: crease) == far)
    }
}
