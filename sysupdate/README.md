# sysupdate

Um único comando (`sysupdate`, ou `sysup`) que atualiza tudo o que está instalado na máquina: gestor de pacotes do sistema, ferramentas de programação, extensões e Claude Code. Os passos independentes correm em paralelo, e no fim aparece um resumo com os passos mais lentos e os que falharam.

Há uma versão para cada sistema:

| Sistema | Ficheiro | Tipo |
|---|---|---|
| Windows | [`windows/install-sysupdate.ps1`](windows/install-sysupdate.ps1) | função PowerShell 7 (também incluída no [`Microsoft.PowerShell_profile.ps1`](../Microsoft.PowerShell_profile.ps1)) |
| macOS | [`macos/sysupdate`](macos/sysupdate) | script bash (compatível com o bash 3.2 do macOS) |
| Omarchy / Arch | [`omarchy/sysupdate`](omarchy/sysupdate) | script bash |

## Instalar

### Windows (PowerShell 7)

```powershell
# descarregar o instalador e correr
Invoke-WebRequest https://raw.githubusercontent.com/MrJazzMan/powershell-profile/master/sysupdate/windows/install-sysupdate.ps1 -OutFile $HOME\Downloads\install-sysupdate.ps1
pwsh -ExecutionPolicy Bypass -File $HOME\Downloads\install-sysupdate.ps1
```

Se não houver PowerShell 7: `winget install --id Microsoft.PowerShell -e`. Quem já usa o `Microsoft.PowerShell_profile.ps1` deste repo não precisa de instalar nada: a função já lá está.

### macOS e Omarchy

```bash
curl -fsSL https://raw.githubusercontent.com/MrJazzMan/powershell-profile/master/sysupdate/install.sh | bash
```

O instalador deteta o sistema, copia o script certo para `~/.local/bin/sysupdate` e cria o atalho `sysup`. Não precisa de sudo. Pode ser corrido outra vez para atualizar o próprio `sysupdate`.

## O que cada versão faz

| | Windows | macOS | Omarchy |
|---|---|---|---|
| Sistema / pacotes | winget (fontes + `upgrade --all`) | Homebrew (fórmulas + casks `--greedy`) | `omarchy-update -y` (pacman, AUR, mise, migrações, snapshot); em Arch simples, `pacman -Syu` + `yay -Sua` |
| Lojas / extra | | Mac App Store (`mas`) | Flatpak |
| Módulos / pacotes de linguagem | Módulos PowerShell | Pacotes Python `--user` (pip) | (mise, dentro do `omarchy-update`) |
| npm global, ferramentas Go, extensões VS Code | sim | sim | sim |
| Atualizações do SO | Assinaturas do Defender | Só **verifica** atualizações do macOS | Só **verifica** firmware (fwupd) |
| Bun, Claude Code | sim | sim | sim |
| Limpeza | `%TEMP%` (> 24 h) | `brew cleanup` | (o `omarchy-update` já limpa a cache e os órfãos) |

Os passos cujas ferramentas não estão instaladas são saltados automaticamente. Cada passo pode também ser saltado à mão:

- **Windows:** `-SkipWinget -SkipModules -SkipNpm -SkipBun -SkipGo -SkipVSCode -SkipClaudeCode -SkipDefender -SkipCleanup`
- **macOS:** `--skip-brew --skip-mas --skip-npm --skip-go --skip-vscode --skip-pip --skip-macos --skip-bun --skip-claude --skip-cleanup`
- **Omarchy:** `--skip-system --skip-npm --skip-go --skip-vscode --skip-flatpak --skip-firmware --skip-bun --skip-claude`

## Decisões de desenho

- **Nada que obrigue a reiniciar é instalado sem pedir.** As atualizações do macOS e o firmware são só reportados, com a indicação de como instalar.
- **O Claude Code e o Bun são atualizados pelo sítio de onde vieram.** Se foram instalados por winget, Homebrew ou pacman, o passo do gestor de pacotes já trata deles; só as instalações nativas ou por npm são atualizadas à parte.
- **No Omarchy, o sistema fica a cargo do `omarchy-update`.** Ele já faz as coisas na ordem certa (snapshot, keyring, pacman, migrações, AUR, verificação do arranque). Repetir esses passos aqui só criaria conflitos.

## Manter as versões alinhadas

A função para Windows existe em dois sítios: no `Microsoft.PowerShell_profile.ps1` e embutida no `windows/install-sysupdate.ps1`. Ao alterar uma, alterar a outra.
