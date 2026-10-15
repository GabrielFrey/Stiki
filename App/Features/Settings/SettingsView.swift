import StikiCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.stiki) private var environment
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var showPaywall = false
    @State private var error: StikiError?
    @State private var storageBytes: Int = 0

    var body: some View {
        NavigationStack {
            List {
                status
                exportDefaults
                privacy
                legal
                about
            }
            .navigationTitle("Settings")
            .scrollEdgeEffectStyle(.soft, for: .top)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .task {
                storageBytes = await environment.assetStore.storageFootprint()
            }
            .alert(
                "Settings",
                isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } }),
                presenting: error
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { item in
                Text(item.localizedDescription)
            }
        }
    }

    private var status: some View {
        Section("Stiki Pro") {
            LabeledContent("Status") {
                Text(environment.isPro ? "Pro" : "Free")
                    .foregroundStyle(environment.isPro ? .green : .secondary)
            }
            if !environment.isPro {
                Button("Upgrade to Pro") { showPaywall = true }
            }
            Button("Restore purchases") {
                Task {
                    do { try await environment.purchases.restore() }
                    catch let error as StikiError { if !error.isSilent { self.error = error } }
                    catch { self.error = .purchaseFailed(error.localizedDescription) }
                }
            }
            Toggle("iCloud sync", isOn: Binding(
                get: { environment.settings.iCloudSyncEnabled },
                set: { newValue in
                    guard environment.isPro || !newValue else {
                        showPaywall = true
                        return
                    }
                    environment.settings.iCloudSyncEnabled = newValue
                }
            ))
            .disabled(!environment.isPro && !environment.settings.iCloudSyncEnabled)
            Text("iCloud sync is off by default and only available with Pro. Turning it on stores your library in your private iCloud database. Restart Stiki after changing this.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var exportDefaults: some View {
        Section("Export") {
            Picker("Default destination", selection: Binding(
                get: { environment.settings.defaultExportTarget },
                set: { environment.settings.defaultExportTarget = $0 }
            )) {
                ForEach(ExportTarget.allCases) { target in
                    Text(target.displayName).tag(target)
                }
            }
            TextField("Author name", text: Binding(
                get: { environment.settings.authorName },
                set: { environment.settings.authorName = $0 }
            ))
            LabeledContent("On-device storage") {
                Text(ByteFormat.string(storageBytes))
            }
            if !environment.isAppGroupAvailable {
                Label("The App Group is missing from this build's signing, so the iMessage extension cannot see your stickers.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.footnote)
            }
        }
    }

    private var privacy: some View {
        Section("Privacy") {
            Text("Data Not Collected. Stickers are made on this device. There is no account and no tracker. Photos never leave the phone unless you export them or turn on iCloud sync.")
                .font(.subheadline)
        }
    }

    private var legal: some View {
        Section("Legal") {
            if let privacy = LegalLinks.privacy {
                Link("Privacy Policy", destination: privacy)
            }
            if let terms = LegalLinks.terms {
                Link("Terms of Use", destination: terms)
            }
            if let support = LegalLinks.support {
                Link("Support", destination: support)
            }
        }
    }

    private var about: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            Text("Language follows the system. Stiki ships English, Russian and Hebrew, including right-to-left layout.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(layoutDirection == .rightToLeft ? "Right-to-left layout is active." : "Left-to-right layout is active.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("LTR") {
    SettingsView()
        .environment(\.stiki, .preview())
}

#Preview("RTL") {
    SettingsView()
        .environment(\.stiki, .preview())
        .environment(\.layoutDirection, .rightToLeft)
}
