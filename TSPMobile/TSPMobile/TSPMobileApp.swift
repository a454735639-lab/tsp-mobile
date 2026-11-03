import SwiftUI

@main
struct TSPMobileApp: App {
    @StateObject private var client = TSPClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(client)
                .task { await client.checkAuthStatus() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var client: TSPClient

    var body: some View {
        Group {
            if client.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: client.isAuthenticated)
    }
}

// MARK: - 主界面

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("看板", systemImage: "chart.bar.fill") }

            ScreenerView()
                .tabItem { Label("选股", systemImage: "magnifyingglass") }

            WatchlistView()
                .tabItem { Label("自选", systemImage: "star.fill") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(TSPTheme.accent)
    }
}
