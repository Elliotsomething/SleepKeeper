import Foundation

public enum StorageItemKind: String, Equatable {
    case file
    case folder
}

public enum StorageCleanupCategory: String, Equatable {
    case download
    case personalLargeFile
    case regenerableCache
    case developerCache
    case otherLargeFile
}

public struct StorageFile: Identifiable, Equatable {
    public var id: String { url.path }

    public let url: URL
    public let byteCount: Int64
    public let locationName: String
    public let kind: StorageItemKind
    public let category: StorageCleanupCategory
    public let cleanupReason: String

    public init(
        url: URL,
        byteCount: Int64,
        locationName: String,
        kind: StorageItemKind = .file,
        category: StorageCleanupCategory = .otherLargeFile,
        cleanupReason: String = "Large item; review before moving to Trash."
    ) {
        self.url = url
        self.byteCount = byteCount
        self.locationName = locationName
        self.kind = kind
        self.category = category
        self.cleanupReason = cleanupReason
    }
}

public struct StorageScanReport: Equatable {
    public let files: [StorageFile]
    public let scannedFileCount: Int
    public let skippedItemCount: Int

    public init(files: [StorageFile], scannedFileCount: Int, skippedItemCount: Int) {
        self.files = files
        self.scannedFileCount = scannedFileCount
        self.skippedItemCount = skippedItemCount
    }
}

public enum StorageScanScope {
    public static let wholeDiskLocations = [URL(fileURLWithPath: "/", isDirectory: true)]
    public static let wholeDiskDescription = "entire disk"

    public static func quickFileLocations(homeDirectory: URL) -> [URL] {
        [
            "Downloads",
            "Desktop",
            "Documents",
            "Movies",
            "Pictures"
        ].map { homeDirectory.appendingPathComponent($0, isDirectory: true) }
    }

    public static var quickCleanDescription: String {
        "downloads, large personal files, and regenerable caches"
    }
}

public struct StorageScanner {
    public static let defaultMinimumFileSize: Int64 = 100 * 1024 * 1024
    public static let defaultResultLimit = 200

    private let fileManager: FileManager
    private let minimumFileSize: Int64
    private let resultLimit: Int

    public init(
        fileManager: FileManager = .default,
        minimumFileSize: Int64 = Self.defaultMinimumFileSize,
        resultLimit: Int = Self.defaultResultLimit
    ) {
        self.fileManager = fileManager
        self.minimumFileSize = minimumFileSize
        self.resultLimit = resultLimit
    }

    public func scan(locations: [URL]) -> StorageScanReport {
        scanFiles(
            locations: locations.map {
                .init(
                    url: $0,
                    category: .otherLargeFile,
                    cleanupReason: "Large file; review before moving to Trash."
                )
            }
        )
    }

    public func scanQuickClean(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> StorageScanReport {
        let fileLocations = StorageScanScope.quickFileLocations(homeDirectory: homeDirectory).map {
            StorageFileScanLocation(
                url: $0,
                category: $0.lastPathComponent == "Downloads" ? .download : .personalLargeFile,
                cleanupReason: $0.lastPathComponent == "Downloads"
                    ? "Downloaded file; review whether you still need it."
                    : "Large personal file; review before moving to Trash."
            )
        }

        let fileReport = scanFiles(locations: fileLocations)
        let folderReport = scanFolders(candidates: quickFolderCandidates(homeDirectory: homeDirectory) + discoveredBuildFolderCandidates(homeDirectory: homeDirectory))
        let files = sortedAndLimited(fileReport.files + folderReport.files)

        return StorageScanReport(
            files: files,
            scannedFileCount: fileReport.scannedFileCount + folderReport.scannedFileCount,
            skippedItemCount: fileReport.skippedItemCount + folderReport.skippedItemCount
        )
    }

    private func scanFiles(locations: [StorageFileScanLocation]) -> StorageScanReport {
        var files: [StorageFile] = []
        var scannedFileCount = 0
        var skippedItemCount = 0

        for location in locations {
            guard fileManager.fileExists(atPath: location.url.path) else {
                skippedItemCount += 1
                continue
            }

            guard let enumerator = fileManager.enumerator(
                at: location.url,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .isDirectoryKey,
                    .fileSizeKey
                ],
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in
                    skippedItemCount += 1
                    return true
                }
            ) else {
                skippedItemCount += 1
                continue
            }

            let directoryEnumerator = enumerator
            for case let fileURL as URL in enumerator {
                do {
                    let values = try fileURL.resourceValues(forKeys: [
                        .isRegularFileKey,
                        .isDirectoryKey,
                        .fileSizeKey
                    ])

                    if values.isDirectory == true, Self.quickBuildFolderNames.contains(fileURL.lastPathComponent) {
                        directoryEnumerator.skipDescendants()
                        continue
                    }

                    guard values.isRegularFile == true else { continue }
                    scannedFileCount += 1

                    let byteCount = Int64(values.fileSize ?? 0)

                    guard byteCount >= minimumFileSize else { continue }

                    files.append(StorageFile(
                        url: fileURL,
                        byteCount: byteCount,
                        locationName: locationName(for: location.url),
                        category: location.category,
                        cleanupReason: location.cleanupReason
                    ))
                } catch {
                    skippedItemCount += 1
                }
            }
        }

