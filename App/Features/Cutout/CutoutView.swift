import StikiCore
import SwiftUI

/// Multi-subject selection plus brush refinement.
struct CutoutView: View {
    @Bindable var model: CreateViewModel
    @State private var brushMode: BrushStroke.Mode = .add
    @State private var brushRadius = MaskRefinement.defaultRelativeRadius
    @State private var feather: Double = 0
    @State private var pendingPoints: [UnitPoint2D] = []
    @State private var isBrushing = false

    var body: some View {
        VStack(spacing: 0) {
            canvas
            inspector
        }
        .navigationTitle("Cut out")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { model.reset() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") { model.goToEditor() }
                    .buttonStyle(.glassProminent)
                    .disabled(model.session?.recipe.mask == nil && model.session?.isBusy == true)
            }
            ToolbarSpacer(.fixed)
        }
        .overlay {
            if model.session?.isBusy == true {
                ProgressView("Finding subjects")
                    .padding()
                    .stikiGlassPanel()
            }
        }
    }

    private var canvas: some View {
        GeometryReader { geometry in
            ZStack {
                CheckerboardBackdrop()
                if let data = model.session?.sourcePreview, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            instanceOverlays(in: geometry.size, imageSize: image.size)
                        }
                        .gesture(brushGesture(in: geometry.size))
                }
            }
        }
        .accessibilityLabel("Photo canvas")
        .accessibilityHint("Tap a glowing subject to keep it. Drag to refine the mask with the brush.")
    }

    @ViewBuilder
    private func instanceOverlays(in size: CGSize, imageSize: CGSize) -> some View {
        if let instances = model.session?.analysis?.instances {
            ForEach(instances) { instance in
                let selected = model.session?.selectedInstances.contains(instance.id) == true
                if let mask = UIImage(data: instance.previewMaskPNG) {
                    Button {
                        Task { await model.toggleInstance(instance.id) }
                    } label: {
                        Image(uiImage: mask)
                            .resizable()
                            .scaledToFit()
                            .colorMultiply(selected ? .green : .cyan)
                            .opacity(selected ? 0.45 : 0.25)
                            .shadow(color: selected ? .green : .cyan, radius: selected ? 12 : 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Subject \(instance.id)")
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                    .accessibilityHint("Toggles whether this subject stays in the sticker")
                }
            }
        }
    }

    private var inspector: some View {
        GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Subjects")
                    .font(.headline)

                if model.session?.analysis?.instances.isEmpty == true {
                    Text("No separate subjects found. You can keep the whole image, or paint the mask yourself.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    GlassChip(
                        title: "Keep whole image",
                        systemImage: "rectangle.dashed",
                        isSelected: model.session?.recipe.background == .originalImage
                    ) {
                        Task { await model.keepWholeImage() }
                    }
                    GlassChip(
                        title: "Add",
                        systemImage: "plus.circle",
                        isSelected: brushMode == .add
                    ) { brushMode = .add }
                    GlassChip(
                        title: "Erase",
                        systemImage: "minus.circle",
                        isSelected: brushMode == .erase
                    ) { brushMode = .erase }
                }

                GlassInspectorRow(title: "Brush", systemImage: "paintbrush.pointed") {
                    Slider(value: $brushRadius, in: MaskRefinement.relativeRadiusRange)
                        .accessibilityLabel("Brush size")
                }
                GlassInspectorRow(title: "Feather", systemImage: "aqi.medium") {
                    Slider(value: $feather, in: MaskRefinement.featherRange)
                        .accessibilityLabel("Edge feather")
                        .onChange(of: feather) { _, value in
                            Task { await model.applyBrush(strokes: [], feather: value) }
                        }
                }

                if let error = model.session?.error {
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(18)
            .stikiGlassPanel()
            .padding()
        }
    }

    private func brushGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isBrushing = true
                pendingPoints.append(
                    UnitPoint2D(
                        x: value.location.x / max(size.width, 1),
                        y: value.location.y / max(size.height, 1)
                    ).clampedToUnitSquare()
                )
            }
            .onEnded { _ in
                let points = pendingPoints
                pendingPoints = []
                isBrushing = false
                Task {
                    await model.applyBrush(
                        strokes: [BrushStroke(points: points, relativeRadius: brushRadius, mode: brushMode)],
                        feather: feather
                    )
                }
            }
    }
}

#Preview {
    NavigationStack {
        CutoutView(model: CreateViewModel(environment: .preview()))
    }
}
