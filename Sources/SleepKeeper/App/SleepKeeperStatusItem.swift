import AppKit
import Combine

@MainActor
final class SleepKeeperStatusItem: NSObject {
    private let model: SleepKeeperModel
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []

    init(model: SleepKeeperModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        rebuildMenu()

        model.$isEnabled
            .sink { [weak self] _ in
                self?.configureButton()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        model.$displayAwakeEnabled
            .sink { [weak self] _ in
                self?.configureButton()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        model.$launchAtLoginEnabled
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: statusSymbolName, accessibilityDescription: "SleepKeeper")
        button.title = statusTitle
        button.toolTip = model.statusTitle
    }

    private var statusSymbolName: String {
        if model.displayAwakeEnabled {
            "display"
        } else if model.isEnabled {
            "bolt.circle.fill"
        } else {
            "moon.zzz"
        }
    }

    private var statusTitle: String {
        if model.displayAwakeEnabled {
            " SK Lit"
        } else if model.isEnabled {
            " SK Awake"
        } else {
            " SK Sleep"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: model.statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: model.isEnabled ? "Turn Off Keep Awake" : "Turn On Keep Awake",
            action: #selector(toggleKeepAwake),
            keyEquivalent: "k"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)

        let displayItem = NSMenuItem(
            title: model.displayAwakeEnabled ? "Allow Display Sleep" : "Keep Display On",
            action: #selector(toggleDisplayAwake),
            keyEquivalent: "d"
        )
        displayItem.keyEquivalentModifierMask = [.command, .shift]
        displayItem.state = model.displayAwakeEnabled ? .on : .off
        displayItem.target = self
        menu.addItem(displayItem)

        let loginItem = NSMenuItem(
            title: "Open at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.state = model.launchAtLoginEnabled ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let openWindowItem = NSMenuItem(title: "Open Window", action: #selector(openWindow), keyEquivalent: "")
        openWindowItem.target = self
        menu.addItem(openWindowItem)

        let quitItem = NSMenuItem(title: "Quit SleepKeeper", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func toggleKeepAwake() {
        model.toggle()
    }

    @objc private func toggleDisplayAwake() {
        model.toggleDisplayAwake()
    }

    @objc private func toggleLaunchAtLogin() {
        model.toggleLaunchAtLogin()
    }

    @objc private func openWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
