# ------------------------------------------
# Miguel – Git Shortcuts & Snapshot Utility
# ------------------------------------------

# Caminho para Notepad++
$global:NPP_PATH = "C:\Program Files\Notepad++\notepad++.exe"

# Suporta múltiplos ficheiros e argumentos (ex: npp arq1.txt arq2.txt)
function npp {
    if (Test-Path $NPP_PATH) {
        & $NPP_PATH $args
    } else {
        Write-Host "Notepad++ não foi encontrado em: $NPP_PATH" -ForegroundColor Red
    }
}

# ------------------------------------------
# Snapshot rápido (add + commit automático)
# ------------------------------------------
function gsnap {
    param([string]$Message = "")

    # Verifica se estamos dentro de um repositório Git
    git rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro: Esta pasta não é um repositório Git." -ForegroundColor Red
        return
    }

    $status = git status --porcelain
    if (-not $status) {
        Write-Host "Nenhuma alteração para guardar (working tree clean)." -ForegroundColor Yellow
        return
    }

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
        $Message = "[snapshot] $timestamp"
    }

    git add .
    git commit -m $Message
    Write-Host "Snapshot criado ✔ → $Message" -ForegroundColor Green
}

# ------------------------------------------
# Git Helpers – Miguel
# ------------------------------------------

function gs   { git status }
function gaa  { git add . }

function gadd {
    param([string]$Path = ".")
    git add $Path
}

function gcm {
    param(
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]]$Message
    )
    # Permite escrever gcm Mensagem sem aspas obrigatórias caso seja uma frase simples
    $fullMsg = $Message -join " "
    git commit -m $fullMsg
}

# Vista de log mais legível e com gráfico de branches
function glg  { git log --graph --oneline --decorate }

function gpsh { git push }
function gpll { git pull }

function gco {
    param([string]$Branch)
    git checkout $Branch
}

function gcb {
    param([string]$Branch)
    git checkout -b $Branch
}

# ------------------------------------------
# Extras Úteis para o Dia a Dia
# ------------------------------------------

# Recarregar o perfil rapidamente após edições
function Reload-Profile {
    . $PROFILE
    Write-Host "Perfil recarregado!" -ForegroundColor Green
}
Set-Alias -Name reload -Value Reload-Profile

# Criar pasta e entrar nela imediatamente
function mkcd {
    param([Parameter(Mandatory = $true)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -Path $Path
}

# Update ao Powershell
function Update-PS {
    Write-Host "A verificar atualizações via WinGet..." -ForegroundColor Cyan
    winget source update | Out-Null
    winget upgrade --id Microsoft.PowerShell
}

function SYSUPDATE {
    param(
        [switch]$SkipWinget,   # Salta winget (fontes + pacotes)
        [switch]$SkipModules,  # Salta módulos PowerShell
        [switch]$SkipNpm,      # Salta npm global packages
        [switch]$SkipVSCode,      # Salta extensões do VS Code
        [switch]$SkipClaudeCode,  # Salta Claude Code CLI
        [switch]$SkipDefender,    # Salta Windows Defender signatures
        [switch]$SkipCleanup      # Salta limpeza de ficheiros temporários
    )

    $start = Get-Date
    $step  = 0
    $total = 8

    function Write-Step {
        param([string]$Label)
        $script:step++
        Write-Host "`n[$script:step/$total] $Label" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "══════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "  🔄  SYSUPDATE  –  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════" -ForegroundColor DarkCyan

    function Write-Skip {
        param([string]$Label)
        $script:step++
        Write-Host "`n[$script:step/$total] " -NoNewline -ForegroundColor DarkGray
        Write-Host "[skip] " -NoNewline -ForegroundColor DarkYellow
        Write-Host $Label -ForegroundColor DarkGray
    }

    # 1. Sincronizar fontes winget
    if (-not $SkipWinget) {
        Write-Step "A sincronizar fontes winget..."
        winget source update
    } else { Write-Skip "winget – fontes" }

    # 2. Atualizar todos os pacotes winget (sem prompts interactivos)
    if (-not $SkipWinget) {
        Write-Step "A atualizar pacotes winget..."
        winget upgrade --all --include-unknown `
            --accept-source-agreements `
            --accept-package-agreements
    } else { Write-Skip "winget – pacotes" }

    # 3. Módulos PowerShell
    if (-not $SkipModules) {
        Write-Step "A atualizar módulos PowerShell..."
        Update-Module -AcceptLicense -ErrorAction SilentlyContinue
    } else { Write-Skip "módulos PowerShell" }

    # 4. npm global packages
    if (-not $SkipNpm -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Step "A atualizar npm global packages..."
        npm update -g --loglevel=error
    } else { Write-Skip "npm global packages" }

    # 5. Extensões do VS Code
    if (-not $SkipVSCode -and (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Step "A atualizar extensões do VS Code..."
        code --update-extensions 2>$null
    } else { Write-Skip "extensões VS Code" }

    # 6. Claude Code CLI
    if (-not $SkipClaudeCode -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Step "A atualizar Claude Code CLI..."
        npm install -g @anthropic-ai/claude-code --loglevel=error
    } else { Write-Skip "Claude Code CLI" }

    # 7. Windows Defender signatures
    if (-not $SkipDefender) {
        Write-Step "A atualizar Windows Defender signatures..."
        Update-MpSignature -ErrorAction SilentlyContinue
    } else { Write-Skip "Windows Defender signatures" }

    # 8. Limpeza de ficheiros temporários
    if (-not $SkipCleanup) {
        Write-Step "A limpar ficheiros temporários..."
        $before = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue |
                   Measure-Object -Property Length -Sum).Sum
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        $freed = [math]::Round(($before / 1MB), 1)
        Write-Host "   Libertados ~$freed MB" -ForegroundColor DarkGray
    } else { Write-Skip "limpeza de temporários" }

    $elapsed = (Get-Date) - $start
    Write-Host ""
    Write-Host "✔  Concluído em $([math]::Round($elapsed.TotalSeconds))s" -ForegroundColor Green

    # Aviso se o PowerShell foi actualizado e precisa de reinício
    $installedPS = (winget list --id Microsoft.PowerShell 2>$null |
                    Select-String '\d+\.\d+\.\d+' | ForEach-Object {
                        $_.Matches[0].Value }) | Select-Object -Last 1
    if ($installedPS -and $installedPS -ne $PSVersionTable.PSVersion.ToString()) {
        Write-Host ""
        Write-Host "  ⚠  PowerShell actualizado: $($PSVersionTable.PSVersion) → $installedPS" -ForegroundColor DarkYellow
        Write-Host "     Reinicia o terminal para aplicar." -ForegroundColor DarkYellow
    }

    Write-Host "══════════════════════════════════════`n" -ForegroundColor DarkCyan
}
Set-Alias -Name sysup -Value SYSUPDATE