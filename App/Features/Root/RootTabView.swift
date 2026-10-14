import SwiftUI

/// The four tabs: Library, Create, Packs, Settings.
///
/// System `TabView` supplies the glass tab bar. Minimize-on-scroll keeps the
/// canvas first, which is the Liquid Glass rule.
struct RootTabView: View {
    @Environment(\.stiki) private var environment
    @State private var selectedTab: AppTab = .library

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: .library) {
                LibraryView()
            }
            Tab(AppTab.create.title, systemImage: AppTab.create.systemImage, value: .create) {
                CreateView()
            }
            Tab(AppTab.packs.title, systemImage: AppTab.packs.systemImage, value: .packs) {
                PacksView()
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: .settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(\.stiki, environment)
    }
}

enum AppTab: Hashable {
    case library
    case create
    case packs
    case settings

    var title: LocalizedStringKey {
        switch self {
        case .library: return "Library"
        case .create: return "Create"
        case .packs: return "Packs"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .library: return "square.grid.2x2.fill"
        case .create: return "plus.circle.fill"
        case .packs: return "tray.full.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

#Preview {
    RootTabView()
        .environment(\.stiki, .preview())
}
