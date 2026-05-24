import Foundation
import SleepKeeperCore

@MainActor
final class SleepKeeperModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var displayAwakeEnabled = false
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var lastError: String?

    private let controller: SleepKeeperController
    private let launchAtLoginManager: LaunchAtLoginManager
    private let defaults: UserDefaults
    private let enabledKey = "sleepKeeper.isEnabled"
    private let displayAwakeKey = "sleepKeeper.displayAwakeEnabled"

    init(
        controller: SleepKeeperController = SleepKeeperController(),
        launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager(),
        defaults: UserDefaults = .standard
    ) {
        self.controller = controller
        self.launchAtLoginManager = launchAtLoginManager
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

    func clearError() {
        lastError = nil
    }
}
