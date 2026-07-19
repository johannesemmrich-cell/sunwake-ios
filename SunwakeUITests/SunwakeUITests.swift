import XCTest

final class SunwakeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Die System-Tab-Bar ist durch die custom V1-Bar ersetzt —
    // Tabs werden über ihre Button-Labels angesteuert, nicht über app.tabBars.

    @MainActor
    func testOnboardingFlowExists() throws {
        // Placeholder: onboarding should be visible on first launch
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Sunwake"].waitForExistence(timeout: 3))
    }

    /// Walks Today → Settings and attaches a screenshot of each screen
    /// (visible under the test report's attachments).
    @MainActor
    func testScreenshotTour() throws {
        let app = launchApp()

        let todayTab = app.buttons["Heute"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10), "Tab bar not found after launch")
        // Interacting is what triggers the interruption monitor; tapping the
        // current tab is a harmless nudge. Repeat once for late alerts
        // (the location prompt arrives after the weather fetch starts).
        todayTab.tap()
        Thread.sleep(forTimeInterval: 3)
        todayTab.tap()

        waitForBriefing(app)
        attachScreenshot(of: app, named: "01-Today")

        let settingsTab = app.buttons["Einstellungen"].exists
            ? app.buttons["Einstellungen"]
            : app.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab not found")
        settingsTab.tap()
        attachScreenshot(of: app, named: "02-Settings")
    }

    /// Premium "tomorrow preview": scroll to the card, generate, and verify
    /// that a summary replaces the button (AI or fallback text — both start
    /// with the pinned opener).
    @MainActor
    func testTomorrowPreviewGeneratesSummary() throws {
        let app = launchApp()

        let todayTab = app.buttons["Heute"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10), "Tab bar not found after launch")
        todayTab.tap()
        Thread.sleep(forTimeInterval: 3)
        todayTab.tap()

        let generateButton = app.buttons["Vorschau erstellen"]
        for _ in 0..<6 where !generateButton.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5), "Tomorrow preview button not found")
        generateButton.tap()

        // Generation may take a while on-device; the fallback is instant.
        let summary = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Dein Ausblick auf morgen")
        ).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 45), "Tomorrow summary did not appear")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1.5)
        attachScreenshot(of: app, named: "03-TomorrowPreview")
    }

    /// Briefing-Banner (4a): Teaser klappt in situ auf (kein Sheet mehr) —
    /// Chips erscheinen, ✕ schließt wieder.
    @MainActor
    func testBriefingBannerExpandsInPlace() throws {
        let app = launchApp()

        let todayTab = app.buttons["Heute"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10))
        todayTab.tap()
        Thread.sleep(forTimeInterval: 3)
        todayTab.tap()

        waitForBriefing(app)

        let teaser = app.buttons["todaySummaryCard"]
        XCTAssertTrue(teaser.waitForExistence(timeout: 20), "Briefing teaser not found")
        teaser.tap()

        let chips = app.buttons["Stichpunkte"]
        XCTAssertTrue(chips.waitForExistence(timeout: 5), "Expanded banner chips not found")
        attachScreenshot(of: app, named: "04-BriefingExpanded")

        let close = app.buttons["briefingCloseButton"]
        XCTAssertTrue(close.exists, "Close button missing on expanded banner")
        close.tap()
        XCTAssertTrue(teaser.waitForExistence(timeout: 5), "Teaser did not return after closing")
    }

    /// One-off tour for design verification: walks the main screens and
    /// writes each screenshot straight to disk.
    @MainActor
    func testDesignHandoffScreenshots() throws {
        let app = launchApp()

        let todayTab = app.buttons["Heute"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10), "Tab bar not found after launch")
        todayTab.tap()
        Thread.sleep(forTimeInterval: 3)
        todayTab.tap()

        waitForBriefing(app)
        saveScreenshot(of: app, named: "sunwake-today")

        // Briefing-Banner aufklappen (in situ, kein Sheet).
        let teaser = app.buttons["todaySummaryCard"]
        if teaser.waitForExistence(timeout: 5), teaser.isHittable {
            teaser.tap()
            _ = app.buttons["Stichpunkte"].waitForExistence(timeout: 5)
            Thread.sleep(forTimeInterval: 1)
            saveScreenshot(of: app, named: "sunwake-briefing-detail")
            let close = app.buttons["briefingCloseButton"]
            if close.exists { close.tap() }
            Thread.sleep(forTimeInterval: 0.8)
        }

        // Tomorrow preview (Premium).
        let generateButton = app.buttons["Vorschau erstellen"]
        for _ in 0..<6 where !generateButton.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        if generateButton.waitForExistence(timeout: 5) {
            generateButton.tap()
            let summary = app.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Dein Ausblick auf morgen")
            ).firstMatch
            _ = summary.waitForExistence(timeout: 45)
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1.5)
            saveScreenshot(of: app, named: "sunwake-tomorrow-preview")
        }

        // Settings.
        let settingsTab = app.buttons["Einstellungen"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab not found")
        settingsTab.tap()
        Thread.sleep(forTimeInterval: 1)
        saveScreenshot(of: app, named: "sunwake-settings")

        // Voice settings.
        let voiceRow = app.staticTexts["Stimme"]
        if voiceRow.waitForExistence(timeout: 5) {
            voiceRow.tap()
            Thread.sleep(forTimeInterval: 1)
            saveScreenshot(of: app, named: "sunwake-settings-voice")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // App layout (background photo + tab order) — below the fold.
        let layoutRow = app.staticTexts["App-Layout"]
        for _ in 0..<6 where !layoutRow.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        if layoutRow.waitForExistence(timeout: 5) {
            layoutRow.tap()
            Thread.sleep(forTimeInterval: 1)
            saveScreenshot(of: app, named: "sunwake-settings-app-layout")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Calendar tab.
        let calendarTab = app.buttons["Kalender"]
        if calendarTab.waitForExistence(timeout: 5) {
            calendarTab.tap()
            Thread.sleep(forTimeInterval: 2)
            saveScreenshot(of: app, named: "sunwake-calendar")
        }

        // Library tab — bei leerem Zustand einen Ordner anlegen, damit
        // Suchfeld + Ordner-Karten sichtbar sind.
        let libraryTab = app.buttons["Bibliothek"]
        if libraryTab.waitForExistence(timeout: 5) {
            libraryTab.tap()
            Thread.sleep(forTimeInterval: 1)
            let createButton = app.buttons["Create Folder"]
            if createButton.exists {
                createButton.tap()
                let nameField = app.textFields.firstMatch
                if nameField.waitForExistence(timeout: 3) {
                    nameField.typeText("Uni")
                    app.buttons["Add"].tap()
                    Thread.sleep(forTimeInterval: 1)
                }
            }
            saveScreenshot(of: app, named: "sunwake-library")
        }

        // Chat, via the Today header shortcut (full-screen cover with ✕).
        todayTab.tap()
        Thread.sleep(forTimeInterval: 1)
        let chatButton = app.buttons["chatShortcutButton"]
        if chatButton.waitForExistence(timeout: 5) {
            chatButton.tap()
            Thread.sleep(forTimeInterval: 2)
            saveScreenshot(of: app, named: "sunwake-chat")
        }
    }

    // MARK: — Helpers

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-selectedLanguage", "de",
        ]

        addUIInterruptionMonitor(withDescription: "System permission alerts") { alert in
            let allowLabels = [
                "Vollen Zugriff erlauben", "Beim Verwenden der App erlauben",
                "Einmal erlauben", "Erlauben",
                "Allow Full Access", "Allow While Using App", "Allow Once", "Allow", "OK",
            ]
            for label in allowLabels where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()
        return app
    }

    /// Wartet, bis die KI-Generierung durch ist (Indikator verschwunden).
    @MainActor
    private func waitForBriefing(_ app: XCUIApplication) {
        let generating = app.staticTexts["Briefing wird vorbereitet…"]
        _ = generating.waitForExistence(timeout: 8)
        for _ in 0..<30 where generating.exists {
            Thread.sleep(forTimeInterval: 1)
        }
        Thread.sleep(forTimeInterval: 1)
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Writes the screenshot PNG directly to the scratchpad — the simulator
    /// shares the host filesystem, so an absolute host path is reachable from
    /// the UI test process without extracting it from the .xcresult bundle.
    @MainActor
    private func saveScreenshot(of app: XCUIApplication, named name: String) {
        let dir = "/private/tmp/claude-502/-Users-johannesemmrich-Developer-Lumio/f0bb0e62-bf66-4ba8-8da3-468263247e5c/scratchpad/design-handoff-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        try? app.screenshot().pngRepresentation.write(to: url)
    }
}
