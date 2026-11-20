import Foundation

enum LaunchAtLoginManager {
    static let label = "com.dansorrel.MenuTogether"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var executablePath: String {
        let installedPath = "/Applications/MenuTogether.app/Contents/MacOS/MenuTogether"
        if FileManager.default.fileExists(atPath: installedPath) {
            return installedPath
        }
        return Bundle.main.executablePath ?? installedPath
    }

    static var isEnabled: Bool {
        get {
            return FileManager.default.fileExists(atPath: plistURL.path)
        }
        set {
            if newValue {
                enable()
            } else {
                disable()
            }
            AppSettings.shared.launchAtLogin = newValue
        }
    }

    static func enable() {
        let agentsDir = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)

        let plistDict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                executablePath,
                "--launched-at-login"
            ],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]

        if let data = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0) {
            try? data.write(to: plistURL, options: .atomic)
        }
    }

    static func disable() {
        try? FileManager.default.removeItem(at: plistURL)
    }

    static func syncWithSettings() {
        if AppSettings.shared.launchAtLogin {
            enable()
        } else {
            disable()
        }
    }
}
