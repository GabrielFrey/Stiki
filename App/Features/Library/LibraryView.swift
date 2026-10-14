import StikiCore
import SwiftUI

/// All stickers, newest first.
struct LibraryView: View {
    @Environment(\.stiki) private var environment
    @State private var stickerPendingExport: StickerSnapshot?
    @State private var stickerPendingPack: StickerSnapshot?
    @State private var stickerPendingEdit: StickerSnapshot?
    @State private var error: StikiError?

    private let columns = [
        GridItem(.adaptive(minimum: 108, maximum: 160), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if environment.library.isLoading && !environment.library.hasContent {
                    ProgressView("Loading stickers")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !environment.library.hasContent {
                    empty
                } else {
                    grid
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        CreateView()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create sticker")
                }
                ToolbarSpacer(.fixed)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .sheet(item: $stickerPendingExport) { sticker in
            SingleStickerExportSheet(sticker: sticker)
        }
        .sheet(item: $stickerPendingPack) { sticker in
            AddToPackSheet(sticker: sticker)
        }
        .sheet(item: $stickerPendingEdit) { sticker in
            EditorSheet(sticker: sticker)
        }
        .alert(
            "Library",
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            ),
            presenting: error
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { item in
            Text(item.localizedDescription)
        }
    }

    private var empty: some View {
        GlassEmptyState(
            systemImage: "sparkles",
            title: "No stickers yet",
            message: "Pick a photo. Stiki lifts the subject on your device and keeps the original so you can edit it later, even inside a pack."
        ) {
            NavigationLink {
                CreateView()
            } label: {
                Label("Create a sticker", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: GlassMetrics.controlHeight)
            }
            .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(environment.library.stickers) { sticker in
                    StickerGridItem(sticker: sticker, environment: environment)
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") {
                                stickerPendingEdit = sticker
                            }
                            Button("Duplicate", systemImage: "plus.square.on.square") {
                                Task { try? await environment.library.duplicateSticker(id: sticker.id) }
                            }
                            Button("Add to pack", systemImage: "tray.and.arrow.down") {
                                stickerPendingPack = sticker
                            }
                            Button("Export", systemImage: "square.and.arrow.up") {
                                stickerPendingExport = sticker
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task {
                                    do {
                                        try await environment.library.deleteSticker(id: sticker.id)
                                    } catch {
                                        self.error = .renderFailed(error.localizedDescription)
                                    }
                                }
                            }
                        }
                }
            }
            .padding(16)
        }
    }
}

struct StickerGridItem: View {
    var sticker: StickerSnapshot
    var environment: AppEnvironment

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CheckerboardBackdrop(squareSize: 8)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                ProgressView()
            }
            if sticker.isAnimated {
                Image(systemName: "play.fill")
                    .font(.caption2.bold())
                    .padding(6)
                    .stikiGlass(in: Circle())
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: GlassMetrics.thumbnailCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GlassMetrics.thumbnailCornerRadius, style: .continuous)
                .stroke(.separator.opacity(0.4), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sticker.accessibilityDescription)
        .task {
            guard let file = sticker.renderedFileName else { return }
            if let data = try? await environment.assetStore.renderedData(fileName: file) {
                image = UIImage(data: data)
            }
        }
    }
}

#Preview {
    LibraryView()
        .environment(\.stiki, .preview())
}
