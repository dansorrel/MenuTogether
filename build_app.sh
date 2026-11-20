#!/bin/bash
set -e

APP_NAME="MenuTogether"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

if [ ! -f "Assets/AppIcon.icns" ]; then
    echo "0. Gerando ícones do aplicativo..."
    swift scripts/generate_icon.swift
    iconutil -c icns AppIcon.iconset -o Assets/AppIcon.icns
    rm -rf AppIcon.iconset
fi

echo "1. Compilando ${APP_NAME} (Release)..."
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${BIN_PATH}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp "Assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.dansorrel.MenuTogether</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>O MenuTogether precisa de acesso de Acessibilidade para ler o menu do aplicativo ativo e acompanhar a posição da janela.</string>
</dict>
</plist>
EOF

xattr -cr "${APP_BUNDLE}"
codesign --force --deep --sign - -r="designated => identifier \"com.dansorrel.MenuTogether\"" "${APP_BUNDLE}"
echo "✅ ${APP_BUNDLE} gerado com sucesso!"

# ---------------------------------------------------------
# 2. Compilar e Instalar Painel dos Ajustes do Sistema (.prefPane)
# ---------------------------------------------------------
PANE_NAME="MenuTogether"
PANE_BUNDLE="${PANE_NAME}.prefPane"
PANE_CONTENTS="${PANE_BUNDLE}/Contents"
PANE_MACOS="${PANE_CONTENTS}/MacOS"
PANE_RESOURCES="${PANE_CONTENTS}/Resources"

echo "2. Compilando painel de Ajustes do Sistema (${PANE_BUNDLE})..."
rm -rf "${PANE_BUNDLE}"
mkdir -p "${PANE_MACOS}"
mkdir -p "${PANE_RESOURCES}"

SDK_PATH=$(xcrun --show-sdk-path)

swiftc -emit-library \
    -target arm64-apple-macosx13.0 \
    -sdk "${SDK_PATH}" \
    -module-name MenuTogetherPrefPane \
    -framework Cocoa \
    -framework PreferencePanes \
    -framework SwiftUI \
    -Xlinker -bundle \
    -o "${PANE_MACOS}/${PANE_NAME}" \
    PrefPane/MenuTogetherPrefPane.swift

cp "Assets/AppIcon-128.png" "${PANE_RESOURCES}/icon.png"

cat > "${PANE_CONTENTS}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${PANE_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.dansorrel.MenuTogether.prefpane</string>
    <key>CFBundleName</key>
    <string>${PANE_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${PANE_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>CFBundleIconFile</key>
    <string>icon.png</string>
    <key>NSPrincipalClass</key>
    <string>MenuTogetherPrefPane</string>
    <key>NSMainNibFile</key>
    <string></string>
    <key>NSPrefPaneIconFile</key>
    <string>icon.png</string>
    <key>NSPrefPaneIconLabel</key>
    <string>MenuTogether</string>
</dict>
</plist>
EOF

xattr -cr "${PANE_BUNDLE}"
codesign --force --deep --sign - "${PANE_BUNDLE}"

USER_PREFPANES_DIR="${HOME}/Library/PreferencePanes"
mkdir -p "${USER_PREFPANES_DIR}"
rm -rf "${USER_PREFPANES_DIR}/${PANE_BUNDLE}"
cp -R "${PANE_BUNDLE}" "${USER_PREFPANES_DIR}/${PANE_BUNDLE}"

echo "✅ ${PANE_BUNDLE} compilado e instalado em ${USER_PREFPANES_DIR}/${PANE_BUNDLE}!"

# ---------------------------------------------------------
# 3. Instalar em /Applications e configurar LaunchAgent (Início Automático)
# ---------------------------------------------------------
INSTALL_APP_PATH="/Applications/${APP_BUNDLE}"
echo "3. Instalando ${APP_BUNDLE} em /Applications..."
killall "${APP_NAME}" 2>/dev/null || true
sleep 0.3

rm -rf "${INSTALL_APP_PATH}"
cp -R "${APP_BUNDLE}" "${INSTALL_APP_PATH}"
xattr -cr "${INSTALL_APP_PATH}"
codesign --force --deep --sign - -r="designated => identifier \"com.dansorrel.MenuTogether\"" "${INSTALL_APP_PATH}"

LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LAUNCH_AGENT_PLIST="${LAUNCH_AGENTS_DIR}/com.dansorrel.MenuTogether.plist"
mkdir -p "${LAUNCH_AGENTS_DIR}"

cat > "${LAUNCH_AGENT_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>KeepAlive</key>
	<false/>
	<key>Label</key>
	<string>com.dansorrel.MenuTogether</string>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Applications/MenuTogether.app/Contents/MacOS/MenuTogether</string>
		<string>--launched-at-login</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
EOF

tccutil reset Accessibility com.dansorrel.MenuTogether 2>/dev/null || true
launchctl unload "${LAUNCH_AGENT_PLIST}" 2>/dev/null || true
launchctl load -w "${LAUNCH_AGENT_PLIST}" 2>/dev/null || open "${INSTALL_APP_PATH}"

echo "✅ Instalado em ${INSTALL_APP_PATH}"
echo "✅ Inicialização automática configurada em ${LAUNCH_AGENT_PLIST}"
echo "🚀 ${APP_NAME} está rodando a partir de /Applications!"
