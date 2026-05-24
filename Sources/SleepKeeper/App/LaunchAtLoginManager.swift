import Foundation

final class LaunchAtLoginManager {
    private let fileManager: FileManager
    private let label = "com.local.SleepKeeper.login"
    private let appPath = "/Applications/SleepKeeper.app"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var isEnabled: Bool {
        fileManager.fileExists(atPath: agentURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try installAgent()
            try runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", agentURL.path], allowFailure: true)
            try runLaunchctl(arguments: ["enable", "gui/\(getuid())/\(label)"], allowFailure: true)
        } else {
            try runLaunchctl(arguments: ["bootout", "gui/\(getuid())/\(label)"], allowFailure: true)
            if fileManager.fileExists(atPath: agentURL.path) {
                try fileManager.removeItem(at: agentURL)
            }
        }
    }

    private var agentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private func installAgent() throws {
        let launchAgentsURL = agentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                "\(appPath)/Contents/MacOS/SleepKeeper"
            ],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: agentURL, options: .atomic)
    }

    private func runLaunchctl(arguments: [String], allowFailure: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()

        if !allowFailure && process.terminationStatus != 0 {
            throw NSError(
                domain: "SleepKeeper.LaunchAtLogin",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "launchctl failed with status \(process.terminationStatus)."]
            )
        }
    }
}
