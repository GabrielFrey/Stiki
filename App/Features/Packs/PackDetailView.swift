import StikiCore
import SwiftUI

struct PackDetailView: View {
    var packID: UUID
    @Environment(\.stiki) private var environment
    @State private var showExport = false
    @State private var renaming = false
    @State private var draftName = ""
    @State private var showPaywall = false

    private var pack: PackSnapshot? { environment.library.pack(id: packID) }

    var body: some View {
        Group {
            if let pack {
                content(pack)
            } else {
                ContentUnavailableView("Pack deleted", systemImage: "tray")
            }
        }
    }

    private func content(_ pack: PackSnapshot) -> some View {
        List {
            Section {
                ReadinessBadgeRow(
                    readinessByTarget: ExportProjection.readiness(
                        for: pack,
                        authorName: environment.settings.authorName
                    )
                )
                .listRowBackground(Color.clear)
            }

            Section("Stickers") {
                if pack.stickers.isEmpty {
                    Text("This pack is empty. Add stickers from the library.")
                        .foregroundStyle(.secondary)
                }
                ForEach(pack.stickers) { sticker in
                    HStack {
                        Text(sticker.accessibilityDescription)
                        Spacer()
                        Text(sticker.emojiTags.joined())
                    }
                    .accessibilityLabel(sticker.accessibilityDescription)
                }
                .onMove { source, destination in
                    try? environment.library.moveStickers(
                        inPack: pack.id,
                        fromOffsets: source,
                        toOffset: destination
                    )
                }
                .onDelete { offsets in
                    for index in offsets {
                        let id = pack.stickers[index].id
                        try? environment.library.removeSticker(id, fromPack: pack.id)
                    }
                }
            }
        }
        .navigationTitle(pack.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export", systemImage: "square.and.arrow.up") { showExport = true }
                    .buttonStyle(.glassProminent)
            }
            ToolbarSpacer(.fixed)
            ToolbarItem(placement: .secondaryAction) {
                Button("Rename", systemImage: "pencil") {
                    draftName = pack.name
                    renaming = true
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Duplicate", systemImage: "plus.square.on.square") {
                    duplicate(pack)
                }
            }
        }
        .sheet(isPresented: $showExport) { ExportSheet(pack: pack) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Rename pack", isPresented: $renaming) {
            TextField("Name", text: $draftName)
            Button("Save") {
                try? environment.library.renamePack(
                    id: pack.id,
                    to: draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func duplicate(_ pack: PackSnapshot) {
        do {
            _ = try environment.library.duplicatePack(id: pack.id, isPro: environment.isPro)
        } catch StikiError.packLimitReached {
            showPaywall = true
        } catch {
            // persist() already surfaces library errors
        }
    }
}
