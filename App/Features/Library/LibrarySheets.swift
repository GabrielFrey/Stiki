import StikiCore
import SwiftUI

/// Reopens a sticker in the full editor, which is how non-destructive editing
/// reaches stickers that already live in packs.
struct EditorSheet: View {
    var sticker: StickerSnapshot
    @Environment(\.stiki) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: CreateViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    if model.step == .editor {
                        EditorView(model: model)
                    } else if model.step == .cutout {
                        CutoutView(model: model)
                    } else {
                        ProgressView()
                    }
                } else {
                    ProgressView("Opening sticker")
                }
            }
        }
        .task {
            let viewModel = CreateViewModel(environment: environment)
            await viewModel.reopen(sticker)
            model = viewModel
        }
        .onChange(of: model?.step) { _, step in
            if step == .importSource { dismiss() }
        }
    }
}

struct AddToPackSheet: View {
    var sticker: StickerSnapshot
    @Environment(\.stiki) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var newPackName = ""
    @State private var error: StikiError?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                if environment.library.packs.isEmpty {
                    Text("You have no packs yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(environment.library.packsNotContaining(stickerID: sticker.id)) { pack in
                    Button(pack.name) {
                        do {
                            try environment.library.addSticker(sticker.id, toPack: pack.id)
                            dismiss()
                        } catch let error as StikiError {
                            self.error = error
                        } catch {
                            self.error = .renderFailed(error.localizedDescription)
                        }
                    }
                }
                Section("New pack") {
                    TextField("Pack name", text: $newPackName)
                    Button("Create pack and add") {
                        addToNewPack()
                    }
                    .disabled(newPackName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Add to pack")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert(
                "Pack",
                isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } }),
                presenting: error
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { item in
                Text(item.localizedDescription)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addToNewPack() {
        do {
            let id = try environment.library.createPack(
                name: newPackName.trimmingCharacters(in: .whitespaces),
                isPro: environment.isPro
            )
            try environment.library.addSticker(sticker.id, toPack: id)
            dismiss()
        } catch StikiError.packLimitReached {
            showPaywall = true
        } catch let error as StikiError {
            self.error = error
        } catch {
            self.error = .renderFailed(error.localizedDescription)
        }
    }
}

struct SingleStickerExportSheet: View {
    var sticker: StickerSnapshot

    var body: some View {
        ExportSheet(pack: PackSnapshot(
            id: sticker.id,
            name: sticker.accessibilityDescription,
            sortIndex: 0,
            trayIconFileName: nil,
            trayIconByteCount: 0,
            trayStickerID: nil,
            updatedAt: sticker.updatedAt,
            stickers: [sticker]
        ))
    }
}
