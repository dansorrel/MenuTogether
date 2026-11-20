import Cocoa
import ApplicationServices

// MARK: - Models

struct MenuItemNode: Identifiable {
    let id = UUID()
    let title: String
    let isEnabled: Bool
    let isSeparator: Bool
    let shortcut: String?
    let axElement: AXUIElement?
    let children: [MenuItemNode]
}

// MARK: - Accessibility Helper

enum AXHelper {
    static func string(_ element: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success, let str = value as? String else { return nil }
        return str
    }

    static func bool(_ element: AXUIElement, _ attr: String) -> Bool? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success else { return nil }
        if let num = value as? NSNumber {
            return num.boolValue
        }
        return nil
    }

    static func int(_ element: AXUIElement, _ attr: String) -> Int? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success, let num = value as? NSNumber else { return nil }
        return num.intValue
    }

    static func element(_ element: AXUIElement, _ attr: String) -> AXUIElement? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success, let val = value, CFGetTypeID(val) == AXUIElementGetTypeID() else { return nil }
        return (val as! AXUIElement)
    }

    static func children(_ element: AXUIElement, _ attr: String = kAXChildrenAttribute) -> [AXUIElement] {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success, let arr = value as? [AXUIElement] else { return [] }
        return arr
    }

    static func point(_ element: AXUIElement, _ attr: String) -> CGPoint? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success, let val = value, CFGetTypeID(val) == AXValueGetTypeID() else { return nil }
        let axVal = val as! AXValue
        var pt = CGPoint.zero
        if AXValueGetValue(axVal, .cgPoint, &pt) {
            return pt
        }
        return nil
    }

    static func size(_ element: AXUIElement, _ attr: String) -> CGSize? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success, let val = value, CFGetTypeID(val) == AXValueGetTypeID() else { return nil }
        let axVal = val as! AXValue
        var sz = CGSize.zero
        if AXValueGetValue(axVal, .cgSize, &sz) {
            return sz
        }
        return nil
    }

    static func frame(of windowElement: AXUIElement) -> CGRect? {
        guard let pos = point(windowElement, kAXPositionAttribute),
              let sz = size(windowElement, kAXSizeAttribute) else {
            return nil
        }
        return CGRect(origin: pos, size: sz)
    }

    static func shouldHideMenu(for windowElement: AXUIElement, axFrame: CGRect, maxPercentage: Double, menuBarHeight: CGFloat) -> Bool {
        if let fs = bool(windowElement, "AXFullScreen"), fs {
            return true
        }
        if let subrole = string(windowElement, kAXSubroleAttribute), subrole == "AXFullScreenWindow" {
            return true
        }

        let ratioLimit = maxPercentage / 100.0
        let globalOriginY = NSScreen.screens.first?.frame.height ?? 0

        for screen in NSScreen.screens {
            // Convert NSScreen frames to CG / AX top-left coordinates
            let cgScreenRect = CGRect(
                x: screen.frame.origin.x,
                y: globalOriginY - screen.frame.origin.y - screen.frame.height,
                width: screen.frame.width,
                height: screen.frame.height
            )
            let cgVisibleRect = CGRect(
                x: screen.visibleFrame.origin.x,
                y: globalOriginY - screen.visibleFrame.origin.y - screen.visibleFrame.height,
                width: screen.visibleFrame.width,
                height: screen.frame.height
            )

            // Check if this is the screen containing the majority of the window
            let intersection = axFrame.intersection(cgScreenRect)
            guard !intersection.isNull, intersection.width * intersection.height > (axFrame.width * axFrame.height * 0.3) else {
                continue
            }

            // 0. Check if this monitor is enabled in AppSettings
            if !AppSettings.shared.isMonitorEnabled(screen.localizedName) {
                return true
            }

            let visibleHeight = screen.visibleFrame.height
            let visibleWidth = screen.visibleFrame.width
            let visibleArea = visibleWidth * visibleHeight
            let windowArea = axFrame.width * axFrame.height

            // 1. Check if window area exceeds the configured screen percentage (e.g. > 80% of the screen area)
            let areaRatio = windowArea / max(visibleArea, 1)
            let widthRatio = axFrame.width / max(visibleWidth, 1)
            let heightRatio = axFrame.height / max(visibleHeight, 1)

            // Hide if total window area exceeds maxPercentage (e.g. 80%), or if both width and height are practically maximized (> 92%)
            if areaRatio > ratioLimit || (widthRatio > 0.92 && heightRatio > 0.92) {
                return true
            }

            // 2. Safety check: if there is not enough room above the window's top edge before hitting the macOS Menu Bar,
            // hide the attached menu so it NEVER overlaps the window's close/minimize/zoom traffic light buttons!
            // Note: secondary monitors still have a 24-38pt macOS menu bar at the top even if visibleFrame doesn't subtract it.
            let menuBarInset = max(cgVisibleRect.minY - cgScreenRect.minY, 28.0)
            let safeTopY = cgScreenRect.minY + menuBarInset
            let availableSpaceAboveWindow = axFrame.minY - safeTopY
            if availableSpaceAboveWindow < (menuBarHeight + 2) {
                return true
            }

            return false
        }
        return false
    }

    static func fetchTopLevelMenuBarItems(for pid: pid_t) -> [MenuItemNode] {
        let appElement = AXUIElementCreateApplication(pid)
        guard let menuBar = element(appElement, kAXMenuBarAttribute) else { return [] }
        let items = children(menuBar)

        var nodes: [MenuItemNode] = []
        for item in items {
            let title = string(item, kAXTitleAttribute) ?? ""
            // Skip Apple menu ("Apple" or empty first icon)
            if title.isEmpty || title == "Apple" || title == "" {
                continue
            }
            let enabled = bool(item, kAXEnabledAttribute) ?? true
            nodes.append(MenuItemNode(
                title: title,
                isEnabled: enabled,
                isSeparator: false,
                shortcut: nil,
                axElement: item,
                children: []
            ))
        }
        return nodes
    }

    static func fetchSubmenuItems(from parentItem: AXUIElement, depth: Int = 0) -> [MenuItemNode] {
        guard depth < 4 else { return [] }
        let subElements = children(parentItem)
        // A MenuBarItem or MenuItem with a submenu usually has 1 child of role AXMenu
        var menuContainer: AXUIElement?
        for sub in subElements {
            if string(sub, kAXRoleAttribute) == kAXMenuRole {
                menuContainer = sub
                break
            }
        }
        guard let menu = menuContainer else { return [] }

        let rawItems = children(menu)
        var result: [MenuItemNode] = []

        for item in rawItems {
            let role = string(item, kAXRoleAttribute) ?? ""
            let title = string(item, kAXTitleAttribute) ?? ""

            if title.isEmpty && role == kAXMenuItemRole {
                // Usually a separator in AXMenu
                result.append(MenuItemNode(
                    title: "",
                    isEnabled: false,
                    isSeparator: true,
                    shortcut: nil,
                    axElement: nil,
                    children: []
                ))
                continue
            }

            let enabled = bool(item, kAXEnabledAttribute) ?? true
            let shortcut = formatShortcut(for: item)
            let subChildren = fetchSubmenuItems(from: item, depth: depth + 1)

            result.append(MenuItemNode(
                title: title,
                isEnabled: enabled,
                isSeparator: false,
                shortcut: shortcut,
                axElement: item,
                children: subChildren
            ))
        }
        return result
    }

    private static func formatShortcut(for item: AXUIElement) -> String? {
        guard let cmdChar = string(item, "AXMenuItemCmdChar"), !cmdChar.isEmpty else {
            return nil
        }
        let mods = int(item, "AXMenuItemCmdModifiers") ?? 0
        // AXMenuItemCmdModifiers bitmask:
        // 0: Command
        // 1 << 0 (1): Shift
        // 1 << 1 (2): Option
        // 1 << 2 (4): Control
        // 1 << 3 (8): No Command
        var symbols = ""
        if (mods & (1 << 2)) != 0 { symbols += "⌃" }
        if (mods & (1 << 1)) != 0 { symbols += "⌥" }
        if (mods & (1 << 0)) != 0 { symbols += "⇧" }
        if (mods & (1 << 3)) == 0 { symbols += "⌘" }
        return symbols + cmdChar.uppercased()
    }
}
