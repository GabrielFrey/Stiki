import StoreKit
import SwiftUI

/// Honest paywall. No fake trial, no weekly plan, no countdown.
struct PaywallView: View {
    @Environment(\.stiki) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var error: StikiError?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    features
                    products
                    finePrint
                }
                .padding(24)
            }
            .navigationTitle("Stiki Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Restore purchases") {
                        Task { await restore() }
                    }
                }
            }
            .alert(
                "Purchase",
                isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } }),
                presenting: error
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { item in
                Text(item.localizedDescription)
            }
            .overlay {
                if environment.purchases.isBusy {
                    ProgressView()
                        .padding()
                        .stikiGlassPanel()
                }
            }
        }
        .presentationDetents([.large])
        .task { await environment.purchases.refresh() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.tint)
            Text("Pay once, or once a year. Never once a week.")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("The free plan already includes unlimited static stickers, three packs, every export, and no watermark. Pro unlocks the rest.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 10) {
            feature("tray.full", "Unlimited packs")
            feature("play.circle", "Animated stickers from Live Photos and video")
            feature("circle.dashed", "Glow and puffy outlines, comic, posterize, glossy")
            feature("icloud", "Optional iCloud sync")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stikiGlassPanel()
    }

    private func feature(_ image: String, _ title: LocalizedStringKey) -> some View {
        Label(title, systemImage: image)
            .font(.body.weight(.medium))
    }

    private var products: some View {
        VStack(spacing: 12) {
            if environment.purchases.products.isEmpty {
                Text("Products are unavailable. Try Restore, or check the StoreKit configuration when running in the simulator.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            ForEach(environment.purchases.products, id: \.id) { product in
                Button {
                    Task { await buy(product) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.headline)
                        Text(product.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(product.displayPrice)
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .modifier(PaywallProductStyle(isProminent: product.id == StikiProductID.lifetime.rawValue))
                .accessibilityHint("Starts a real App Store purchase. There is no free trial.")
            }
        }
    }

    private var finePrint: some View {
        Text("No ads, no account, no weekly plan. Purchases are handled by Apple. Family Sharing is on.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private func buy(_ product: Product) async {
        do {
            try await environment.purchases.purchase(product)
            if environment.isPro { dismiss() }
        } catch let error as StikiError {
            if !error.isSilent { self.error = error }
        } catch {
            self.error = .purchaseFailed(error.localizedDescription)
        }
    }

    private func restore() async {
        do {
            try await environment.purchases.restore()
            if environment.isPro { dismiss() }
        } catch let error as StikiError {
            if !error.isSilent { self.error = error }
        } catch {
            self.error = .purchaseFailed(error.localizedDescription)
        }
    }
}

private struct PaywallProductStyle: ViewModifier {
    var isProminent: Bool

    func body(content: Content) -> some View {
        if isProminent {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.glass)
        }
    }
}

#Preview {
    PaywallView()
        .environment(\.stiki, .preview())
}
