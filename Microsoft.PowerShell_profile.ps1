# ------------------------------------------
# Miguel – Git Shortcuts & Snapshot Utility
# ------------------------------------------

# Path to Notepad++
$global:NPP_PATH = "C:\Program Files\Notepad++\notepad++.exe"

# Supports multiple files and arguments (e.g. npp file1.txt file2.txt)
function npp {
    if (Test-Path $NPP_PATH) {
        & $NPP_PATH $args
    } else {
        Write-Host "Notepad++ not found at: $NPP_PATH" -ForegroundColor Red
    }
}

# ------------------------------------------
# Quick Snapshot (auto add + commit)
# ------------------------------------------
function gsnap {
    param([string]$Message = "")

    # Check if we are inside a Git repository
    git rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: This folder is not a Git repository." -ForegroundColor Red
        return
    }

    $status = git status --porcelain
    if (-not $status) {
        Write-Host "Nothing to snapshot (working tree clean)." -ForegroundColor Yellow
        return
    }

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
        $Message = "[snapshot] $timestamp"
    }

    git add .
    git commit -m $Message
    Write-Host "Snapshot created ✔ → $Message" -ForegroundColor Green
}

# ------------------------------------------
# Git Helpers
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
    # Allows writing gcm Message without mandatory quotes for simple sentences
    $fullMsg = $Message -join " "
    git commit -m $fullMsg
}

# Readable log view with branch graph
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
# Useful Day-to-Day Extras
# ------------------------------------------

# Quickly reload the profile after edits
function Reload-Profile {
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}
Set-Alias -Name reload -Value Reload-Profile

# Create a folder and immediately enter it
function mkcd {
    param([Parameter(Mandatory = $true)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -Path $Path
}

# Update PowerShell itself via WinGet
function Update-PS {
    Write-Host "Checking for updates via WinGet..." -ForegroundColor Cyan
    winget source update | Out-Null
    winget upgrade --id Microsoft.PowerShell
}

function SYSUPDATE {
    param(
        [switch]$SkipWinget,      # Skip winget (source sync + package upgrades)
        [switch]$SkipModules,     # Skip PowerShell modules
        [switch]$SkipNpm,         # Skip npm global packages
        [switch]$SkipVSCode,      # Skip VS Code extensions
        [switch]$SkipClaudeCode,  # Skip Claude Code CLI
        [switch]$SkipDefender,    # Skip Windows Defender signatures
        [switch]$SkipCleanup      # Skip temporary file cleanup
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

    # 1. Sync winget sources
    if (-not $SkipWinget) {
        Write-Step "Syncing winget sources..."
        winget source update
    } else { Write-Skip "winget – sources" }

    # 2. Upgrade all winget packages (no interactive prompts)
    if (-not $SkipWinget) {
        Write-Step "Upgrading winget packages..."
        winget upgrade --all --include-unknown `
            --accept-source-agreements `
            --accept-package-agreements
    } else { Write-Skip "winget – packages" }

    # 3. PowerShell modules
    if (-not $SkipModules) {
        Write-Step "Updating PowerShell modules..."
        Update-Module -AcceptLicense -ErrorAction SilentlyContinue
    } else { Write-Skip "PowerShell modules" }

    # 4. npm global packages
    if (-not $SkipNpm -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Step "Updating npm global packages..."
        npm update -g --loglevel=error
    } else { Write-Skip "npm global packages" }

    # 5. VS Code extensions
    if (-not $SkipVSCode -and (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Step "Updating VS Code extensions..."
        code --update-extensions 2>$null
    } else { Write-Skip "VS Code extensions" }

    # 6. Claude Code CLI
    if (-not $SkipClaudeCode -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Step "Updating Claude Code CLI..."
        npm install -g @anthropic-ai/claude-code --loglevel=error
    } else { Write-Skip "Claude Code CLI" }

    # 7. Windows Defender signatures
    if (-not $SkipDefender) {
        Write-Step "Updating Windows Defender signatures..."
        Update-MpSignature -ErrorAction SilentlyContinue
    } else { Write-Skip "Windows Defender signatures" }

    # 8. Temporary file cleanup
    if (-not $SkipCleanup) {
        Write-Step "Cleaning up temporary files..."
        $before = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue |
                   Measure-Object -Property Length -Sum).Sum
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        $freed = [math]::Round(($before / 1MB), 1)
        Write-Host "   Freed ~$freed MB" -ForegroundColor DarkGray
    } else { Write-Skip "temporary file cleanup" }

    $elapsed = (Get-Date) - $start
    Write-Host ""
    Write-Host "✔  Done in $([math]::Round($elapsed.TotalSeconds))s" -ForegroundColor Green

    # Warn if PowerShell was updated and needs a restart
    $installedPS = (winget list --id Microsoft.PowerShell 2>$null |
                    Select-String '\d+\.\d+\.\d+' | ForEach-Object {
                        $_.Matches[0].Value }) | Select-Object -Last 1
    if ($installedPS -and $installedPS -ne $PSVersionTable.PSVersion.ToString()) {
        Write-Host ""
        Write-Host "  ⚠  PowerShell updated: $($PSVersionTable.PSVersion) → $installedPS" -ForegroundColor DarkYellow
        Write-Host "     Restart your terminal to apply." -ForegroundColor DarkYellow
    }

    Write-Host "══════════════════════════════════════`n" -ForegroundColor DarkCyan
}
Set-Alias -Name sysup -Value SYSUPDATE
