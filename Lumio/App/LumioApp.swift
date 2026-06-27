import SwiftUI
import SwiftData

@main
struct LumioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var subscriptionManager = SubscriptionManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PDFFolder.self,
            PDFDocument.self,
            FeedbackEntry.self,
            UserPreferences.self,
            BriefingCache.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(subscriptionManager)
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(themeManager.preferredColorScheme)
        }
    }
}
