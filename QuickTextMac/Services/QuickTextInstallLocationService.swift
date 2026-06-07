import AppKit
import Foundation

enum QuickTextInstallLocationService {
    enum InstallLocation: Equatable {
        case applications
        case userApplications
        case outsideApplications(URL)
        case unknown

        var isInApplicationsFolder: Bool {
            switch self {
            case .applications, .userApplications:
                return true
            case .outsideApplications, .unknown:
                return false
            }
        }

        var isCanonicalInstall: Bool {
            if case .applications = self {
                return true
            }
            return false
        }
    }

    enum MoveError: LocalizedError {
        case sourceBundleMissing(URL)
        case destinationUnavailable
        case destinationExists(URL)
        case destinationNotWritable(URL)
        case copyFailed(source: URL, destination: URL, underlying: Error)

        var errorDescription: String? {
            switch self {
            case .sourceBundleMissing:
                return "Die aktuelle App-Installation wurde nicht gefunden."
            case .destinationUnavailable:
                return "Der Zielordner /Applications ist nicht verfügbar."
            case .destinationExists:
                return "Am Zielort liegt bereits eine Quick Text-Installation."
            case .destinationNotWritable:
                return "Der Zielordner /Applications ist auf diesem Mac nicht beschreibbar."
            case .copyFailed:
                return "Quick Text konnte nicht nach /Applications kopiert werden."
            }
        }
    }

    static var bundleURL: URL {
        Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    static var bundleName: String {
        bundleURL.deletingPathExtension().lastPathComponent
    }

    static var currentInstallLocation: InstallLocation {
        let currentDirectory = bundleURL.deletingLastPathComponent()
        let standardizedCurrentDirectory = currentDirectory.standardizedFileURL.resolvingSymlinksInPath()

        if standardizedCurrentDirectory == systemApplicationsDirectoryURL.standardizedFileURL.resolvingSymlinksInPath() {
            return .applications
        }

        if standardizedCurrentDirectory == userApplicationsDirectoryURL.standardizedFileURL.resolvingSymlinksInPath() {
            return .userApplications
        }

        if FileManager.default.fileExists(atPath: bundleURL.path) {
            return .outsideApplications(bundleURL)
        }

        return .unknown
    }

    static var shouldOfferMoveToApplications: Bool {
        !currentInstallLocation.isCanonicalInstall
    }

    static var systemApplicationsDirectoryURL: URL {
        URL(fileURLWithPath: "/Applications", isDirectory: true)
    }

    static var userApplicationsDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
    }

    static var preferredInstallDirectoryURL: URL? {
        systemApplicationsDirectoryURL
    }

    static var preferredInstallBundleURL: URL? {
        preferredInstallDirectoryURL?.appendingPathComponent(bundleURL.lastPathComponent)
    }

    static var knownInstallBundleURLs: [URL] {
        let candidates = [
            bundleURL,
            systemApplicationsDirectoryURL.appendingPathComponent(bundleURL.lastPathComponent),
            userApplicationsDirectoryURL.appendingPathComponent(bundleURL.lastPathComponent)
        ]

        var seen = Set<String>()
        return candidates.filter { candidate in
            let key = candidate.standardizedFileURL.resolvingSymlinksInPath().path
            guard seen.insert(key).inserted else { return false }
            return FileManager.default.fileExists(atPath: candidate.path)
        }
    }

    static var otherInstalledBundleURLs: [URL] {
        knownInstallBundleURLs.filter { $0 != bundleURL }
    }

    static func moveCurrentAppToApplications(replacingExisting: Bool = true) throws -> URL {
        let sourceURL = bundleURL
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw MoveError.sourceBundleMissing(sourceURL)
        }

        guard let destinationDirectoryURL = preferredInstallDirectoryURL else {
            throw MoveError.destinationUnavailable
        }

        let destinationURL = destinationDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)

        if sourceURL.standardizedFileURL.resolvingSymlinksInPath() == destinationURL.standardizedFileURL.resolvingSymlinksInPath() {
            return destinationURL
        }

        try ensureDirectoryExists(at: destinationDirectoryURL)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            guard replacingExisting else {
                throw MoveError.destinationExists(destinationURL)
            }
            try FileManager.default.removeItem(at: destinationURL)
        }

        guard FileManager.default.isWritableFile(atPath: destinationDirectoryURL.path) else {
            throw MoveError.destinationNotWritable(destinationDirectoryURL)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw MoveError.copyFailed(source: sourceURL, destination: destinationURL, underlying: error)
        }

        return destinationURL
    }

    static func moveToApplicationsAndRelaunch(replacingExisting: Bool = true) throws {
        let destinationURL = try moveCurrentAppToApplications(replacingExisting: replacingExisting)

        let openProcess = Process()
        openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openProcess.arguments = [destinationURL.path]
        try openProcess.run()

        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    private static func ensureDirectoryExists(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            return
        }

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
