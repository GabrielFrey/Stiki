import StikiCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Per-target readiness, auto-fix, and hand-off.
struct ExportSheet: View {
    var pack: PackSnapshot
    @Environment(\.stiki) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTarget: ExportTarget = .whatsApp
    @State private var report: ValidationReport?
    @State private var isWorking = false
    @State private var shareURLs: [URL] = []
    @State private var isSharePresented = false
    @State private var limitation: ExportLimitation?
    @State private var error: StikiError?
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ReadinessBadgeRow(
                        readinessByTarget: ExportProjection.readiness(
                            for: pack,
                            authorName: environment.settings.authorName
                        )
                    )

                    targetPicker
                    issues
                    actions
                    if let limitation {
                        GlassCard(title: LocalizedStringKey(limitation.title), systemImage: "info.circle") {
                            Text(limitation.detail)
                                .font(.subheadline)
                        }
                    }
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                selectedTarget = environment.settings.defaultExportTarget
                refreshReport()
            }
            .onChange(of: selectedTarget) { _, _ in refreshReport() }
            .sheet(isPresented: $isSharePresented) {
                ShareSheet(urls: shareURLs)
            }
            .alert(
                "Export",
                isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } }),
                presenting: error
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { item in
                Text(item.localizedDescription)
            }
            .overlay {
                if isWorking {
                    ProgressView("Preparing pack")
                        .padding()
                        .stikiGlassPanel()
                }
            }
        }
        .presentationDetents([.large])
    }

    private var targetPicker: some View {
        GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
            HStack(spacing: 8) {
                ForEach(ExportTarget.allCases) { target in
                    GlassChip(
                        title: target.displayName,
                        systemImage: target.systemImage,
                        isSelected: selectedTarget == target
                    ) {
                        selectedTarget = target
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var issues: some View {
        if let report, !report.issues.isEmpty {
            GlassCard(title: report.readiness.summary, systemImage: report.readiness.systemImage) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.issues) { issue in
                        Text(issue.englishDescription)
                            .font(.subheadline)
                    }
                }
            }
        } else {
            GlassCard(title: "Ready", systemImage: "checkmark.circle") {
                Text("This pack meets \(selectedTarget.englishName) limits.")
                    .font(.subheadline)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if report?.readiness == .fixable {
                Button("Fix automatically") { Task { await export(fixing: true) } }
                    .buttonStyle(.glassProminent)
                    .disabled(isWorking)
            }
            Button("Export to \(selectedTarget.englishName)") { Task { await export(fixing: false) } }
                .buttonStyle(.glassProminent)
                .disabled(isWorking || report?.readiness == .blocked)
            Button("Save PNG to Photos") { Task { await saveToPhotos() } }
                .buttonStyle(.glass)
            Button("Copy") { Task { await copyToClipboard() } }
                .buttonStyle(.glass)
            ShareLink(items: shareURLs) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .frame(height: GlassMetrics.controlHeight)
            }
            .buttonStyle(.glass)
            .disabled(shareURLs.isEmpty)
        }
    }

    private func refreshReport() {
        let spec = ExportProjection.projectedPack(
            pack,
            target: selectedTarget,
            authorName: environment.settings.authorName
        )
        report = ExportValidator.validate(pack: spec, target: selectedTarget)
        let notes = Task {
            await environment.exporter.limitations(
                for: selectedTarget,
                isAnimated: pack.containsAnimated
            )
        }
        Task {
            limitation = await notes.value.first
        }
    }

    private func export(fixing: Bool) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let prepared = try await environment.exporter.prepare(
                pack: pack,
                target: selectedTarget,
                sourceLoader: loader
            )
            report = prepared.report
            shareURLs = prepared.files

            if selectedTarget == .whatsApp {
                try await sendWhatsApp(prepared: prepared)
            } else if selectedTarget == .telegram {
                let zip = try await environment.exporter.telegramZip(pack: pack, prepared: prepared)
                shareURLs = [zip]
                isSharePresented = true
                if let url = URL(string: ExportTarget.telegram.handoffURLString ?? "") {
                    await UIApplication.shared.open(url)
                }
            } else {
                isSharePresented = true
            }
            _ = fixing
        } catch let error as StikiError {
            self.error = error
        } catch {
            self.error = .exportFailed(error.localizedDescription)
        }
    }

    private func sendWhatsApp(prepared: PreparedExport) async throws {
        let payload = try await environment.exporter.whatsAppPayload(
            pack: pack,
            prepared: prepared,
            publisher: environment.settings.authorName
        )
        guard let url = URL(string: ExportTarget.whatsApp.handoffURLString ?? "") else { return }
        if !UIApplication.shared.canOpenURL(url) {
            throw StikiError.messengerNotInstalled(.whatsApp)
        }
        UIPasteboard.general.setData(
            payload,
            forPasteboardType: WhatsAppPackPayload.pasteboardType
        )
        await UIApplication.shared.open(url)
        statusMessage = String(localized: "Opening WhatsApp")
    }

    private func saveToPhotos() async {
        guard let first = pack.stickers.first, let file = first.renderedFileName else { return }
        do {
            let data = try await environment.assetStore.renderedData(fileName: file)
            guard let image = UIImage(data: data) else { throw StikiError.imageDecodingFailed }
            try await saveImage(image)
            statusMessage = String(localized: "Saved to Photos")
        } catch {
            self.error = .photoLibraryAccessDenied
        }
    }

    private func copyToClipboard() async {
        guard let first = pack.stickers.first, let file = first.renderedFileName else { return }
        if let data = try? await environment.assetStore.renderedData(fileName: file),
           let image = UIImage(data: data) {
            UIPasteboard.general.image = image
            statusMessage = String(localized: "Copied")
        }
    }

    private func loader(_ sticker: StickerSnapshot) async throws -> (Data, Data?, [CGImage]?) {
        let (source, mask) = try await environment.loadSource(for: sticker)
        var frames: [CGImage]?
        if let recipe = sticker.recipe, let animation = recipe.animation {
            let video = try await environment.assetStore.assetData(recipe.source)
            frames = try await environment.animation.sampleFrames(videoData: video, spec: animation)
        }
        return (source, mask, frames)
    }

    private func saveImage(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            continuation.resume()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
