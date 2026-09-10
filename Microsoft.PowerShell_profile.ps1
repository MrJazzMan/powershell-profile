# ==============================================
# Miguel's PowerShell Profile
# ==============================================

# ------------------------------------------
# Path to Notepad++
# ------------------------------------------
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

function gs    { git status }
function ga    { git add . }
function gaa   { git add . }

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

function gcom {
    git add .
    git commit -m ($args -join ' ')
}

function lazyg {
    git add .
    git commit -m ($args -join ' ')
    git push
}

function gcl   { git clone @args }

# Readable log view with branch graph
function glg   { git log --graph --oneline --decorate }

function gpsh  { git push }
function gpush { git push @args }
function gpll  { git pull }
function gpull { git pull @args }

function gco {
    param([string]$Branch)
    git checkout $Branch
}

function gcb {
    param([string]$Branch)
    git checkout -b $Branch
}

# ------------------------------------------
# Navigation Shortcuts
# ------------------------------------------

function docs  { Set-Location -Path ([Environment]::GetFolderPath('MyDocuments')) }
function dtop  { Set-Location -Path ([Environment]::GetFolderPath('Desktop')) }

function la    { Get-ChildItem | Format-Table -AutoSize }
function ll    { Get-ChildItem -Force | Format-Table -AutoSize }

# Create a folder and immediately enter it
function mkcd {
    param([Parameter(Mandatory = $true)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -Path $Path
}

# ------------------------------------------
# Unix-style Utilities
# ------------------------------------------

# Create a file or update its timestamp
function touch {
    param([Parameter(Mandatory)][string]$File)
    if (Test-Path -Path $File) {
        (Get-Item -Path $File).LastWriteTime = Get-Date
    } else {
        New-Item -Path $File -ItemType File -Force | Out-Null
    }
}

# Create a new empty file
function nf {
    param([Parameter(Mandatory)][string]$Name)
    New-Item -ItemType File -Path . -Name $Name -Force | Out-Null
}

# Recursively find files matching a name pattern
function ff {
    param([Parameter(Mandatory)][string]$Name)
    Get-ChildItem -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
}

# Search files or piped input with regex
function grep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Pattern,
        [Parameter(Position = 1)][string]$Path,
        [Parameter(ValueFromPipeline)][object]$InputObject
    )

    begin { $pipelineInput = [System.Collections.Generic.List[object]]::new() }
    process {
        if ($PSBoundParameters.ContainsKey('InputObject')) { $pipelineInput.Add($InputObject) }
    }
    end {
        if ($Path) {
            Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
                Select-String -Pattern $Pattern
        } elseif ($pipelineInput.Count -gt 0) {
            $pipelineInput | Select-String -Pattern $Pattern
        } else {
            Write-Error 'Usage: grep <pattern> [path] or pipe input to grep'
        }
    }
}

# Show first N lines of a file (default 10)
function head {
    param([Parameter(Mandatory)][string]$Path, [int]$n = 10)
    Get-Content -Path $Path -Head $n
}

# Show last N lines of a file; -f to follow
function tail {
    param([Parameter(Mandatory)][string]$Path, [int]$n = 10, [switch]$f)
    Get-Content -Path $Path -Tail $n -Wait:$f
}

# Find and replace text inside a file
function sed {
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Find,
        [Parameter(Mandatory)][string]$Replace
    )
    (Get-Content -Path $File).Replace($Find, $Replace) | Set-Content -Path $File
}

# Show full path of a command
function which {
    param([Parameter(Mandatory)][string]$Name)
    Get-Command -Name $Name | Select-Object -ExpandProperty Definition
}

# Show disk/volume info
function df { Get-Volume }

# Extract a ZIP archive to the current directory
function unzip {
    param([Parameter(Mandatory)][string]$File)
    if (-not (Test-Path -Path $File -PathType Leaf)) {
        Write-Error "File not found: $File"
        return
    }
    Expand-Archive -Path $File -DestinationPath (Get-Location) -Force
}

# Send a file or folder to the Recycle Bin (instead of permanent delete)
function trash {
    param([Parameter(Mandatory)][string]$Path)
    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) { Write-Error "Item not found: $Path"; return }

    $fullPath = $resolvedPath.ProviderPath
    $item = Get-Item -LiteralPath $fullPath
    $parentPath = if ($item.PSIsContainer) {
        if ($item.Parent) { $item.Parent.FullName } else { Split-Path -Path $item.FullName -Parent }
    } else { $item.DirectoryName }

    $shell = New-Object -ComObject 'Shell.Application'
    $shellFolder = $shell.NameSpace($parentPath)
    $shellItem = if ($shellFolder) { $shellFolder.ParseName($item.Name) } else { $null }

    if ($shellItem) { $shellItem.InvokeVerb('delete') }
    else { Write-Error "Could not move item to Recycle Bin: $fullPath" }
}

# ------------------------------------------
# System Utilities
# ------------------------------------------

# Show how long the system has been running
function uptime {
    $boot = if (Get-Command Get-Uptime -ErrorAction SilentlyContinue) {
        Get-Uptime -Since
    } else {
        (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }
    (Get-Date) - $boot | Select-Object Days, Hours, Minutes, Seconds
}

# Flush the DNS resolver cache
function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS has been flushed." -ForegroundColor Green
}

# Show your public IP address
function pubip {
    (Invoke-RestMethod -Uri 'https://ifconfig.me/ip').Trim()
}

# Show detailed system information
function sysinfo { Get-ComputerInfo }

# Open a new PowerShell window as Administrator
function admin {
    $cwd = (Get-Location).ProviderPath
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }
    $shellArgs = if ($args.Count -gt 0) { @('-NoExit', '-Command', ($args -join ' ')) } else { @('-NoExit') }
    if (Get-Command wt -ErrorAction SilentlyContinue) {
        Start-Process wt -Verb RunAs -ArgumentList (@('-d', $cwd, $shell) + $shellArgs)
    } else {
        Start-Process $shell -Verb RunAs -WorkingDirectory $cwd -ArgumentList $shellArgs
    }
}
Set-Alias -Name su -Value admin -Force

# Kill a process by name
function pkill {
    param([Parameter(Mandatory)][string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}
Set-Alias -Name k9 -Value pkill -Force

# Find a running process by name
function pgrep {
    param([Parameter(Mandatory)][string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue
}

# Copy text to clipboard
function cpy { Set-Clipboard ($args -join ' ') }

# Paste text from clipboard
function pst { Get-Clipboard }

# Set an environment variable for the current session
function export {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )
    Set-Item -Path "env:$Name" -Value $Value -Force
}

# ------------------------------------------
# Profile Helpers
# ------------------------------------------

# Quickly reload the profile after edits
function Reload-Profile {
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}
Set-Alias -Name reload -Value Reload-Profile

# Update PowerShell itself via WinGet
function Update-PS {
    Write-Host "Checking for updates via WinGet..." -ForegroundColor Cyan
    winget source update | Out-Null
    winget upgrade --id Microsoft.PowerShell
}

# ------------------------------------------
# SYSUPDATE — Full system updater
# ------------------------------------------
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

    function Write-Skip {
        param([string]$Label)
        $script:step++
        Write-Host "`n[$script:step/$total] " -NoNewline -ForegroundColor DarkGray
        Write-Host "[skip] " -NoNewline -ForegroundColor DarkYellow
        Write-Host $Label -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "══════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "  🔄  SYSUPDATE  –  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════" -ForegroundColor DarkCyan

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
