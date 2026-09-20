import Foundation

/// Browser decisions shared by capture and command execution.
public enum BrowserSupport {
    private static let chromiumBrowsers: Set<String> = [
        "com.brave.browser", "com.google.chrome", "com.microsoft.edgemac",
        "company.thebrowser.dia", "company.thebrowser.browser"
    ]

    public static func isBrowser(_ bundleIdentifier: String?) -> Bool {
        let identifier = bundleIdentifier?.lowercased() ?? ""
        return chromiumBrowsers.contains(identifier) || ["com.apple.safari", "org.mozilla.firefox"].contains(identifier)
    }

    /// Known browsers should not depend on a particular framework/helper layout.
    public static func isKnownChromium(_ bundleIdentifier: String?) -> Bool {
        chromiumBrowsers.contains(bundleIdentifier?.lowercased() ?? "")
    }

    public static func shouldRefreshPage(operation: String, windowChanged: Bool) -> Bool {
        windowChanged || ["OPEN_URL", "PRESS_RETURN", "CLICK", "GO_BACK", "NEXT_TAB", "MENU"].contains(operation)
    }
}

/// Avoid waiting on every capture of an Electron window with only native controls.
/// The caller serializes access; `now` is monotonic uptime.
public struct WebContentRetryCache<Window: Hashable> {
    private var retryAfter: [Window: TimeInterval] = [:]
    public init() {}

    public mutating func shouldWait(for window: Window, isBrowser: Bool, loading: Bool, now: TimeInterval) -> Bool {
        retryAfter = retryAfter.filter { $0.value > now }
        if isBrowser || loading {
            retryAfter.removeValue(forKey: window)
            return true
        }
        return retryAfter[window] == nil
    }

    public mutating func recordTimeout(for window: Window, now: TimeInterval) {
        retryAfter = retryAfter.filter { $0.value > now }
        retryAfter[window] = now + 10
    }

    public mutating func recordReady(for window: Window) {
        retryAfter.removeValue(forKey: window)
    }
}

/// A bounded observation of accessible content. Never include secure-field values.
public struct PageElement: Equatable, Hashable, Sendable {
    public let role: String
    public let name: String
    public let value: String?
    public let url: String?
    public let children: Int
    public let state: String

    public init(role: String, name: String, value: String? = nil, url: String? = nil, children: Int = 0, state: String = "") {
        self.role = role
        self.name = name
        self.value = value
        self.url = url
        self.children = children
        self.state = state
    }
}

public struct PageObservation: Equatable, Hashable, Sendable {
    public let elements: [PageElement]
    public let ready: Bool

    public init(elements: [PageElement], ready: Bool) {
        self.elements = elements
        self.ready = ready
    }
}

/// A loading or missing page must not settle just because successive reads are empty.
public struct PageStability {
    private let stablePolls: Int
    private var previous: PageObservation?
    private var stableRuns = 0

    public init(stablePolls: Int = 2) { self.stablePolls = max(1, stablePolls) }

    public mutating func observe(_ current: PageObservation) -> Bool {
        guard current.ready, !current.elements.isEmpty else {
            previous = nil
            stableRuns = 0
            return false
        }
        stableRuns = current == previous ? stableRuns + 1 : 0
        previous = current
        return stableRuns >= stablePolls
    }
}
