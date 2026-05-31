import Foundation
import XCTest
@testable import SleepKeeperCore

final class StorageScannerTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SleepKeeperStorageScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
    }

    func testScanReturnsOnlyFilesAtOrAboveMinimumSizeSortedLargestFirst() throws {
        let folder = temporaryRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let smallFile = try makeFile(named: "small.bin", byteCount: 9, in: folder)
        let mediumFile = try makeFile(named: "medium.bin", byteCount: 10, in: folder)
        let largeFile = try makeFile(named: "large.bin", byteCount: 30, in: folder)

        let report = StorageScanner(minimumFileSize: 10).scan(locations: [folder])

        XCTAssertEqual(report.files.map { $0.url.lastPathComponent }, [largeFile.lastPathComponent, mediumFile.lastPathComponent])
        XCTAssertFalse(report.files.map { $0.url.lastPathComponent }.contains(smallFile.lastPathComponent))
        XCTAssertEqual(report.files.map(\.byteCount), [30, 10])
        XCTAssertEqual(report.scannedFileCount, 3)
    }

    func testScanAppliesResultLimitAfterSorting() throws {
        let folder = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let largest = try makeFile(named: "largest.bin", byteCount: 40, in: folder)
        _ = try makeFile(named: "middle.bin", byteCount: 30, in: folder)
        let secondLargest = try makeFile(named: "second-largest.bin", byteCount: 35, in: folder)

        let report = StorageScanner(minimumFileSize: 1, resultLimit: 2).scan(locations: [folder])

        XCTAssertEqual(report.files.map { $0.url.lastPathComponent }, [largest.lastPathComponent, secondLargest.lastPathComponent])
    }

    func testScanCountsMissingLocationsAsSkippedWithoutFailing() throws {
        let existingFolder = temporaryRoot.appendingPathComponent("Desktop", isDirectory: true)
        try FileManager.default.createDirectory(at: existingFolder, withIntermediateDirectories: true)
        let file = try makeFile(named: "large.bin", byteCount: 10, in: existingFolder)
        let missingFolder = temporaryRoot.appendingPathComponent("Missing", isDirectory: true)

        let report = StorageScanner(minimumFileSize: 1).scan(locations: [missingFolder, existingFolder])

        XCTAssertEqual(report.files.map { $0.url.lastPathComponent }, [file.lastPathComponent])
        XCTAssertEqual(report.skippedItemCount, 1)
    }

    func testWholeDiskScopeUsesRootVolume() {
        XCTAssertEqual(StorageScanScope.wholeDiskLocations, [URL(fileURLWithPath: "/", isDirectory: true)])
        XCTAssertEqual(StorageScanScope.wholeDiskDescription, "entire disk")
    }

    func testQuickCleanScanFindsLargeFilesAndRegenerableFolders() throws {
        let downloads = temporaryRoot.appendingPathComponent("Downloads", isDirectory: true)
        let documents = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
        let caches = temporaryRoot.appendingPathComponent("Library/Caches", isDirectory: true)
        let derivedData = temporaryRoot.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
        let nodeModules = documents.appendingPathComponent("Project/node_modules", isDirectory: true)
        try [downloads, documents, caches, derivedData, nodeModules].forEach {
            try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
        }

        let installer = try makeFile(named: "installer.dmg", byteCount: 20, in: downloads)
        _ = try makeFile(named: "notes.txt", byteCount: 5, in: documents)
        _ = try makeFile(named: "cache.db", byteCount: 12, in: caches)
        _ = try makeFile(named: "build-output.o", byteCount: 30, in: derivedData)
        _ = try makeFile(named: "dependency.js", byteCount: 25, in: nodeModules)

        let report = StorageScanner(minimumFileSize: 10).scanQuickClean(homeDirectory: temporaryRoot)

        XCTAssertEqual(report.files.map { $0.url.lastPathComponent }, ["DerivedData", "node_modules", "installer.dmg", "Caches"])
        XCTAssertEqual(report.files.map(\.kind), [.folder, .folder, .file, .folder])
        XCTAssertEqual(report.files.map(\.category), [.developerCache, .developerCache, .download, .regenerableCache])
        XCTAssertEqual(report.files.first?.cleanupReason, "Xcode build data; can be regenerated.")
        XCTAssertTrue(report.files.contains { $0.url.lastPathComponent == installer.lastPathComponent })
        XCTAssertEqual(report.scannedFileCount, 5)
    }

    private func makeFile(named fileName: String, byteCount: Int, in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent(fileName)
        let data = Data(repeating: 1, count: byteCount)
        try data.write(to: url)
        return url
    }
}
