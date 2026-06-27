import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Tab("Today", systemImage: "sun.horizon.fill", value: AppTab.today) {
                TodayView()
            }

            Tab("Library", systemImage: "books.vertical.fill", value: AppTab.library) {
                LibraryView()
            }

            Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill", value: AppTab.chat) {
                ChatView()
                    .overlay(alignment: .topTrailing) {
                        if !subscriptionManager.effectivelyPremium {
                            PremiumBadge()
                                .padding(8)
                        }
                    }
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Color.lumioAccent)
    }
}

struct PremiumBadge: View {
    var body: some View {
        Text("Premium")
            .font(LumioTypography.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.lumioAccent))
    }
}
