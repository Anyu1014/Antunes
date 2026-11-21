#if os(macOS)
import Combine
import Sparkle
import SwiftUI

/// Wraps Sparkle's standard updater so SwiftUI menus can observe its state.
@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    @Published private(set) var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
        // 二改作品：不再向上游 feed 自动检查更新（设置里的「更新」已移除）。
        controller.updater.automaticallyChecksForUpdates = false
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

struct CheckForUpdatesButton: View {
    @ObservedObject private var updater = UpdaterManager.shared

    var body: some View {
        Button("检查更新…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
#else
import SwiftUI

struct CheckForUpdatesButton: View {
    var body: some View {
        EmptyView()
    }
}
#endif
