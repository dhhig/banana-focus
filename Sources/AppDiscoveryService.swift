import Foundation
import AppKit

/// Scans the system for installed applications and returns them as StudyApp models.
class AppDiscoveryService {

    /// Discover all user-facing applications from standard directories.
    func discoverApps() -> [StudyApp] {
        var apps: [StudyApp] = []
        var seenBundleIDs = Set<String>()

        let searchPaths: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications"),
        ]

        let fileManager = FileManager.default

        for searchPath in searchPaths {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: searchPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ) else { continue }

            for url in contents {
                // Handle both .app bundles and subdirectories containing .app bundles
                if url.pathExtension == "app" {
                    if let app = extractAppInfo(from: url) {
                        if seenBundleIDs.insert(app.id).inserted {
                            apps.append(app)
                        }
                    }
                } else if url.hasDirectoryPath {
                    // Check one level deeper (e.g. /Applications/Utilities/)
                    if let subContents = try? fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: .skipsHiddenFiles
                    ) {
                        for subURL in subContents where subURL.pathExtension == "app" {
                            if let app = extractAppInfo(from: subURL) {
                                if seenBundleIDs.insert(app.id).inserted {
                                    apps.append(app)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Sort: system apps last, then alphabetically
        apps.sort { a, b in
            let aIsSystem = a.path.hasPrefix("/System/")
            let bIsSystem = b.path.hasPrefix("/System/")
            if aIsSystem != bIsSystem { return !aIsSystem }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        return apps
    }

    private func extractAppInfo(from url: URL) -> StudyApp? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier,
              let infoDict = bundle.infoDictionary else {
            // Try reading Info.plist directly as fallback
            let infoPlistPath = url.appendingPathComponent("Contents/Info.plist")
            guard let plist = NSDictionary(contentsOf: infoPlistPath),
                  let bundleID = plist["CFBundleIdentifier"] as? String else {
                return nil
            }
            let name = (plist["CFBundleDisplayName"] as? String)
                ?? (plist["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
            return StudyApp(id: bundleID, name: name, path: url.path)
        }

        let name = (infoDict["CFBundleDisplayName"] as? String)
            ?? (infoDict["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        return StudyApp(id: bundleID, name: name, path: url.path)
    }

    /// Filter apps by search text.
    func filter(_ apps: [StudyApp], query: String) -> [StudyApp] {
        guard !query.isEmpty else { return apps }
        let q = query.lowercased()
        return apps.filter { $0.name.lowercased().contains(q) }
    }
}
