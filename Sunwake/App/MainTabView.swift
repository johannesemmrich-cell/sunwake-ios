import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private var tabs: [AppTab] { Array(appState.tabOrder.prefix(4)) }

    /// Höhe des Tab-Bar-Inhalts über der Geräte-Safe-Area — als Inset in jedem
    /// Tab-Kind, weil safeAreaInset auf der TabView nicht zuverlässig in
    /// NavigationStack-Inhalte propagiert.
    static let tabBarContentHeight: CGFloat = 62

    var body: some View {
        // Native TabView (State-Erhalt pro Tab) mit versteckter System-Bar;
        // die V1-Tab-Bar (Custom-Glyphen, Punkt statt Auswahl-Pille) liegt
        // als einzige Blur-Fläche der App darüber.
        TabView(selection: $appState.selectedTab) {
            ForEach(tabs, id: \.self) { tab in
                Tab(value: tab) {
                    tabContent(for: tab)
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
            }
        }
        .overlay(alignment: .bottom) {
            SunwakeTabBar(
                tabs: tabs,
                selection: $appState.selectedTab,
                language: appState.selectedLanguage
            )
        }
        .onChange(of: subscriptionManager.effectivelyPremium) { _, isPremium in
            if isPremium { appState.applyPremiumLayoutMigrationIfNeeded() }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TodayView()
        case .calendar:
            NavigationStack { SunwakeCalendarView() }
        case .library:
            LibraryView()
        case .chat:
            ChatView()
                .overlay(alignment: .topTrailing) {
                    if !subscriptionManager.effectivelyPremium {
                        PremiumBadge().padding(8)
                    }
                }
        case .settings:
            SettingsView()
        }
    }
}

struct PremiumBadge: View {
    var body: some View {
        Text("Premium")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.sunwakeAccentDeep)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: SunwakeRadius.chip, style: .continuous)
                    .fill(Color.sunwakeTint)
            )
    }
}
