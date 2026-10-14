import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The Create tab's first step: pick a photo, Live Photo, video, camera
/// capture, a file, or the clipboard.
struct ImportView: View {
    @Bindable var model: CreateViewModel
    @Environment(\.stiki) private var environment

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isCameraPresented = false
    @State private var isFileImporterPresented = false
    @State private var cameraError: StikiError?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
                    VStack(spacing: 12) {
                        photosPickerButton
                        cameraButton
                        pasteButton
                        filesButton
                    }
                }
                .padding(.horizontal, 20)

                if model.isImporting {
                    ProgressView("Preparing photo")
                        .padding()
                        .stikiGlassPanel()
                }

                if let error = model.error ?? cameraError, !error.isSilent {
                    errorCard(error)
                }
            }
            .padding(.vertical, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Create")
        .onChange(of: photoItems) { _, items in
            Task { await load(items: items) }
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraPicker { data in
                Task { await model.importStill(data) }
            } onCancel: {
                isCameraPresented = false
            } onDenied: {
                cameraError = .cameraAccessDenied
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .movie, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            Task { await loadFile(result) }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Make a sticker")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Pick a photo and Stiki lifts the subject on your device. Nothing is uploaded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private var photosPickerButton: some View {
        PhotosPicker(
            selection: $photoItems,
            maxSelectionCount: 1,
            matching: .any(of: [.images, .livePhotos, .videos])
        ) {
            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: GlassMetrics.controlHeight)
        }
        .buttonStyle(.glassProminent)
        .accessibilityHint("Opens your photo library")
    }

    private var cameraButton: some View {
        Button {
            isCameraPresented = true
        } label: {
            Label("Take a photo", systemImage: "camera.fill")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: GlassMetrics.controlHeight)
        }
        .buttonStyle(.glass)
        .accessibilityHint("Opens the camera")
    }

    private var pasteButton: some View {
        Button {
            Task { await paste() }
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: GlassMetrics.controlHeight)
        }
        .buttonStyle(.glass)
        .accessibilityHint("Uses the image currently on the clipboard")
    }

    private var filesButton: some View {
        Button {
            isFileImporterPresented = true
        } label: {
            Label("Choose a file", systemImage: "folder")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: GlassMetrics.controlHeight)
        }
        .buttonStyle(.glass)
        .accessibilityHint("Opens the Files picker")
    }

    private func errorCard(_ error: StikiError) -> some View {
        GlassCard(title: "Could not import", systemImage: "exclamationmark.triangle", footnote: LocalizedStringKey(error.recoverySuggestion ?? "")) {
            Text(error.localizedDescription)
                .font(.subheadline)
        }
        .padding(.horizontal, 20)
    }

    private func load(items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        defer { photoItems = [] }
        if let movie = try? await item.loadTransferable(type: MovieTransferable.self) {
            await model.importVideo(movie.data)
            return
        }
        if let image = try? await item.loadTransferable(type: Data.self) {
            await model.importStill(image)
            return
        }
        model.error = .imageDecodingFailed
    }

    private func loadFile(_ result: Result<[URL], Error>) async {
        switch result {
        case let .failure(error):
            model.error = .exportFailed(error.localizedDescription)
        case let .success(urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                model.error = .imageDecodingFailed
                return
            }
            if url.pathExtension.lowercased() == "mov"
                || url.pathExtension.lowercased() == "mp4"
                || url.pathExtension.lowercased() == "m4v" {
                await model.importVideo(data)
            } else {
                await model.importStill(data)
            }
        }
    }

    private func paste() async {
        let pasteboard = UIPasteboard.general
        if let data = pasteboard.data(forPasteboardType: UTType.png.identifier)
            ?? pasteboard.data(forPasteboardType: UTType.jpeg.identifier)
            ?? pasteboard.image.flatMap({ $0.pngData() }) {
            await model.importStill(data)
        } else {
            model.error = .imageDecodingFailed
        }
    }
}

/// Video bytes from a `PhotosPickerItem`.
struct MovieTransferable: Transferable {
    var data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .movie) { data in
            MovieTransferable(data: data)
        }
        DataRepresentation(importedContentType: .mpeg4Movie) { data in
            MovieTransferable(data: data)
        }
        DataRepresentation(importedContentType: .quickTimeMovie) { data in
            MovieTransferable(data: data)
        }
    }
}

#Preview {
    NavigationStack {
        ImportView(model: CreateViewModel(environment: .preview()))
    }
    .environment(\.stiki, .preview())
}
