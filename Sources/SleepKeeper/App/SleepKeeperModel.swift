import Foundation
import SleepKeeperCore

@MainActor
final class SleepKeeperModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var displayAwakeEnabled = false
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var lastError: String?
    @Published private(set) var storageFiles: [StorageFile] = []
    @Published private(set) var isStorageScanRunning = false
    @Published private(set) var storageScannedFileCount = 0
    @Published private(set) var storageSkippedItemCount = 0
    @Published private(set) var storageScanDescription = StorageScanScope.quickCleanDescription
    @Published var selectedStorageFileIDs: Set<StorageFile.ID> = []

    private let controller: SleepKeeperController
    private let launchAtLoginManager: LaunchAtLoginManager
    private let storageTrashService: StorageTrashService
    private let defaults: UserDefaults
    private let enabledKey = "sleepKeeper.isEnabled"
    private let displayAwakeKey = "sleepKeeper.displayAwakeEnabled"

    init(
        controller: SleepKeeperController = SleepKeeperController(),
        launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager(),
        storageTrashService: StorageTrashService = StorageTrashService(),
        defaults: UserDefaults = .standard
    ) {
        self.controller = controller
        self.launchAtLoginManager = launchAtLoginManager
        self.storageTrashService = storageTrashService
        self.defaults = defaults

        if defaults.bool(forKey: enabledKey) {
            setEnabled(true)
        }

        if defaults.bool(forKey: displayAwakeKey) {
            setDisplayAwakeEnabled(true)
        }

        refreshLaunchAtLoginStatus()
    }

    var statusTitle: String {
        if displayAwakeEnabled {
            "Keeping display on"
        } else if isEnabled {
            "Keeping Mac awake"
        } else {
            "Normal sleep behavior"
        }
    }

    var statusDetail: String {
        if displayAwakeEnabled {
            "Your display stays on, and macOS will avoid idle system sleep while this is enabled."
        } else if isEnabled {
            "Your display may turn off, but macOS will avoid idle system sleep so background work can continue."
        } else {
            "macOS can sleep normally when the display turns off or the system becomes idle."
        }
    }

    var storageScanLocationsText: String {
        storageScanDescription
    }

    var selectedStorageFiles: [StorageFile] {
        storageFiles.filter { selectedStorageFileIDs.contains($0.id) }
    }

    var selectedStorageByteCount: Int64 {
        selectedStorageFiles.reduce(0) { $0 + $1.byteCount }
    }

    var selectedStorageSummaryText: String {
        "\(selectedStorageFiles.count) items, \(formatByteCount(selectedStorageByteCount))"
    }

    var storageResultsSummaryText: String {
        if isStorageScanRunning {
            return "Scanning \(storageScanLocationsText)..."
        }

        if storageFiles.isEmpty {
            if storageScannedFileCount == 0 && storageSkippedItemCount == 0 {
                return "Quick scan downloads, large personal files, and regenerable caches over \(formatByteCount(StorageScanner.defaultMinimumFileSize))."
            }

            return "No cleanup candidates found across \(storageScannedFileCount) scanned files."
        }

        return "\(storageFiles.count) cleanup candidates found across \(storageScannedFileCount) scanned files."
    }

    func toggle() {
        setEnabled(!isEnabled)
    }

    func toggleDisplayAwake() {
        setDisplayAwakeEnabled(!displayAwakeEnabled)
    }

    func toggleLaunchAtLogin() {
        setLaunchAtLoginEnabled(!launchAtLoginEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            try controller.setEnabled(enabled)
            isEnabled = controller.isEnabled
            defaults.set(isEnabled, forKey: enabledKey)
            lastError = nil
        } catch {
            isEnabled = controller.isEnabled
            defaults.set(isEnabled, forKey: enabledKey)
            lastError = error.localizedDescription
        }
    }

    func setDisplayAwakeEnabled(_ enabled: Bool) {
        do {
            try controller.setDisplayAwakeEnabled(enabled)
            displayAwakeEnabled = controller.isDisplayAwakeEnabled
            defaults.set(displayAwakeEnabled, forKey: displayAwakeKey)

            if displayAwakeEnabled && !isEnabled {
                setEnabled(true)
            } else {
                lastError = nil
            }
        } catch {
            displayAwakeEnabled = controller.isDisplayAwakeEnabled
            defaults.set(displayAwakeEnabled, forKey: displayAwakeKey)
            lastError = error.localizedDescription
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
            lastError = nil
        } catch {
            refreshLaunchAtLoginStatus()
            lastError = error.localizedDescription
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = launchAtLoginManager.isEnabled
    }

    func scanStorage() {
        scanQuickStorage()
    }

    func scanQuickStorage() {
        guard !isStorageScanRunning else { return }

        isStorageScanRunning = true
        storageScanDescription = StorageScanScope.quickCleanDescription

        Task {
            let report = await Task.detached(priority: .userInitiated) {
                StorageScanner().scanQuickClean()
            }.value

            applyStorageReport(report)
        }
    }

    func scanEntireDisk() {
        guard !isStorageScanRunning else { return }

        isStorageScanRunning = true
        storageScanDescription = StorageScanScope.wholeDiskDescription
        let locations = Self.wholeDiskStorageScanLocations

        Task {
            let report = await Task.detached(priority: .userInitiated) {
                StorageScanner().scan(locations: locations)
            }.value

            applyStorageReport(report)
        }
    }

    func scanStorageIfNeeded() {
        guard storageFiles.isEmpty, storageScannedFileCount == 0, storageSkippedItemCount == 0 else { return }
        scanStorage()
    }

    func isStorageFileSelected(_ file: StorageFile) -> Bool {
        selectedStorageFileIDs.contains(file.id)
    }

    func setStorageFile(_ file: StorageFile, selected: Bool) {
        if selected {
            selectedStorageFileIDs.insert(file.id)
        } else {
            selectedStorageFileIDs.remove(file.id)
        }
    }

    func revealStorageFile(_ file: StorageFile) {
        storageTrashService.revealInFinder(file.url)
    }

    func moveSelectedStorageFilesToTrash() async {
        let files = selectedStorageFiles
        guard !files.isEmpty else { return }

        do {
            try await storageTrashService.moveToTrash(files.map(\.url))
            let movedIDs = Set(files.map(\.id))
            storageFiles.removeAll { movedIDs.contains($0.id) }
            selectedStorageFileIDs.subtract(movedIDs)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func formatByteCount(_ byteCount: Int64) -> String {
        Self.byteCountFormatter.string(fromByteCount: byteCount)
    }

    func clearError() {
        lastError = nil
    }

    private func applyStorageReport(_ report: StorageScanReport) {
        storageFiles = report.files
        storageScannedFileCount = report.scannedFileCount
        storageSkippedItemCount = report.skippedItemCount
        selectedStorageFileIDs.formIntersection(Set(report.files.map(\.id)))
        isStorageScanRunning = false
        lastError = nil
    }

    private static var wholeDiskStorageScanLocations: [URL] {
        StorageScanScope.wholeDiskLocations
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter
    }()
}
