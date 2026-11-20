import Cocoa
import SwiftUI

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Configurações do MenuTogether"
        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
        }
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView())
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @State private var isEnabled: Bool = AppSettings.shared.isEnabled
    @State private var launchAtLogin: Bool = LaunchAtLoginManager.isEnabled
    @State private var maxScreenPercentage: Double = AppSettings.shared.maxScreenPercentage
    @State private var verticalGap: Double = AppSettings.shared.verticalGap
    @State private var horizontalOffset: Double = AppSettings.shared.horizontalOffset
    @State private var screens: [ScreenDescriptor] = AppSettings.connectedScreens()
    @State private var disabledMonitors: Set<String> = AppSettings.shared.disabledMonitors
    @State private var paneInstalled: Bool = SettingsView.checkPaneInstalled()

    static func checkPaneInstalled() -> Bool {
        let userPane = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/PreferencePanes/MenuTogether.prefPane")
        return FileManager.default.fileExists(atPath: userPane.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MenuTogether")
                        .font(.title2.bold())
                    Text("Mantém o menu do aplicativo junto da janela ativa")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Atalho: ⌃⌥⌘M")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
            }

            Divider()

            Toggle("Ativar MenuTogether (⌃⌥⌘M para alternar a qualquer momento)", isOn: $isEnabled)
                .font(.headline)
                .onChange(of: isEnabled) { newValue in
                    AppSettings.shared.isEnabled = newValue
                }

            Toggle("Iniciar automaticamente ao ligar o Mac (sem pedir confirmação)", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    LaunchAtLoginManager.isEnabled = newValue
                }

            GroupBox(label: Text("Monitores Ativos").font(.subheadline.bold())) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Escolha em quais monitores o menu acoplado deve aparecer:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(screens) { screen in
                        Toggle(isOn: Binding(
                            get: { !disabledMonitors.contains(screen.id) },
                            set: { enabled in
                                AppSettings.shared.setMonitor(screen.id, enabled: enabled)
                                disabledMonitors = AppSettings.shared.disabledMonitors
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
                        Button("Apenas Monitores Grandes (> 18\")") {
                            for s in screens {
                                AppSettings.shared.setMonitor(s.id, enabled: !s.isSmallMonitor)
                            }
                            disabledMonitors = AppSettings.shared.disabledMonitors
                        }
                        .controlSize(.small)

                        Button("Ativar em Todos") {
                            for s in screens {
                                AppSettings.shared.setMonitor(s.id, enabled: true)
                            }
                            disabledMonitors = AppSettings.shared.disabledMonitors
                        }
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(label: Text("Tamanho da Janela e Posicionamento").font(.subheadline.bold())) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Ocultar quando a janela usar mais de:")
                            Spacer()
                            Text("\(Int(maxScreenPercentage))% da tela")
                                .monospacedDigit()
                                .bold()
                        }
                        Slider(value: $maxScreenPercentage, in: 50...95, step: 5)
                            .onChange(of: maxScreenPercentage) { newValue in
                                AppSettings.shared.maxScreenPercentage = newValue
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Distância vertical acima da janela:")
                            Spacer()
                            Text("\(Int(verticalGap)) pt")
                                .monospacedDigit()
                        }
                        Slider(value: $verticalGap, in: 0...16, step: 1)
                            .onChange(of: verticalGap) { newValue in
                                AppSettings.shared.verticalGap = newValue
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Deslocamento horizontal ( a partir da borda esquerda):")
                            Spacer()
                            Text("\(Int(horizontalOffset)) pt")
                                .monospacedDigit()
                        }
                        Slider(value: $horizontalOffset, in: 0...120, step: 4)
                            .onChange(of: horizontalOffset) { newValue in
                                AppSettings.shared.horizontalOffset = newValue
                            }
                    }
                }
                .padding(8)
            }

            Divider()

            HStack {
                Image(systemName: paneInstalled ? "checkmark.seal.fill" : "gearshape.2")
                    .foregroundColor(paneInstalled ? .green : .secondary)
                Text(paneInstalled
                     ? "Painel instalado nos Ajustes do Sistema"
                     : "Painel dos Ajustes do Sistema não encontrado")
                    .font(.caption)
                Spacer()
                Button("Abrir nos Ajustes do Sistema") {
                    openInSystemSettings()
                }
            }
        }
        .padding(20)
        .frame(width: 520)
        .onReceive(NotificationCenter.default.publisher(for: AppSettings.settingsChangedNotification)) { _ in
            isEnabled = AppSettings.shared.isEnabled
            launchAtLogin = LaunchAtLoginManager.isEnabled
            maxScreenPercentage = AppSettings.shared.maxScreenPercentage
            verticalGap = AppSettings.shared.verticalGap
            horizontalOffset = AppSettings.shared.horizontalOffset
            disabledMonitors = AppSettings.shared.disabledMonitors
            screens = AppSettings.connectedScreens()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = AppSettings.connectedScreens()
        }
    }

    private func openInSystemSettings() {
        let userPane = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/PreferencePanes/MenuTogether.prefPane")
        if FileManager.default.fileExists(atPath: userPane.path) {
            NSWorkspace.shared.open(userPane)
        } else if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }
}
