import Cocoa
import ApplicationServices

final class WindowTracker {
    private let panel = AttachedMenuPanel()
    private var axObserver: AXObserver?
    private var trackedPID: pid_t = 0
    private var pollTimer: Timer?
    private var isEnabled: Bool {
        get { AppSettings.shared.isEnabled }
        set {
            AppSettings.shared.isEnabled = newValue
            if !newValue {
                panel.orderOut(nil)
            } else {
                refreshActiveWindow()
            }
        }
    }

    init() {
        setupWorkspaceNotifications()
        startPollingTimer()
        refreshActiveWindow()
    }

    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }

    var enabled: Bool {
        return isEnabled
    }

    private func setupWorkspaceNotifications() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(
            self,
            selector: #selector(activeAppDidChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(activeSpaceDidChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange(_:)),
            name: AppSettings.settingsChangedNotification,
            object: nil
        )
    }

    @objc private func settingsDidChange(_ notification: Notification) {
        if !AppSettings.shared.isEnabled {
            panel.orderOut(nil)
        } else {
            refreshActiveWindow()
        }
    }

    private func startPollingTimer() {
        // Lightweight fallback sync (60ms) to ensure ultra-smooth tracking during window drags/resizes
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            self?.syncCurrentWindowPosition()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    @objc private func activeAppDidChange(_ notification: Notification) {
        refreshActiveWindow()
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        refreshActiveWindow()
    }

    func refreshActiveWindow() {
        guard isEnabled, AXIsProcessTrusted() else {
            panel.orderOut(nil)
            return
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            panel.orderOut(nil)
            return
        }

        let pid = frontApp.processIdentifier
        let myPID = ProcessInfo.processInfo.processIdentifier

        // Ignore ourselves or background agents without standard UI
        if pid == myPID || frontApp.bundleIdentifier == "com.apple.dock" {
            return
        }

        if pid != trackedPID {
            registerAXObserver(for: pid)
        }

        let menuItems = AXHelper.fetchTopLevelMenuBarItems(for: pid)
        if menuItems.isEmpty {
            panel.orderOut(nil)
            return
        }

        panel.updateMenuItems(menuItems, pid: pid)
        syncCurrentWindowPosition(for: pid)
    }

    func syncCurrentWindowPosition(for explicitPID: pid_t? = nil) {
        guard isEnabled, AXIsProcessTrusted() else {
            panel.orderOut(nil)
            return
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            panel.orderOut(nil)
            return
        }

        let pid = explicitPID ?? frontApp.processIdentifier
        if pid == ProcessInfo.processInfo.processIdentifier {
            return
        }

        if pid != trackedPID {
            refreshActiveWindow()
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        guard let focusedWindow = AXHelper.element(appElement, kAXFocusedWindowAttribute)
                ?? AXHelper.element(appElement, kAXMainWindowAttribute) else {
            panel.orderOut(nil)
            return
        }

        // Check if minimized or hidden
        if AXHelper.bool(focusedWindow, kAXMinimizedAttribute) == true {
            panel.orderOut(nil)
            return
        }

        // Check role is window (ignore sheets/popovers if they aren't standard windows)
        let role = AXHelper.string(focusedWindow, kAXRoleAttribute) ?? ""
        if role != kAXWindowRole {
            panel.orderOut(nil)
            return
        }

        guard let axFrame = AXHelper.frame(of: focusedWindow),
              axFrame.width > 100, axFrame.height > 60 else {
            panel.orderOut(nil)
            return
        }

        // Core rule: Hide when window is using > maxScreenPercentage (default 80%) of the screen or lacks space above titlebar
        let maxPct = AppSettings.shared.maxScreenPercentage
        if AXHelper.shouldHideMenu(
            for: focusedWindow,
            axFrame: axFrame,
            maxPercentage: maxPct,
            menuBarHeight: AttachedMenuPanel.barHeight + CGFloat(AppSettings.shared.verticalGap)
        ) {
            panel.orderOut(nil)
            return
        }

        panel.updatePosition(forWindowAXFrame: axFrame)
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func registerAXObserver(for pid: pid_t) {
        if let oldObserver = axObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(oldObserver),
                .commonModes
            )
            axObserver = nil
        }

        trackedPID = pid

        var newObserver: AXObserver?
        let callback: AXObserverCallback = { (_, _, notification, refcon) in
            guard let refcon = refcon else { return }
            let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            let notifName = notification as String
            if notifName == kAXFocusedWindowChangedNotification ||
               notifName == kAXWindowDeminiaturizedNotification ||
               notifName == kAXWindowMiniaturizedNotification ||
               notifName == kAXUIElementDestroyedNotification {
                tracker.refreshActiveWindow()
            } else {
                tracker.syncCurrentWindowPosition()
            }
        }

        guard AXObserverCreate(pid, callback, &newObserver) == .success,
              let observer = newObserver else {
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let notifications = [
            kAXWindowMovedNotification,
            kAXWindowResizedNotification,
            kAXFocusedWindowChangedNotification,
            kAXMainWindowChangedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
            kAXUIElementDestroyedNotification
        ]

        for notif in notifications {
            AXObserverAddNotification(observer, appElement, notif as CFString, selfPtr)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
        self.axObserver = observer
    }
}
