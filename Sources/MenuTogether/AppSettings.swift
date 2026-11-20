import Cocoa

struct ScreenDescriptor: Identifiable {
    let id: String // Stable key (e.g. localizedName)
    let displayID: CGDirectDisplayID
    let name: String
    let resolution: String
    let diagonalInches: Double
    let screen: NSScreen

    var formattedDiagonal: String {
        if diagonalInches > 1 {
            return String(format: "%.1f\"", diagonalInches)
        }
        return ""
    }

    var isSmallMonitor: Bool {
        return diagonalInches > 0 && diagonalInches < 18.0
    }
}

final class AppSettings {
    static let shared = AppSettings()

    static let suiteName = "com.dansorrel.MenuTogether"
    static let settingsChangedNotification = Notification.Name("com.dansorrel.MenuTogether.settingsChanged")

    private let defaults: UserDefaults

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let maxScreenPercentage = "maxScreenPercentage"
        static let verticalGap = "verticalGap"
        static let horizontalOffset = "horizontalOffset"
        static let disabledMonitors = "disabledMonitors"
        static let hasInitializedMonitors = "hasInitializedMonitors"
    }

    private init() {
        self.defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        registerDefaults()
        initializeMonitorDefaultsIfNeeded()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleExternalChange(_:)),
            name: Self.settingsChangedNotification,
            object: nil
        )
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.maxScreenPercentage: 80.0,
            Keys.verticalGap: 2.0,
            Keys.horizontalOffset: 0.0
        ])
    }

    /// On first run, automatically disable monitors smaller than 18 inches (e.g. 13" Built-in Retina & Kamvas 13)
    /// while keeping large monitors (e.g. 55" Mi TV) enabled.
    func initializeMonitorDefaultsIfNeeded() {
        defaults.synchronize()
        if !defaults.bool(forKey: Keys.hasInitializedMonitors) {
            var initialDisabled: [String] = []
            for desc in Self.connectedScreens() {
                if desc.isSmallMonitor {
                    initialDisabled.append(desc.id)
                }
            }
            defaults.set(initialDisabled, forKey: Keys.disabledMonitors)
            defaults.set(true, forKey: Keys.hasInitializedMonitors)
            defaults.synchronize()
        }
    }

    static func connectedScreens() -> [ScreenDescriptor] {
        return NSScreen.screens.map { screen in
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            let mm = CGDisplayScreenSize(displayID)
            let diag = sqrt(mm.width * mm.width + mm.height * mm.height) / 25.4
            let name = screen.localizedName
            let w = Int(screen.frame.width)
            let h = Int(screen.frame.height)
            return ScreenDescriptor(
                id: name,
                displayID: displayID,
                name: name,
                resolution: "\(w)×\(h)",
                diagonalInches: diag,
                screen: screen
            )
        }
    }

    var isEnabled: Bool {
        get {
            defaults.synchronize()
            return defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: Keys.isEnabled)
            notifyChange()
        }
    }

    var maxScreenPercentage: Double {
        get {
            defaults.synchronize()
            let val = defaults.double(forKey: Keys.maxScreenPercentage)
            return val > 0 ? val : 80.0
        }
        set {
            defaults.set(newValue, forKey: Keys.maxScreenPercentage)
            notifyChange()
        }
    }

    var verticalGap: Double {
        get {
            defaults.synchronize()
            if defaults.object(forKey: Keys.verticalGap) == nil { return 2.0 }
            return defaults.double(forKey: Keys.verticalGap)
        }
        set {
            defaults.set(newValue, forKey: Keys.verticalGap)
            notifyChange()
        }
    }

    var horizontalOffset: Double {
        get {
            defaults.synchronize()
            if defaults.object(forKey: Keys.horizontalOffset) == nil { return 0.0 }
            return defaults.double(forKey: Keys.horizontalOffset)
        }
        set {
            defaults.set(newValue, forKey: Keys.horizontalOffset)
            notifyChange()
        }
    }

    var disabledMonitors: Set<String> {
        get {
            defaults.synchronize()
            let arr = defaults.stringArray(forKey: Keys.disabledMonitors) ?? []
            return Set(arr)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.disabledMonitors)
            notifyChange()
        }
    }

    func isMonitorEnabled(_ screenID: String) -> Bool {
        return !disabledMonitors.contains(screenID)
    }

    func setMonitor(_ screenID: String, enabled: Bool) {
        var current = disabledMonitors
        if enabled {
            current.remove(screenID)
        } else {
            current.insert(screenID)
        }
        disabledMonitors = current
    }

    func notifyChange() {
        defaults.synchronize()
        DistributedNotificationCenter.default().postNotificationName(
            Self.settingsChangedNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        NotificationCenter.default.post(name: Self.settingsChangedNotification, object: nil)
    }

    @objc private func handleExternalChange(_ notification: Notification) {
        defaults.synchronize()
        NotificationCenter.default.post(name: Self.settingsChangedNotification, object: nil)
    }
}
