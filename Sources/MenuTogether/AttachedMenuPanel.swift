import Cocoa
import ApplicationServices

final class AttachedMenuPanel: NSPanel {
    static let barHeight: CGFloat = 26

    private let visualEffectView = NSVisualEffectView()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private var topNodes: [MenuItemNode] = []
    private var currentPID: pid_t = 0

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: Self.barHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.ignoresMouseEvents = false

        setupUI()
    }

    private func setupUI() {
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 7
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 0.5
        visualEffectView.layer?.borderColor = NSColor.separatorColor.cgColor

        self.contentView = visualEffectView

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 2
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: visualEffectView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])
    }

    func updateMenuItems(_ nodes: [MenuItemNode], pid: pid_t) {
        let newTitles = nodes.map { $0.title }
        let oldTitles = topNodes.map { $0.title }
        if pid == currentPID && newTitles == oldTitles && !nodes.isEmpty {
            // Still update AX references silently
            self.topNodes = nodes
            return
        }

        self.currentPID = pid
        self.topNodes = nodes

        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, node) in nodes.enumerated() {
            let btn = MenuBarButton(title: node.title, isBold: index == 0)
            btn.tag = index
            btn.target = self
            btn.action = #selector(menuBarButtonClicked(_:))
            stackView.addArrangedSubview(btn)
        }

        stackView.layoutSubtreeIfNeeded()
    }

    func updatePosition(forWindowAXFrame axFrame: CGRect) {
        guard let primaryScreen = NSScreen.screens.first else { return }
        let primaryHeight = primaryScreen.frame.height

        // Convert AX top-left coordinates to Cocoa bottom-left coordinates
        let cocoaWindowTopY = primaryHeight - axFrame.origin.y
        let cocoaWindowX = axFrame.origin.x

        // Required width based on buttons, bounded by window width
        let fittingWidth = max(stackView.fittingSize.width + 8, 120)
        let panelWidth = min(max(fittingWidth, 160), axFrame.width)

        // Position directly above the window's top edge (never clamped down over the window buttons)
        let gap = CGFloat(AppSettings.shared.verticalGap)
        let hOffset = CGFloat(AppSettings.shared.horizontalOffset)
        let targetY = cocoaWindowTopY + gap
        let targetX = cocoaWindowX + hOffset

        let newFrame = NSRect(
            x: round(targetX),
            y: round(targetY),
            width: round(panelWidth),
            height: Self.barHeight
        )

        if self.frame != newFrame {
            self.setFrame(newFrame, display: true)
        }
    }

    @objc private func menuBarButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0 && index < topNodes.count else { return }
        let topNode = topNodes[index]
        guard let topAX = topNode.axElement else { return }

        let children = AXHelper.fetchSubmenuItems(from: topAX)
        if children.isEmpty {
            // If no submenu children found, perform AXPress directly on the top bar item
            AXUIElementPerformAction(topAX, kAXPressAction as CFString)
            return
        }

        let menu = buildNSMenu(title: topNode.title, items: children)
        let location = NSPoint(x: 0, y: -4)
        menu.popUp(positioning: nil, at: location, in: sender)
    }

    private func buildNSMenu(title: String, items: [MenuItemNode]) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false

        for item in items {
            if item.isSeparator {
                menu.addItem(.separator())
                continue
            }

            let titleWithShortcut: String
            if let sc = item.shortcut, !sc.isEmpty {
                titleWithShortcut = "\(item.title)   (\(sc))"
            } else {
                titleWithShortcut = item.title
            }

            let nsItem = NSMenuItem(title: titleWithShortcut, action: nil, keyEquivalent: "")
            nsItem.isEnabled = item.isEnabled

            if !item.children.isEmpty {
                let subMenu = buildNSMenu(title: item.title, items: item.children)
                nsItem.submenu = subMenu
            } else if item.isEnabled, let axElem = item.axElement {
                nsItem.target = self
                nsItem.action = #selector(triggerAXMenuItem(_:))
                nsItem.representedObject = axElem
            }

            menu.addItem(nsItem)
        }

        return menu
    }

    @objc private func triggerAXMenuItem(_ sender: NSMenuItem) {
        guard let elementObj = sender.representedObject else { return }
        let axElement = elementObj as! AXUIElement

        // Activate target app first so the action applies cleanly to its key window
        if let app = NSRunningApplication(processIdentifier: currentPID) {
            app.activate(options: [.activateIgnoringOtherApps])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            AXUIElementPerformAction(axElement, kAXPressAction as CFString)
        }
    }
}

// MARK: - Custom Compact Button for Menu Bar

final class MenuBarButton: NSButton {
    init(title: String, isBold: Bool) {
        super.init(frame: .zero)
        self.title = title
        self.bezelStyle = .recessed
        self.isBordered = false
        self.setButtonType(.momentaryPushIn)
        self.font = isBold
            ? NSFont.systemFont(ofSize: 13, weight: .semibold)
            : NSFont.systemFont(ofSize: 13, weight: .regular)
        self.contentTintColor = .labelColor
        self.translatesAutoresizingMaskIntoConstraints = false

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
        self.wantsLayer = true
        self.layer?.cornerRadius = 4
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width + 12, height: 20)
    }

    override func mouseEntered(with event: NSEvent) {
        self.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
}
