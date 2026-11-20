import Cocoa
import PreferencePanes
import SwiftUI

@objc(MenuTogetherPrefPane)
public final class MenuTogetherPrefPane: NSPreferencePane {
    public override func loadMainView() -> NSView {
        let hostingView = NSHostingView(rootView: PrefPaneRootView())
        hostingView.frame = NSRect(x: 0, y: 0, width: 668, height: 500)
        self.mainView = hostingView
        return hostingView
    }
}

struct PrefPaneScreenItem: Identifiable {
    let id: String
    let name: String
    let resolution: String
    let diagonalInches: Double

    var formattedDiagonal: String {
        diagonalInches > 1 ? String(format: "%.1f\"", diagonalInches) : ""
    }

    var isSmallMonitor: Bool {
        diagonalInches > 0 && diagonalInches < 18.0
    }
}

struct PrefPaneRootView: View {
    private static let suiteName = "com.dansorrel.MenuTogether"
    private static let notificationName = Notification.Name("com.dansorrel.MenuTogether.settingsChanged")

    @State private var isEnabled: Bool = true
    @State private var launchAtLogin: Bool = true
    @State private var maxScreenPercentage: Double = 80.0
    @State private var verticalGap: Double = 2.0
    @State private var horizontalOffset: Double = 0.0
    @State private var disabledMonitors: Set<String> = []
    @State private var screens: [PrefPaneScreenItem] = PrefPaneRootView.loadScreens()

    private static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.dansorrel.MenuTogether.plist")
    }

    init() {
        let defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        let enabledVal = defaults.object(forKey: "isEnabled") as? Bool ?? true
        let loginVal = FileManager.default.fileExists(atPath: Self.launchAgentURL.path)
        let pctVal = defaults.double(forKey: "maxScreenPercentage")
        let gapVal = defaults.object(forKey: "verticalGap") != nil ? defaults.double(forKey: "verticalGap") : 2.0
        let hOffsetVal = defaults.object(forKey: "horizontalOffset") != nil ? defaults.double(forKey: "horizontalOffset") : 0.0
        let disabledArr = defaults.stringArray(forKey: "disabledMonitors") ?? []

        _isEnabled = State(initialValue: enabledVal)
        _launchAtLogin = State(initialValue: loginVal)
        _maxScreenPercentage = State(initialValue: pctVal > 0 ? pctVal : 80.0)
        _verticalGap = State(initialValue: gapVal)
        _horizontalOffset = State(initialValue: hOffsetVal)
        _disabledMonitors = State(initialValue: Set(disabledArr))
    }

    static func loadScreens() -> [PrefPaneScreenItem] {
        return NSScreen.screens.map { screen in
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            let mm = CGDisplayScreenSize(displayID)
            let diag = sqrt(mm.width * mm.width + mm.height * mm.height) / 25.4
            let name = screen.localizedName
            let w = Int(screen.frame.width)
            let h = Int(screen.frame.height)
            return PrefPaneScreenItem(
                id: name,
                name: name,
                resolution: "\(w)×\(h)",
                diagonalInches: diag
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("MenuTogether")
                        .font(.title2.bold())
                    Text("Mantém uma barra de menu acoplada acima da janela ativa nos monitores selecionados.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Atalho Global: ⌃⌥⌘M")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
            }

            Divider()

            Toggle("Ativar menu junto da janela ativa (ou use ⌃⌥⌘M a qualquer momento)", isOn: $isEnabled)
                .font(.headline)
                .onChange(of: isEnabled) { newValue in
                    saveAndNotify(key: "isEnabled", value: newValue)
                }

            Toggle("Iniciar automaticamente ao ligar o Mac", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    updateLaunchAgent(enabled: newValue)
                    saveAndNotify(key: "launchAtLogin", value: newValue)
                }

            GroupBox(label: Text("Monitores Habilitados").font(.subheadline.bold())) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Marque em quais monitores o menu acoplado deve funcionar (desmarque os monitores pequenos de 13\"):")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(screens) { screen in
                        Toggle(isOn: Binding(
                            get: { !disabledMonitors.contains(screen.id) },
                            set: { enabled in
                                if enabled {
                                    disabledMonitors.remove(screen.id)
                                } else {
                                    disabledMonitors.insert(screen.id)
                                }
                                saveAndNotify(key: "disabledMonitors", value: Array(disabledMonitors))
                            }
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: screen.isSmallMonitor ? "laptopcomputer" : "display")
                                    .foregroundColor(.accentColor)
                                Text(screen.name)
                                    .fontWeight(.medium)
                                if !screen.formattedDiagonal.isEmpty {
                                    Text("(\(screen.formattedDiagonal) • \(screen.resolution))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    HStack {
                        Button("Usar Apenas em Monitores Grandes (> 18\")") {
                            var newDisabled = Set<String>()
                            for s in screens where s.isSmallMonitor {
                                newDisabled.insert(s.id)
                            }
                            disabledMonitors = newDisabled
                            saveAndNotify(key: "disabledMonitors", value: Array(disabledMonitors))
                        }
                        .controlSize(.small)

                        Button("Habilitar Todos") {
                            disabledMonitors.removeAll()
                            saveAndNotify(key: "disabledMonitors", value: [String]())
                        }
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(label: Text("Limite de Tela e Posicionamento").font(.subheadline.bold())) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Ocultar menu acoplado se a janela ocupar mais de:")
                        Spacer()
                        Text("\(Int(maxScreenPercentage))% da tela")
                            .monospacedDigit()
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $maxScreenPercentage, in: 50...95, step: 5)
                        .onChange(of: maxScreenPercentage) { newValue in
                            saveAndNotify(key: "maxScreenPercentage", value: newValue)
                        }

                    HStack {
                        Text("Espaçamento vertical acima da janela:")
                        Spacer()
                        Text("\(Int(verticalGap)) pt")
                            .monospacedDigit()
                    }
                    Slider(value: $verticalGap, in: 0...16, step: 1)
                        .onChange(of: verticalGap) { newValue in
                            saveAndNotify(key: "verticalGap", value: newValue)
                        }

                    HStack {
                        Text("Deslocamento horizontal (da esquerda da janela):")
                        Spacer()
                        Text("\(Int(horizontalOffset)) pt")
                            .monospacedDigit()
                    }
                    Slider(value: $horizontalOffset, in: 0...120, step: 4)
                        .onChange(of: horizontalOffset) { newValue in
                            saveAndNotify(key: "horizontalOffset", value: newValue)
                        }
                }
                .padding(10)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 668, height: 500)
    }

    private func updateLaunchAgent(enabled: Bool) {
        let url = Self.launchAgentURL
        if enabled {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let plist: [String: Any] = [
                "Label": "com.dansorrel.MenuTogether",
                "ProgramArguments": [
                    "/Applications/MenuTogether.app/Contents/MacOS/MenuTogether",
                    "--launched-at-login"
                ],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive"
            ]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? data.write(to: url, options: .atomic)
            }
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func saveAndNotify(key: String, value: Any) {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else { return }
        defaults.set(value, forKey: key)
        defaults.synchronize()
        DistributedNotificationCenter.default().postNotificationName(
            Self.notificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
