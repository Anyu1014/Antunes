import Foundation
import os

/// Built-in endpoints; existing stored configuration remains compatible.
enum Upstream {

    /// Stored endpoint configuration.
    struct Hosts: Codable, Equatable, Sendable {
        /// Web, login and the encrypted API: `music.<api>.com`.
        let api: Int
        /// Signed audio and images: `*.music.<cdn>.net`.
        let cdn: Int
    }

    private static let defaultHosts = Hosts(api: 163, cdn: 126)

    private static let defaultsKey = "upstream.hosts"
    private static let state = OSAllocatedUnfairLock<Hosts?>(initialState: load())

    private static func load() -> Hosts? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return defaultHosts }
        return (try? JSONDecoder().decode(Hosts.self, from: data)) ?? defaultHosts
    }

    static var hosts: Hosts? { state.withLock { $0 } }
    static var isConfigured: Bool { hosts != nil }

    /// Stores endpoint configuration. Pass `persist: false` from tests.
    static func configure(_ hosts: Hosts, persist: Bool = true) {
        state.withLock { $0 = hosts }
        if persist, let data = try? JSONEncoder().encode(hosts) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func reset() {
        state.withLock { $0 = defaultHosts }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static let didChange = Notification.Name("Upstream.didChange")

    // MARK: - Hosts

    static var webHost: String? { hosts.map { "music.\($0.api).com" } }
    static var interfaceHost: String? { hosts.map { "interface.music.\($0.api).com" } }
    /// Suffix every audio CDN host ends with, leading dot included.
    static var cdnSuffix: String? { hosts.map { ".music.\($0.cdn).net" } }

    static func webURL(_ pathAndQuery: String) -> URL? {
        webHost.flatMap { URL(string: "https://\($0)\(pathAndQuery)") }
    }

    static func songPageURL(id: Int) -> URL? { webURL("/#/song?id=\(id)") }

    // MARK: - Protocol identifiers

    /// Source identifier used in request headers, cache keys, offline records
    /// and account scopes.
    static let tag = unshift("ofufbtf")

    private static func unshift(_ shifted: String) -> String {
        String(String.UnicodeScalarView(shifted.unicodeScalars.compactMap { Unicode.Scalar($0.value - 1) }))
    }

    /// Client name for the User-Agent.
    static var clientName: String { tag.prefix(1).uppercased() + tag.dropFirst() + "Music" }

    /// The scope offline downloads and sync records carry for an account.
    static func accountScope(userID: Int) -> String { "\(tag):\(userID)" }
}
