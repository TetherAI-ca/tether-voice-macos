import XCTest
@testable import JevCore

final class BrowserSupportTests: XCTestCase {
    func testDiaReceivesBrowserRecoveryAndKeepsLinksInCurrentBrowser() {
        XCTAssertTrue(BrowserSupport.isBrowser("company.thebrowser.dia"))
        XCTAssertTrue(BrowserSupport.isBrowser("COMPANY.THEBROWSER.DIA"))
        XCTAssertTrue(BrowserSupport.isBrowser("company.thebrowser.Browser"))
        XCTAssertTrue(BrowserSupport.isBrowser("com.apple.Safari"))
        XCTAssertTrue(BrowserSupport.isBrowser("org.mozilla.firefox"))
        XCTAssertFalse(BrowserSupport.isBrowser("com.apple.finder"))
        XCTAssertFalse(BrowserSupport.isBrowser("com.example.electron"))
        XCTAssertFalse(BrowserSupport.isBrowser(nil))
    }

    func testNavigationWithinSameTitledTabStillRefreshesPage() {
        for operation in ["CLICK", "PRESS_RETURN", "GO_BACK", "NEXT_TAB", "OPEN_URL", "MENU"] {
            XCTAssertTrue(BrowserSupport.shouldRefreshPage(operation: operation, windowChanged: false), operation)
        }
        XCTAssertFalse(BrowserSupport.shouldRefreshPage(operation: "TYPE_TEXT", windowChanged: false))
        XCTAssertFalse(BrowserSupport.shouldRefreshPage(operation: "DONE", windowChanged: false))
        XCTAssertTrue(BrowserSupport.shouldRefreshPage(operation: "PRESS_ESCAPE", windowChanged: true))
    }

    func testDiaRequestsChromiumAccessibilityWithoutRendererHelperDiscovery() {
        XCTAssertTrue(BrowserSupport.isKnownChromium("company.thebrowser.dia"))
        XCTAssertTrue(BrowserSupport.isKnownChromium("company.thebrowser.Browser"))
        XCTAssertTrue(BrowserSupport.isKnownChromium("com.google.Chrome"))
        XCTAssertFalse(BrowserSupport.isKnownChromium("com.apple.Safari"))
        XCTAssertFalse(BrowserSupport.isKnownChromium("org.mozilla.firefox"))
        XCTAssertFalse(BrowserSupport.isKnownChromium(nil))
    }

    func testMissingWebContentCanRecoverInTheSameWindowAfterTimeout() {
        var cache = WebContentRetryCache<String>()
        XCTAssertTrue(cache.shouldWait(for: "window", isBrowser: false, loading: false, now: 0))
        cache.recordTimeout(for: "window", now: 3)
        XCTAssertFalse(cache.shouldWait(for: "window", isBrowser: false, loading: false, now: 4))
        XCTAssertTrue(cache.shouldWait(for: "other window", isBrowser: false, loading: false, now: 4))
        XCTAssertTrue(cache.shouldWait(for: "window", isBrowser: false, loading: false, now: 14))
    }

    func testBrowsersAndLoadingPagesNeverUseTheMissingContentCooldown() {
        var cache = WebContentRetryCache<String>()
        cache.recordTimeout(for: "window", now: 0)
        XCTAssertTrue(cache.shouldWait(for: "window", isBrowser: true, loading: false, now: 1))
        XCTAssertTrue(cache.shouldWait(for: "window", isBrowser: false, loading: true, now: 1))
        cache.recordTimeout(for: "window", now: 1)
        XCTAssertFalse(cache.shouldWait(for: "window", isBrowser: false, loading: false, now: 2))
        cache.recordReady(for: "window")
        XCTAssertTrue(cache.shouldWait(for: "window", isBrowser: false, loading: false, now: 2))
    }

    func testSameSizePageChangesResetStability() {
        var stability = PageStability(stablePolls: 2)
        func page(_ name: String, _ value: String, _ url: String) -> PageObservation {
            PageObservation(elements: [PageElement(role: "AXLink", name: name, value: value, url: url)], ready: true)
        }
        let first = page("Project one", "", "/project/one")
        let renamed = page("Project two", "", "/project/one")
        let changedValue = page("Project two", "selected", "/project/one")
        let navigated = page("Project two", "selected", "/project/two")
        for observation in [first, renamed, changedValue, navigated] {
            XCTAssertFalse(stability.observe(observation))
            XCTAssertFalse(stability.observe(observation))
        }
        XCTAssertTrue(stability.observe(navigated))
    }

    func testLoadingAndMissingPagesDoNotSettle() {
        var stability = PageStability(stablePolls: 1)
        let element = PageElement(role: "AXWebArea", name: "Railway")
        let ready = PageObservation(elements: [element], ready: true)
        XCTAssertFalse(stability.observe(ready))
        for _ in 0..<3 {
            XCTAssertFalse(stability.observe(PageObservation(elements: [element], ready: false)))
            XCTAssertFalse(stability.observe(PageObservation(elements: [], ready: true)))
        }
        XCTAssertFalse(stability.observe(ready))
        XCTAssertTrue(stability.observe(ready))
    }
}
