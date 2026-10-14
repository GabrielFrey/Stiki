import SwiftUI

/// The transparency checkerboard drawn behind the editor canvas.
///
/// Drawn with `Canvas` rather than a tiled image asset so it stays crisp at
/// every scale and adapts to light and dark appearance.
struct CheckerboardBackdrop: View {
    var squareSize: CGFloat = 12

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let columns = Int((size.width / squareSize).rounded(.up))
            let rows = Int((size.height / squareSize).rounded(.up))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(lightSquare))
            for row in 0..<max(rows, 1) {
                for column in 0..<max(columns, 1) where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(darkSquare))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var lightSquare: Color {
        colorScheme == .dark ? Color(white: 0.16) : Color(white: 0.94)
    }

    private var darkSquare: Color {
        colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.86)
    }
}

/// The full-bleed editor backdrop: a blurred, over-scaled copy of the source
/// image behind the transparency checkerboard, so the glass panels have
/// something interesting to refract.
struct EditorBackdrop: View {
    var image: Image?

    var body: some View {
        ZStack {
            CheckerboardBackdrop()
            if let image {
                image
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 48, opaque: false)
                    .opacity(0.55)
                    .overlay(.background.opacity(0.1))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview("Backdrop") {
    EditorBackdrop(image: nil)
}
