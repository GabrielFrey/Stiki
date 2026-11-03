import StikiCore
import SwiftUI
import UIKit

/// Hands-free, StandBy-style surface for tent and seated poses.
///
/// - Tent: the whole visible half is a slow, large sticker carousel that can
///   be read from across a table; one big tap target opens Create.
/// - Seated (Flex): the upright half shows the carousel, the flat half keeps
///   touch controls, split by `CreaseAwareSplit` so nothing sits on the fold.
struct GlanceRootView: View {
    @Environment(\.stiki) private var environment
    @Environment(\.devicePresentation) private var presentation
    @Binding var selection: AppTab
    @State private var index = 0
    @State private var showFullApp = false

    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        let stickers = environment.library.stickers
        Group {
            if presentation.pose == .seated {
                CreaseAwareSplit {
                    carousel(stickers)
                } trailing: {
                    controls.padding()
                }
            } else {
                carousel(stickers)
                    .overlay(alignment: .bottom) { controls.padding(.bottom, 32) }
            }
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .onReceive(timer) { _ in
            guard !stickers.isEmpty, !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.smooth(duration: 0.8)) { index = (index + 1) % stickers.count }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .fullScreenCover(isPresented: $showFullApp) {
            NavigationStack {
                detail
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done", systemImage: "xmark") { showFullApp = false }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func carousel(_ stickers: [StickerSnapshot]) -> some View {
        if stickers.isEmpty {
            ContentUnavailableView(
                "No stickers yet",
                systemImage: "face.smiling",
                description: Text("Open Stiki flat to create your first sticker.")
            )
            .font(.title)
        } else {
            let sticker = stickers[index % stickers.count]
            VStack(spacing: 16) {
                GlanceStickerImage(sticker: sticker)
                    .id(sticker.id)
                    .transition(.blurReplace)
                Text(sticker.name)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private var controls: some View {
        HStack(spacing: 20) {
            glanceButton("Create", systemImage: "plus.circle.fill", tab: .create)
            glanceButton("Packs", systemImage: "tray.full.fill", tab: .packs)
        }
    }

    private func glanceButton(_ title: LocalizedStringKey, systemImage: String, tab: AppTab) -> some View {
        Button {
            selection = tab
            showFullApp = true
        } label: {
            Label(title, systemImage: systemImage)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .frame(minHeight: 64)
        }
        .buttonStyle(.glass)
        .accessibilityIdentifier("glance.\(tab)")
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .library: LibraryView()
        case .create: CreateView()
        case .packs: PacksView()
        case .settings: SettingsView()
        }
    }
}

private struct GlanceStickerImage: View {
    @Environment(\.stiki) private var environment
    let sticker: StickerSnapshot
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .frame(maxWidth: 420, maxHeight: 420)
        .task(id: sticker.id) {
            guard let file = sticker.renderedFileName,
                  let data = try? await environment.assetStore.renderedData(fileName: file) else { return }
            image = UIImage(data: data)
        }
    }
}

#Preview("Tent") {
    GlanceRootView(selection: .constant(.library))
        .environment(\.stiki, .preview())
        .environment(\.devicePresentation, DevicePresentation(pose: .tent, surface: .inner, creaseIsActive: true))
}
