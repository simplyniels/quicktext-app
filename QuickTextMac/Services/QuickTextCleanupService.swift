import Foundation
import ServiceManagement

enum QuickTextCleanupService {
    struct CleanupItemFailure: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let errorDescription: String
    }

    struct CleanupReport: Equatable {
        let removedURLs: [URL]
        let failedItems: [CleanupItemFailure]
        let knownInstallBundleURLs: [URL]

        var didSucceedFully: Bool {
            failedItems.isEmpty
        }
    }

    static func cleanupUserData() -> CleanupReport {
        KeychainService.delete(key: .openAIAPIKey)

        return cleanup(paths: [
            AppSupportPaths.settingsURL,
            AppSupportPaths.appSupportDirectoryURL,
            AppSupportPaths.cachesDirectoryURL,
            AppSupportPaths.preferencesURL,
            AppSupportPaths.savedApplicationStateDirectoryURL
        ], unregisterLaunchAtLogin: true)
    }

    static func removeLaunchAtLoginRegistration() -> CleanupReport {
        cleanup(paths: [], unregisterLaunchAtLogin: true)
    }

    static func removeApplicationSupportFiles() -> CleanupReport {
        KeychainService.delete(key: .openAIAPIKey)

        return cleanup(
            paths: [
                AppSupportPaths.settingsURL,
                AppSupportPaths.appSupportDirectoryURL
            ],
            unregisterLaunchAtLogin: false
        )
    }

    static func removeCacheAndStateFiles() -> CleanupReport {
        cleanup(
            paths: [
                AppSupportPaths.cachesDirectoryURL,
                AppSupportPaths.preferencesURL,
                AppSupportPaths.savedApplicationStateDirectoryURL
            ],
            unregisterLaunchAtLogin: false
        )
    }

    static func knownInstallBundleURLs() -> [URL] {
        QuickTextInstallLocationService.knownInstallBundleURLs
    }

    static func cleanup(paths: [URL], unregisterLaunchAtLogin: Bool) -> CleanupReport {
        var removedURLs: [URL] = []
        var failedItems: [CleanupItemFailure] = []

        if unregisterLaunchAtLogin {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                failedItems.append(
                    CleanupItemFailure(
                        url: QuickTextInstallLocationService.bundleURL,
                        errorDescription: error.localizedDescription
                    )
                )
            }
        }

        for url in paths {
            do {
                try removeItemIfNeeded(at: url)
                removedURLs.append(url)
            } catch {
                failedItems.append(
                    CleanupItemFailure(
                        url: url,
                        errorDescription: error.localizedDescription
                    )
                )
            }
        }

        return CleanupReport(
            removedURLs: removedURLs,
            failedItems: failedItems,
            knownInstallBundleURLs: QuickTextInstallLocationService.otherInstalledBundleURLs
        )
    }

    private static func removeItemIfNeeded(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try FileManager.default.removeItem(at: url)
    }
}
