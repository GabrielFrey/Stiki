import StikiCore
import SwiftUI

/// Lays two children out on either side of an active crease, or as a normal
/// stack when there is none. Use it for any custom two-part layout so no
/// primary control straddles the fold.
struct CreaseAwareSplit<Leading: View, Trailing: View>: View {
    @Environment(\.devicePresentation) private var presentation
    var leading: Leading
    var trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        GeometryReader { proxy in
            let crease = presentation.creaseIsActive ? presentation.crease : nil
            let panes = CreaseLayout.panes(
                containerWidth: proxy.size.width,
                containerHeight: proxy.size.height,
                crease: crease ?? fallbackCrease(in: proxy.size)
            )
            if panes.count == 2 {
                ZStack(alignment: .topLeading) {
                    leading
                        .frame(width: panes[0].width, height: panes[0].height)
                        .offset(x: panes[0].x, y: panes[0].y)
                    trailing
                        .frame(width: panes[1].width, height: panes[1].height)
                        .offset(x: panes[1].x, y: panes[1].y)
                }
            } else {
                VStack(spacing: 0) { leading; trailing }
            }
        }
    }

    /// When a pose implies a crease but the SDK did not report a frame
    /// (simulated pose / older SDK), assume a centred hairline fold.
    private func fallbackCrease(in size: CGSize) -> CGRectCodable? {
        guard presentation.pose.hasActiveCrease else { return nil }
        let gutter = 24.0
        if presentation.pose == .book {
            return CGRectCodable(x: size.width / 2 - gutter / 2, y: 0, width: gutter, height: size.height)
        }
        return CGRectCodable(x: 0, y: size.height / 2 - gutter / 2, width: size.width, height: gutter)
    }
}

extension View {
    /// Adds padding on the side facing an active crease so edge controls of
    /// a pane never sit on the fold.
    func creaseSafePadding(_ edges: Edge.Set, amount: CGFloat = 12) -> some View {
        modifier(CreaseSafePadding(edges: edges, amount: amount))
    }
}

private struct CreaseSafePadding: ViewModifier {
    @Environment(\.devicePresentation) private var presentation
    let edges: Edge.Set
    let amount: CGFloat
    func body(content: Content) -> some View {
        content.padding(edges, presentation.creaseIsActive ? amount : 0)
    }
}
