import StikiCore
import SwiftUI

/// Chooses the root layout for the current pose.
///
/// - `.standardPhone` / `.closed` (outer cover, same aspect ratio as a
///   regular iPhone): the existing `RootTabView`, unchanged.
/// - `.fullyOpen` / `.book` on the inner display: `DualPaneRootView`.
/// - `.tent` / `.seated` (hands-free): `GlanceRootView`, StandBy-style.
struct AdaptiveRootView: View {
    @Environment(\.stiki) private var environment
    @State private var selection: AppTab = .library

    var body: some View {
        let presentation = environment.device.presentation
        Group {
            if presentation.prefersGlanceable {
                GlanceRootView(selection: $selection)
            } else if presentation.prefersDualPane {
                DualPaneRootView(selection: $selection)
            } else {
                RootTabView()
            }
        }
        .environment(\.devicePresentation, presentation)
        .observingHinge(environment.device)
        .accessibilityIdentifier("root.\(presentation.pose.rawValue)")
    }
}

/// Sidebar + detail on the large inner display. Each detail is the same
/// feature view the tab UI uses, so no feature is lost or duplicated.
struct DualPaneRootView: View {
    @Binding var selection: AppTab
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(AppTab.allCases, id: \.self, selection: Binding(
                get: { Optional(selection) },
                set: { if let value = $0 { selection = value } }
            )) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .accessibilityIdentifier("sidebar.\(tab)")
            }
            .navigationTitle("Stiki")
            .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 340)
        } detail: {
            detail(for: selection)
                .creaseSafePadding(.leading)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func detail(for tab: AppTab) -> some View {
        switch tab {
        case .library: LibraryView()
        case .create: CreateView()
        case .packs: PacksView()
        case .settings: SettingsView()
        }
    }
}

extension AppTab: CaseIterable {
    static var allCases: [AppTab] { [.library, .create, .packs, .settings] }
}
