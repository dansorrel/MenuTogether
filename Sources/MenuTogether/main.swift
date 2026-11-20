import Cocoa
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var tracker: WindowTracker?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchAtLoginManager.syncWithSettings()
        setupStatusBar()
        setupGlobalHotKey()
        checkAccessibilityPermissions()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChanges),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func setupGlobalHotKey() {
        GlobalHotKeyManager.shared.onToggle = { [weak self] in
            self?.toggleEnabled()
        }
        GlobalHotKeyManager.shared.registerDefaultHotKey()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBarIcon()
        rebuildStatusMenu()
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        let trusted = AXIsProcessTrusted()
        let isEnabled = AppSettings.shared.isEnabled
        let symbolName: String
        if !trusted {
            symbolName = "exclamationmark.triangle.fill"
        } else {
            symbolName = isEnabled ? "menubar.rectangle" : "menubar.arrow.up.rectangle"
        }
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MenuTogether")
        button.alphaValue = (trusted && isEnabled) ? 1.0 : 0.65
    }

    private func rebuildStatusMenu() {
        updateStatusBarIcon()
        let menu = NSMenu()

        let trusted = AXIsProcessTrusted()
        let isEnabled = AppSettings.shared.isEnabled
        let statusTitle: String
        if !trusted {
            statusTitle = "Status: Aguardando Permissão de Acessibilidade…"
        } else {
            statusTitle = isEnabled ? "Status: Ativo" : "Status: Pausado"
        }

        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        if trusted {
            let toggleItem = NSMenuItem(
                title: isEnabled ? "Desativar MenuTogether (⌃⌥⌘M)" : "Ativar MenuTogether (⌃⌥⌘M)",
                action: #selector(toggleEnabled),
                keyEquivalent: "m"
            )
            toggleItem.keyEquivalentModifierMask = [.control, .option, .command]
            toggleItem.target = self
            menu.addItem(toggleItem)

            menu.addItem(.separator())

            let monitorsHeader = NSMenuItem(title: "Monitores Habilitados:", action: nil, keyEquivalent: "")
            monitorsHeader.isEnabled = false
            menu.addItem(monitorsHeader)

            for screen in AppSettings.connectedScreens() {
                let diagInfo = screen.formattedDiagonal.isEmpty ? "" : " (\(screen.formattedDiagonal))"
                let item = NSMenuItem(
                    title: "\(screen.name)\(diagInfo)",
                    action: #selector(toggleMonitorFromMenu(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = screen.id
                item.state = AppSettings.shared.isMonitorEnabled(screen.id) ? .on : .off
                menu.addItem(item)
            }
        } else {
            let requestItem = NSMenuItem(
                title: "Solicitar Permissão de Acessibilidade…",
                action: #selector(promptAccessibility),
                keyEquivalent: ""
            )
            requestItem.target = self
            menu.addItem(requestItem)
        }

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Iniciar Automaticamente com o Mac",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

        let settingsItem = NSMenuItem(
            title: "Configurações e Ajustes Finos…",
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let sysPrefItem = NSMenuItem(
            title: "Abrir Painel nos Ajustes do Sistema…",
            action: #selector(openSystemSettingsPane),
            keyEquivalent: ""
        )
        sysPrefItem.target = self
        menu.addItem(sysPrefItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Sair do MenuTogether",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()

        if trusted {
            startTracking()
        } else {
            // Prompt only once when not trusted yet
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)

            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.permissionTimer = nil
                    self?.startTracking()
                }
            }
        }
    }

    private func startTracking() {
        if tracker == nil {
            tracker = WindowTracker()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: AppSettings.settingsChangedNotification,
            object: nil
        )
        rebuildStatusMenu()
    }

    @objc private func handleSettingsChanged() {
        rebuildStatusMenu()
    }

    @objc private func handleScreenChanges() {
        rebuildStatusMenu()
        tracker?.refreshActiveWindow()
    }

    @objc private func toggleEnabled() {
        let nextState = !AppSettings.shared.isEnabled
        if let tracker = tracker {
            tracker.setEnabled(nextState)
        } else {
            AppSettings.shared.isEnabled = nextState
        }
        rebuildStatusMenu()
    }

    @objc private func toggleMonitorFromMenu(_ sender: NSMenuItem) {
        guard let screenID = sender.representedObject as? String else { return }
        let currentlyEnabled = AppSettings.shared.isMonitorEnabled(screenID)
        AppSettings.shared.setMonitor(screenID, enabled: !currentlyEnabled)
        rebuildStatusMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLoginManager.isEnabled.toggle()
        rebuildStatusMenu()
    }

    @objc private func openSettingsWindow() {
        SettingsWindowController.shared.show()
    }

    @objc private func openSystemSettingsPane() {
        let userPane = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/PreferencePanes/MenuTogether.prefPane")
        if FileManager.default.fileExists(atPath: userPane.path) {
            NSWorkspace.shared.open(userPane)
        } else {
            SettingsWindowController.shared.show()
        }
    }

    @objc private func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Main Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
