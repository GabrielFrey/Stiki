import StikiCore
import SwiftUI

/// Full-bleed canvas with a morphing glass palette and a context inspector.
struct EditorView: View {
    @Bindable var model: CreateViewModel
    @Environment(\.stiki) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.undoManager) private var undoManager

    @State private var isPaletteExpanded = false
    @State private var selectedTool: EditorTool?
    @State private var stickerName = ""
    @State private var emojiTags: [String] = ["😀"]
    @State private var previewImage: UIImage?
    @State private var isSaving = false
    @State private var showPaywall = false

    var body: some View {
        ZStack(alignment: .bottom) {
            EditorBackdrop(image: previewImage.map { Image(uiImage: $0) })
            canvas
            VStack(spacing: 12) {
                if let selectedTool {
                    inspector(for: selectedTool)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                palette
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 18)
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { model.step = .cutout }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .buttonStyle(.glassProminent)
                    .disabled(isSaving)
            }
            ToolbarSpacer(.flexible)
        }
        .task { await refreshPreview() }
        .onChange(of: model.session?.recipe) { _, _ in
            Task { await refreshPreview() }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .overlay {
            if isSaving {
                ProgressView("Saving sticker")
                    .padding()
                    .stikiGlassPanel()
            }
        }
        .alert(
            "Could not save",
            isPresented: Binding(
                get: { model.error != nil && !(model.error?.isSilent ?? true) },
                set: { if !$0 { model.error = nil } }
            ),
            presenting: model.error
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private var canvas: some View {
        Group {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .gesture(transformGesture)
                    .accessibilityLabel("Sticker preview")
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var palette: some View {
        GlassToolPalette(
            isExpanded: $isPaletteExpanded,
            tools: EditorTool.allCases.map(\.glassTool),
            selectedToolID: selectedTool?.rawValue
        ) { tool in
            guard let editorTool = EditorTool(rawValue: tool.id) else { return }
            if editorTool.requiresPro && !environment.isPro {
                showPaywall = true
                return
            }
            withAnimation(.stikiPanel(reduceMotion: reduceMotion)) {
                selectedTool = selectedTool == editorTool ? nil : editorTool
            }
        }
    }

    @ViewBuilder
    private func inspector(for tool: EditorTool) -> some View {
        GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
            Group {
                switch tool {
                case .cutout:
                    CutoutInspector(model: model)
                case .outline:
                    OutlineInspector(recipe: recipeBinding)
                case .text:
                    TextInspector(recipe: recipeBinding)
                case .emoji:
                    EmojiInspector(recipe: recipeBinding)
                case .filters:
                    FilterInspector(recipe: recipeBinding, isPro: environment.isPro) {
                        showPaywall = true
                    }
                case .animate:
                    AnimateInspector(model: model, isPro: environment.isPro) {
                        showPaywall = true
                    }
                }
            }
            .padding(16)
            .stikiGlassPanel()
        }
    }

    private var recipeBinding: Binding<EditRecipe> {
        Binding(
            get: { model.session?.recipe ?? EditRecipe(source: AssetRef(fileName: "", kind: .image, pixelSize: .square(1))) },
            set: { newValue in
                registerUndo()
                model.session?.recipe = newValue
            }
        )
    }

    private var transformGesture: some Gesture {
        MagnifyGesture()
            .simultaneously(with: RotateGesture())
            .onChanged { value in
                guard var session = model.session else { return }
                let magnify = value.first?.magnification ?? 1
                let rotation = value.second?.rotation.radians ?? 0
                session.recipe.transform.scale = session.recipe.transform.sanitizedScale * (magnify == 0 ? 1 : 1)
                session.recipe.transform.rotation += rotation == 0 ? 0 : 0
                model.session = session
            }
            .onEnded { value in
                guard var session = model.session else { return }
                registerUndo()
                let magnify = value.first?.magnification ?? 1
                session.recipe.transform.scale = min(max(session.recipe.transform.scale * magnify, 0.05), 8)
                if let rotation = value.second?.rotation.radians {
                    session.recipe.transform.rotation += rotation
                }
                model.session = session
            }
    }

    private func registerUndo() {
        guard let current = model.session?.recipe else { return }
        undoManager?.registerUndo(withTarget: model) { target in
            target.session?.recipe = current
        }
    }

    private func refreshPreview() async {
        guard let session = model.session else { return }
        do {
            let source = try ImageCoding.decode(data: session.sourcePreview)
            let mask: CGImage?
            if let ref = session.recipe.mask {
                mask = try ImageCoding.decode(data: try await environment.assetStore.assetData(ref))
            } else {
                mask = nil
            }
            let image = try await environment.renderer.render(
                recipe: session.recipe,
                source: source,
                mask: mask,
                canvas: PixelSize.square(512)
            )
            previewImage = UIImage(cgImage: image)
        } catch {
            // Keep the last good preview rather than blanking the canvas.
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        _ = await model.save(name: stickerName, emojiTags: emojiTags)
    }
}

#Preview {
    NavigationStack {
        EditorView(model: CreateViewModel(environment: .preview()))
    }
    .environment(\.stiki, .preview())
}
