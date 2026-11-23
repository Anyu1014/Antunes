import XCTest

final class KumoneIOSUITests: XCTestCase {
    @MainActor
    func testClosingFocusedSearchKeepsTabsAndLibraryUsable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-startTab", "library", "-librarySearchButton", "YES",
            "-settings.searchOffMigrated", "YES", "-settings.showSearch", "YES",
            "-settings.showHome", "YES", "-settings.showLibrary", "YES",
            "-bottomBarLyrics", "NO"
        ]
        app.launch()
        let openSearch = app.buttons["library-search-button"]
        XCTAssertTrue(openSearch.waitForExistence(timeout: 10))
        openSearch.tap()

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["search-close-button"].tap()

        let home = app.buttons["section-tab-home"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.tap()
        XCTAssertTrue(app.navigationBars["推荐"].waitForExistence(timeout: 5))
        app.buttons["section-tab-library"].tap()
        XCTAssertTrue(openSearch.waitForExistence(timeout: 5))
        XCTAssertTrue(openSearch.isHittable)
    }
}
