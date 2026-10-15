import StoreKit
import SwiftUI

/// Honest paywall. No fake trial, no weekly plan, no countdown.
///
/// Auto-renewable subscription copy follows Apple's published sign-up
/// requirements (name, duration, content, full renewal price, restore) plus
/// Privacy Policy and Terms of Use links required in the binary by
/// Guideline 3.1.2.
struct PaywallView: View {
    @Environment(\.stiki) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var error: StikiError?
    @State private var showManageSubscriptions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    features
                    products
                    subscriptionTerms
                    legalLinks
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
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
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
                        if product.id == StikiProductID.yearly.rawValue {
                            Text("Billed \(product.displayPrice) once a year. Auto-renews until you cancel.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .modifier(PaywallProductStyle(isProminent: product.id == StikiProductID.lifetime.rawValue))
                .accessibilityHint("Starts a real App Store purchase. There is no free trial.")
            }
        }
    }

    private var subscriptionTerms: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stiki Pro — Yearly")
                .font(.subheadline.weight(.semibold))
            Text("Auto-renewable subscription. Length: 1 year. Price: the yearly button above shows the amount billed in your storefront currency. Payment is charged to your Apple ID at confirmation. The subscription renews automatically unless you turn off auto-renew at least 24 hours before the end of the current period. Your account is charged for renewal within 24 hours prior to the end of the current period. Manage or cancel in Settings → Apple ID → Subscriptions, or tap Manage subscription below.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Manage subscription") {
                showManageSubscriptions = true
            }
            .buttonStyle(.glass)
            .accessibilityHint("Opens Apple's subscription management sheet")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .stikiGlassPanel()
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            if let privacy = LegalLinks.privacy {
                Link("Privacy Policy", destination: privacy)
            }
            if let terms = LegalLinks.terms {
                Link("Terms of Use", destination: terms)
            }
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var finePrint: some View {
        Text("No ads, no account, no weekly plan. Purchases are handled by Apple. Family Sharing is on. Restore purchases if you already bought Pro on this Apple ID.")
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
