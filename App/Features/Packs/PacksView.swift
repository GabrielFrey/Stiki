import StikiCore
import SwiftUI

struct PacksView: View {
    @Environment(\.stiki) private var environment
    @State private var newPackName = ""
    @State private var isCreating = false
    @State private var showPaywall = false
    @State private var error: StikiError?

    var body: some View {
        NavigationStack {
            Group {
                if environment.library.packs.isEmpty {
                    GlassEmptyState(
                        systemImage: "tray",
                        title: "No packs yet",
                        message: "A pack is a set of stickers you send together. One pack exports to iMessage, WhatsApp and Telegram."
                    ) {
                        Button("New pack") { isCreating = true }
                            .buttonStyle(.glassProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(environment.library.packs) { pack in
                            NavigationLink {
                                PackDetailView(packID: pack.id)
                            } label: {
                                PackRow(pack: pack)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", role: .destructive) {
                                    Task { try? await environment.library.deletePack(id: pack.id) }
                                }
                            }
                        }
                        .onMove { source, destination in
                            try? environment.library.reorderPacks(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                }
            }
            .navigationTitle("Packs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New pack", systemImage: "plus") { isCreating = true }
                }
                ToolbarSpacer(.fixed)
            }
            .alert("New pack", isPresented: $isCreating) {
                TextField("Name", text: $newPackName)
                Button("Create") { create() }
                Button("Cancel", role: .cancel) { newPackName = "" }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert(
                "Packs",
                isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } }),
                presenting: error
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { item in
                Text(item.localizedDescription)
            }
        }
    }

    private func create() {
        let name = newPackName.trimmingCharacters(in: .whitespacesAndNewlines)
        newPackName = ""
        guard !name.isEmpty else { return }
        do {
            _ = try environment.library.createPack(name: name, isPro: environment.isPro)
        } catch StikiError.packLimitReached {
            showPaywall = true
        } catch let error as StikiError {
            self.error = error
        } catch {
            self.error = .renderFailed(error.localizedDescription)
        }
    }
}

struct PackRow: View {
    var pack: PackSnapshot
    @Environment(\.stiki) private var environment

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.name)
                    .font(.headline)
                Text("\(pack.stickers.count) stickers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ReadinessBadgeRow(
                readinessByTarget: ExportProjection.readiness(
                    for: pack,
                    authorName: environment.settings.authorName
                ),
                isCompact: true
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pack.name), \(pack.stickers.count) stickers")
    }
}

#Preview {
    PacksView()
        .environment(\.stiki, .preview())
}
