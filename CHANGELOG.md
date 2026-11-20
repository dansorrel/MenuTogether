# Changelog

Todas as mudanças notáveis neste projeto são documentadas neste arquivo.

## [1.2.0] - 2026-11-20

### Adicionado
- **Instalação em `/Applications` e Inicialização Automática Silenciosa**: Instalado diretamente em `/Applications/MenuTogether.app` com `LaunchAgent` (`~/Library/LaunchAgents/com.dansorrel.MenuTogether.plist`) configurado com `--launched-at-login` e assinatura por identificador estável (`designated => identifier "com.dansorrel.MenuTogether"`), iniciando junto com o Mac sem exibir pop-ups de autorização.
- **Ícone Nativo Personalizado (`AppIcon.icns`)**: Gerador vetorial em CoreGraphics (`scripts/generate_icon.swift`) criando ícone de alta resolução para o app e para o painel de preferências.
- **Seleção Inteligente Multi-Monitor**: Detecção automática do tamanho físico (em polegadas via `CGDisplayScreenSize`) e resolução de cada monitor conectado, permitindo escolher em quais monitores o menu acoplado aparece (desativando automaticamente monitores `< 18"` por padrão).
- **Atalho Global de Teclado (`⌃⌥⌘M`)**: Alternância imediata entre ativo e pausado de qualquer lugar do macOS via Carbon `RegisterEventHotKey`.
- **Ajuste Fino de Deslocamento Horizontal e Vertical**: Sliders para calibrar a distância vertical acima da janela (`0` a `16 pt`) e o deslocamento horizontal (`0` a `120 pt`).

### Corrigido
- Proteção reforçada de margem da barra de menu em monitores secundários para nunca sobrepor os botões de fechar/minimizar/maximizar da janela.

## [1.1.0] - 2026-11-20

### Adicionado
- **Limite Configurável de Uso da Tela (Padrão 80%)**: Oculta o menu acoplado automaticamente quando a janela ativa ocupa mais de 80% da área/altura visível da tela.
- **Painel nos Ajustes do Sistema (`MenuTogether.prefPane`)**: Bundle nativo instalado em `~/Library/PreferencePanes` com sincronização em tempo real via `DistributedNotificationCenter`.

## [1.0.0] - 2026-11-20

### Adicionado
- Barra de menu flutuante (`AttachedMenuPanel`) acoplada acima da janela ativa em foco.
- Leitura completa da árvore `AXMenuBar` do aplicativo ativo, incluindo submenus, separadores, atalhos de teclado e disparo nativo via `AXPress`.
- Rastreamento contínuo de foco, movimento e redimensionamento de janelas (`WindowTracker`).