        return StorageScanReport(
            files: sortedAndLimited(files),
            scannedFileCount: scannedFileCount,
            skippedItemCount: skippedItemCount
        )
    }

    private func scanFolders(candidates: [StorageFolderCandidate]) -> StorageScanReport {
        var files: [StorageFile] = []
        var scannedFileCount = 0
        var skippedItemCount = 0

        for candidate in candidates {
            guard fileManager.fileExists(atPath: candidate.url.path) else {
                continue
            }

            let size = folderSize(at: candidate.url, scannedFileCount: &scannedFileCount, skippedItemCount: &skippedItemCount)
            guard size >= minimumFileSize else { continue }

            files.append(StorageFile(
                url: candidate.url,
                byteCount: size,
                locationName: candidate.locationName,
                kind: .folder,
                category: candidate.category,
                cleanupReason: candidate.cleanupReason
            ))
        }

        return StorageScanReport(
            files: sortedAndLimited(files),
            scannedFileCount: scannedFileCount,
            skippedItemCount: skippedItemCount
        )
    }

    private func folderSize(at url: URL, scannedFileCount: inout Int, skippedItemCount: inout Int) -> Int64 {
        var traversalSkippedItemCount = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in
                traversalSkippedItemCount += 1
                return true
            }
        ) else {
            skippedItemCount += 1
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else { continue }
                scannedFileCount += 1
                total += Int64(values.fileSize ?? 0)
            } catch {
                skippedItemCount += 1
            }
        }
        skippedItemCount += traversalSkippedItemCount
        return total
    }

    private func sortedAndLimited(_ files: [StorageFile]) -> [StorageFile] {
        let sorted = files.sorted {
            if $0.byteCount == $1.byteCount {
                return $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
            }
            return $0.byteCount > $1.byteCount
        }

        return Array(sorted.prefix(max(0, resultLimit)))
    }

    private func locationName(for location: URL) -> String {
        let name = location.lastPathComponent
        return name.isEmpty ? StorageScanScope.wholeDiskDescription : name
    }

    private func quickFolderCandidates(homeDirectory: URL) -> [StorageFolderCandidate] {
        [
            .init(
                url: homeDirectory.appendingPathComponent("Library/Caches", isDirectory: true),
                locationName: "Caches",
                category: .regenerableCache,
                cleanupReason: "App cache data; most apps can regenerate it."
            ),
            .init(
                url: homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true),
                locationName: "Xcode",
                category: .developerCache,
                cleanupReason: "Xcode build data; can be regenerated."
            ),
            .init(
                url: homeDirectory.appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true),
                locationName: "Xcode",
                category: .developerCache,
                cleanupReason: "Old Xcode archives; review before removing."
            ),
            .init(
                url: homeDirectory.appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true),
                locationName: "Simulator",
                category: .developerCache,
                cleanupReason: "Simulator device data; review before removing."
            ),
            .init(
                url: homeDirectory.appendingPathComponent(".npm", isDirectory: true),
                locationName: "Developer cache",
                category: .developerCache,
                cleanupReason: "npm package cache; can be regenerated."
            ),
            .init(
                url: homeDirectory.appendingPathComponent(".cache", isDirectory: true),
                locationName: "Developer cache",
                category: .developerCache,
                cleanupReason: "Tool cache data; most tools can regenerate it."
            ),
            .init(
                url: homeDirectory.appendingPathComponent(".swiftpm", isDirectory: true),
                locationName: "Developer cache",
                category: .developerCache,
                cleanupReason: "SwiftPM cache data; can be regenerated."
            )
        ]
    }

    private func discoveredBuildFolderCandidates(homeDirectory: URL) -> [StorageFolderCandidate] {
        var candidates: [StorageFolderCandidate] = []

        for root in StorageScanScope.quickFileLocations(homeDirectory: homeDirectory) {
            guard fileManager.fileExists(atPath: root.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard Self.quickBuildFolderNames.contains(url.lastPathComponent) else { continue }

                do {
                    let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                    guard values.isDirectory == true else { continue }

                    candidates.append(.init(
                        url: url,
                        locationName: "Project cache",
                        category: .developerCache,
                        cleanupReason: "Dependency or build output folder; can usually be regenerated."
                    ))
                    enumerator.skipDescendants()
                } catch {
                    continue
                }
            }
        }

        return candidates
    }

    private static let quickBuildFolderNames: Set<String> = [
        ".build",
        "build",
        "DerivedData",
        "node_modules",
        "Pods"
    ]
}

private struct StorageFileScanLocation {
    let url: URL
    let category: StorageCleanupCategory
    let cleanupReason: String
}

private struct StorageFolderCandidate {
    let url: URL
    let locationName: String
    let category: StorageCleanupCategory
    let cleanupReason: String
}
