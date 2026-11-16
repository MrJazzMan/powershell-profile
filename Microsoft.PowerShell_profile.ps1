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

# ga  = stage from the current directory down
# gaa = stage the whole worktree, wherever you are inside the repo
function ga    { git add . }
function gaa   { git add --all }

function gadd {
    param([string]$Path = ".")
    git add $Path
}

# NOTE: named gcmsg, not gcm — `gcm` is PowerShell's built-in alias for
# Get-Command, and defining a function with that name would shadow it.
function gcmsg {
    param(
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]]$Message
    )
    # Allows writing gcmsg Message without mandatory quotes for simple sentences
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

# `gcb` ships as a built-in alias for Get-Clipboard, and PowerShell resolves
# aliases before functions — so without dropping it first, the function below
# is never reached. Get-Clipboard is still available as `pst` (and by name).
Remove-Item Alias:gcb -Force -ErrorAction SilentlyContinue

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

# ------------------------------------------
# dir — accept cmd.exe switches
# ------------------------------------------
# `dir` is normally just an alias for Get-ChildItem, which has no /s or /p:
# they bind to -Path instead, so "/s" resolves to C:\s and errors out.
#
# The alias has to go first: PowerShell resolves aliases *before* functions,
# so a `function dir` alongside the alias would simply never be reached.
#
# This wrapper keeps Get-ChildItem (and its object output) for everything
# that already worked, and shells out to the real cmd.exe dir only when an
# actual cmd switch is present. `ls`, `gci` and `Get-ChildItem` still reach
# the cmdlet directly if you want to bypass this.
#
# Caveat: on the cmd.exe path the output is plain text, not FileInfo
# objects — so `dir /s | Where-Object Length -gt 1MB` will not work.
# Use `dir -Recurse | Where-Object ...` for that.
Remove-Item Alias:dir -Force -ErrorAction SilentlyContinue

function dir {
    # cmd.exe dir switches, with optional modifier: /s /b /a:d /o:-d /-c /?
    $cmdSwitch = '^/(\?|-?[abcdlnopqrstwx4](:.+)?)$'

    if (@($args | Where-Object { $_ -is [string] -and $_ -match $cmdSwitch }).Count) {
        & cmd.exe /c dir @args
    } else {
        Get-ChildItem @args
    }
}

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
        [switch]$SkipBun,         # Skip Bun runtime
        [switch]$SkipGo,          # Skip Go-installed CLI tools
        [switch]$SkipVSCode,      # Skip VS Code extensions
        [switch]$SkipClaudeCode,  # Skip Claude Code CLI
        [switch]$SkipDefender,    # Skip Windows Defender signatures
        [switch]$SkipCleanup      # Skip temporary file cleanup
    )

    $start = Get-Date
    $total = 10
    # State lives in a hashtable (not $script:) so a second run in the same
    # session starts again at [1/10] instead of continuing from the last count.
    $state   = @{ Step = 0; Label = $null; Started = $null; Failed = $false }
    $results = [System.Collections.Generic.List[object]]::new()

    # Closes the step in progress: prints its duration and records the outcome.
    function Complete-Step {
        if (-not $state.Label) { return }
        $secs = [math]::Round(((Get-Date) - $state.Started).TotalSeconds)
        $results.Add([pscustomobject]@{ Step = $state.Label; Seconds = $secs; Failed = $state.Failed })
        Write-Host "   ⏱ ${secs}s" -ForegroundColor DarkGray
        $state.Label = $null
    }

    # Flags the current step as failed when the last native command returned non-zero.
    function Test-ExitCode {
        param([string]$What)
        if ($LASTEXITCODE -ne 0) {
            $state.Failed = $true
            Write-Host "   ✘ $What failed (exit code $LASTEXITCODE)" -ForegroundColor Red
        }
    }

    function Write-Step {
        param([string]$Label)
        Complete-Step
        $state.Step++
        $state.Label   = $Label
        $state.Started = Get-Date
        $state.Failed  = $false
        Write-Host "`n[$($state.Step)/$total] $Label" -ForegroundColor Yellow
    }

    function Write-Skip {
        param([string]$Label)
        Complete-Step
        $state.Step++
        Write-Host "`n[$($state.Step)/$total] " -NoNewline -ForegroundColor DarkGray
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
        Test-ExitCode "winget upgrade"
        if ($LASTEXITCODE -ne 0) {
            # The usual cause is an app that is still running (locked files, 0x80070020):
            # the exit code alone doesn't say so, and nothing else in the run will fix it.
            Write-Host "   ↳ Most often an app that is still open (installer can't replace its files)." -ForegroundColor DarkYellow
            Write-Host "     Close it and re-run: winget upgrade --all   (or sysupdate -SkipModules -SkipNpm -SkipGo -SkipVSCode -SkipDefender -SkipBun -SkipClaudeCode -SkipCleanup)" -ForegroundColor DarkYellow
        }
    } else { Write-Skip "winget – packages" }

    # 3-7. Independent steps, run in parallel
    # PowerShell modules, npm, Go tools, VS Code extensions and Defender only need
    # the toolchains winget just upgraded and don't touch each other's state, so
    # they run as thread jobs and the wall-clock drops to the slowest of them.
    # Each body is passed as text and re-created inside its job: a scriptblock
    # created here stays bound to this runspace and would run on this thread.
    # Bodies signal failure by emitting [pscustomobject]@{ StepFailed = $true }.
    # (Start-ThreadJob ships with PowerShell 7.)
    $stepRunner = {
        param([string]$BodyText)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $failed = $false
        try {
            & ([scriptblock]::Create($BodyText)) | ForEach-Object {
                if ($null -ne $_ -and $null -ne $_.PSObject.Properties['StepFailed']) { $failed = $true } else { $_ }
            }
        } catch {
            Write-Host "   ✘ $($_.Exception.Message)" -ForegroundColor Red
            $failed = $true
        }
        [pscustomobject]@{ StepResult = $true; Seconds = [math]::Round($sw.Elapsed.TotalSeconds); Failed = $failed }
    }

    $defs = @(
        @{
            Name = 'PowerShell modules'; Label = 'Updating PowerShell modules...'
            On   = (-not $SkipModules)
            Body = {
                # PSResourceGet is far faster than Update-Module (which queries the
                # gallery one module at a time). Errors are collected and reported
                # instead of being swallowed.
                $modErrors = @()
                if (Get-Command Update-PSResource -ErrorAction SilentlyContinue) {
                    # One retry: behind a corporate proxy / TLS inspection a single
                    # gallery request is occasionally aborted ("SSL connection could
                    # not be established"); the second pass is cheap.
                    $updated = @()
                    foreach ($attempt in 1..2) {
                        $modErrors = @()
                        $updated  += @(Update-PSResource -Name '*' -AcceptLicense -TrustRepository -PassThru -ErrorAction SilentlyContinue -ErrorVariable +modErrors)
                        if ($modErrors.Count -eq 0) { break }
                        if ($attempt -eq 1) { Start-Sleep -Seconds 3 }
                    }
                    if ($updated.Count -gt 0) {
                        Write-Host "   ✔ $($updated.Count) updated: $(($updated | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ')" -ForegroundColor DarkGray
                    } elseif ($modErrors.Count -eq 0) {
                        Write-Host "   ✔ All modules up to date" -ForegroundColor DarkGray
                    }
                } else {
                    Update-Module -AcceptLicense -ErrorAction SilentlyContinue -ErrorVariable +modErrors
                    Write-Host "   ✔ Update-Module finished (PSResourceGet not available – no per-module report)" -ForegroundColor DarkGray
                }
                if ($modErrors.Count -gt 0) {
                    $msg = $modErrors[0].Exception.Message
                    if ($msg.Length -gt 140) { $msg = $msg.Substring(0, 140) + '…' }
                    Write-Host "   ✘ $($modErrors.Count) module(s) could not be checked (still failing after retry); first: $msg" -ForegroundColor Red
                    [pscustomobject]@{ StepFailed = $true }
                }
            }
        }
        @{
            Name = 'npm global packages'; Label = 'Updating npm global packages...'
            On   = (-not $SkipNpm -and [bool](Get-Command npm -ErrorAction SilentlyContinue))
            Body = {
                npm update -g --loglevel=error
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "   ✘ npm update failed (exit code $LASTEXITCODE)" -ForegroundColor Red
                    [pscustomobject]@{ StepFailed = $true }
                }
            }
        }
        @{
            Name = 'Go tools'; Label = 'Updating Go tools...'
            On   = (-not $SkipGo -and [bool](Get-Command go -ErrorAction SilentlyContinue))
            Body = {
                # The Go toolchain itself comes from winget (step 2). What nothing tracks
                # are binaries put in GOPATH\bin by `go install <pkg>@latest` — Go keeps no
                # manifest of them. `go version -m` reads the package path and module
                # version back out of each binary; the install is only re-run (a full
                # recompile) when `go list -m <module>@latest` reports a newer version.
                $goBin = if ($env:GOBIN) { $env:GOBIN } else { Join-Path (go env GOPATH) 'bin' }
                $goTools = @(Get-ChildItem $goBin -Filter *.exe -ErrorAction SilentlyContinue)
                if ($goTools.Count -eq 0) {
                    Write-Host "   (no Go tools installed)" -ForegroundColor DarkGray
                    return
                }
                foreach ($tool in $goTools) {
                    $info = @(go version -m $tool.FullName 2>$null)
                    $pkg  = ($info | Select-String -Pattern '^\s+path\s+(\S+)' | Select-Object -First 1).Matches.Groups[1].Value
                    $mod  = $info | Select-String -Pattern '^\s+mod\s+(\S+)\s+(\S+)' | Select-Object -First 1
                    if (-not $pkg) {
                        Write-Host "   ? $($tool.BaseName) – no module path, skipped" -ForegroundColor DarkGray
                        continue
                    }
                    $have   = $mod.Matches.Groups[2].Value
                    $latest = if ($mod) { ((go list -m "$($mod.Matches.Groups[1].Value)@latest" 2>$null) -split '\s+' | Select-Object -Last 1) }
                    if ($latest -and $latest -eq $have) {
                        Write-Host "   ✔ $($tool.BaseName) up to date ($have)" -ForegroundColor DarkGray
                        continue
                    }
                    go install "$pkg@latest" 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "   ✔ $($tool.BaseName) $have → $(if ($latest) { $latest } else { 'latest' })" -ForegroundColor DarkGray
                    } else {
                        Write-Host "   ✘ $($tool.BaseName) – go install failed" -ForegroundColor Red
                        [pscustomobject]@{ StepFailed = $true }
                    }
                }
            }
        }
        @{
            Name = 'VS Code extensions'; Label = 'Updating VS Code extensions...'
            On   = (-not $SkipVSCode -and [bool](Get-Command code -ErrorAction SilentlyContinue))
            Body = {
                # `code --update-extensions` was removed in recent VS Code versions.
                # Enumerate installed extensions and re-install each one so the marketplace
                # delivers the latest available version; without --force VS Code skips
                # extensions that are already at the latest version (fast path).
                $exts = @(code --list-extensions 2>$null)
                $exts | ForEach-Object { code --install-extension $_ 2>&1 | Out-Null }
                Write-Host "   ✔ $($exts.Count) extension(s) checked" -ForegroundColor DarkGray
            }
        }
        @{
            Name = 'Windows Defender signatures'; Label = 'Updating Windows Defender signatures...'
            On   = (-not $SkipDefender)
            # Runs on this thread, not in a thread job: Update-MpSignature goes through
            # CIM/COM, which failed inside a job with "Call was canceled by the message
            # filter" after ~130s. It still overlaps with the jobs started below.
            Inline = $true
        }
    )

    $running = @($defs | Where-Object { $_.On })
    if ($running.Count -gt 0) {
        Complete-Step
        Write-Host "`n⚡ Running $($running.Count) independent step(s) in parallel..." -ForegroundColor Cyan
        foreach ($d in $running | Where-Object { -not $_.Inline }) {
            $d.Job = Start-ThreadJob -ScriptBlock $stepRunner -ArgumentList $d.Body.ToString() -ThrottleLimit 5
        }
        foreach ($d in $running | Where-Object { $_.Inline }) {
            # Defender is usually company-managed (Intune/MDE) and its CIM provider can
            # hang or be locked down, so a failure here is a warning, not a step error,
            # and it is capped at 45s. A separate process that we can kill outright:
            # Stop-Job waits for a stuck CIM call to unwind (it added ~25s).
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $d.Failed = $false; $d.Warn = $false
            $mpErr = [System.IO.Path]::GetTempFileName()
            $mpProc = Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -PassThru -WindowStyle Hidden `
                -RedirectStandardError $mpErr `
                -ArgumentList '-NoProfile', '-NonInteractive', '-Command', 'Update-MpSignature -ErrorAction Stop'
            if ($mpProc.WaitForExit(45000)) {
                if ($mpProc.ExitCode -eq 0) {
                    $d.Msg = '   ✔ Signatures updated'
                } else {
                    $why = ((Get-Content $mpErr -Raw -ErrorAction SilentlyContinue) -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
                    $d.Msg = "   ⚠ Defender unavailable – managed by the company? ($why)"; $d.Warn = $true
                }
            } else {
                $mpProc.Kill($true)
                $d.Msg = '   ⚠ Defender unavailable – managed by the company? (no response in 45s, skipped)'; $d.Warn = $true
            }
            Remove-Item $mpErr -Force -ErrorAction SilentlyContinue
            $d.Seconds = [math]::Round($sw.Elapsed.TotalSeconds)
            Write-Host "   … $($d.Name) finished" -ForegroundColor DarkGray
        }
        $pending = @($running | Where-Object { -not $_.Inline })
        while ($pending.Count -gt 0) {
            $finished = Wait-Job -Job @($pending | ForEach-Object { $_.Job }) -Any
            $done = $pending | Where-Object { $_.Job.Id -eq $finished.Id } | Select-Object -First 1
            Write-Host "   … $($done.Name) finished" -ForegroundColor DarkGray
            $pending = @($pending | Where-Object { $_.Job.Id -ne $finished.Id })
        }
    }

    # Report in step order, now that every job is done
    foreach ($d in $defs) {
        if (-not $d.On) { Write-Skip $d.Name; continue }
        Complete-Step
        $state.Step++
        Write-Host "`n[$($state.Step)/$total] $($d.Label)" -ForegroundColor Yellow
        if ($d.Inline) {
            Write-Host $d.Msg -ForegroundColor $(if ($d.Failed) { 'Red' } elseif ($d.Warn) { 'DarkYellow' } else { 'DarkGray' })
            $results.Add([pscustomobject]@{ Step = $d.Name; Seconds = $d.Seconds; Failed = $d.Failed })
            Write-Host "   ⏱ $($d.Seconds)s" -ForegroundColor DarkGray
            continue
        }
        $out    = @(Receive-Job -Job $d.Job -Wait -AutoRemoveJob)
        $isMeta = { $null -ne $_ -and $null -ne $_.PSObject.Properties['StepResult'] }
        $res    = $out | Where-Object $isMeta | Select-Object -Last 1
        $out | Where-Object { -not (& $isMeta) } | Out-Host
        $secs   = if ($res) { $res.Seconds } else { 0 }
        $failed = (-not $res) -or $res.Failed
        $results.Add([pscustomobject]@{ Step = $d.Name; Seconds = $secs; Failed = $failed })
        Write-Host "   ⏱ ${secs}s" -ForegroundColor DarkGray
    }

    # 8. Bun runtime (sequential: self-replaces its own binary)
    # `bun upgrade` self-replaces the binary, which only makes sense for the
    # official installer (~\.bun\bin). A winget-managed Bun is already covered
    # by step 2, and letting it self-upgrade would drift from what winget
    # thinks is installed — so detect the install location and skip.
    if (-not $SkipBun -and (Get-Command bun -ErrorAction SilentlyContinue)) {
        $bunSource = (Get-Command bun).Source
        if ($bunSource -like "$env:USERPROFILE\.bun\*") {
            Write-Step "Updating Bun..."
            bun upgrade
        } else {
            Write-Skip "Bun runtime (managed by winget – step 2)"
        }
    } else { Write-Skip "Bun runtime" }

    # 9. Claude Code CLI
    # Work out how it was installed from the path of the `claude` binary (instant)
    # before touching npm: `npm view` / `npm list` cost ~75s here and are only
    # relevant for an npm install.
    #   winget  -> already upgraded in step 2; `claude update` just refuses it
    #   native  -> `claude update`
    #   npm     -> reinstall only when a newer version is published
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    $hasNpm    = [bool](Get-Command npm -ErrorAction SilentlyContinue)
    if (-not $SkipClaudeCode -and ($claudeCmd -or $hasNpm)) {
        Write-Step "Updating Claude Code CLI..."
        $claudeSrc = if ($claudeCmd) { $claudeCmd.Source } else { '' }
        if ($claudeSrc -like '*\WinGet\*') {
            Write-Host "   ✔ Managed by winget (step 2) – $(claude --version 2>$null)" -ForegroundColor DarkGray
        } elseif ($claudeSrc -and $claudeSrc -notlike '*\npm\*') {
            claude update
            Test-ExitCode "claude update"
        } elseif ($hasNpm) {
            $latest = npm view @anthropic-ai/claude-code version 2>$null
            # npm list returns an array of lines. `-match` against an *array* is a
            # filter, not a regex match — it returns the matching elements and never
            # populates $Matches, so indexing $Matches[1] blew up on a null array.
            # Join to a single string first so -match behaves as a scalar match.
            $rawList = (npm list -g @anthropic-ai/claude-code --depth=0 2>$null) -join "`n"
            $current = if ($rawList -match '@anthropic-ai/claude-code@(\d+\.\d+\.\d+)') { $Matches[1] } else { $null }
            try {
                if (-not $current) {
                    Write-Host "   ! Claude Code not installed – skipped" -ForegroundColor DarkGray
                } elseif ($latest -and ([version]$latest -gt [version]$current)) {
                    npm install -g @anthropic-ai/claude-code --loglevel=error
                    Test-ExitCode "npm install"
                    Write-Host "   ✔ $current → $latest" -ForegroundColor DarkGray
                } else {
                    Write-Host "   ✔ Already up to date ($current)" -ForegroundColor DarkGray
                }
            } catch {
                # Fallback: install unconditionally if version comparison fails
                npm install -g @anthropic-ai/claude-code --loglevel=error
            }
        }
    } else { Write-Skip "Claude Code CLI" }


    # 10. Temporary file cleanup
    if (-not $SkipCleanup) {
        Write-Step "Cleaning up temporary files..."
        # Only files untouched for 24h: wiping all of %TEMP% would pull files out
        # from under running apps, installers and live Claude sessions (their
        # scratchpad lives in %TEMP%\claude, which is excluded outright).
        $cutoff   = (Get-Date).AddDays(-1)
        $claudeTmp = Join-Path $env:TEMP 'claude'
        $old = @(Get-ChildItem $env:TEMP -Recurse -File -Force -ErrorAction SilentlyContinue |
                 Where-Object { $_.LastWriteTime -lt $cutoff -and -not $_.FullName.StartsWith($claudeTmp, [StringComparison]::OrdinalIgnoreCase) })
        $before = ($old | Measure-Object -Property Length -Sum).Sum
        $old | Remove-Item -Force -ErrorAction SilentlyContinue
        # Then drop old directories that ended up empty (deepest first)
        Get-ChildItem $env:TEMP -Recurse -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff -and -not $_.FullName.StartsWith($claudeTmp, [StringComparison]::OrdinalIgnoreCase) } |
            Sort-Object { $_.FullName.Length } -Descending |
            Where-Object { -not (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
        $freed = [math]::Round(($before / 1MB), 1)
        Write-Host "   Freed ~$freed MB (files older than 24h)" -ForegroundColor DarkGray
    } else { Write-Skip "temporary file cleanup" }

    Complete-Step

    $elapsed = (Get-Date) - $start
    Write-Host ""
    $slowest = $results | Sort-Object Seconds -Descending | Select-Object -First 3
    if ($slowest) {
        Write-Host "Slowest steps:" -ForegroundColor DarkGray
        $slowest | ForEach-Object { Write-Host ("   {0,6}s  {1}" -f $_.Seconds, $_.Step) -ForegroundColor DarkGray }
    }
    $failed = @($results | Where-Object Failed)
    if ($failed.Count -gt 0) {
        Write-Host "✘  $($failed.Count) step(s) had errors: $(($failed.Step) -join '; ')" -ForegroundColor Red
    }
    Write-Host "✔  Done in $([math]::Round($elapsed.TotalSeconds))s" -ForegroundColor Green

    # Warn if a newer PowerShell is on disk than the one running this session.
    # Compare as [version], not as strings: a string compare also fires on
    # downgrades and orders "7.6.10" before "7.6.9".
    $installedPS = (winget list --id Microsoft.PowerShell 2>$null |
                    Select-String '\d+\.\d+\.\d+' | ForEach-Object {
                        $_.Matches[0].Value }) | Select-Object -Last 1
    if ($installedPS) {
        $running = $PSVersionTable.PSVersion
        $runningShort = "$($running.Major).$($running.Minor).$($running.Patch)"
        try {
            if ([version]$installedPS -gt [version]$runningShort) {
                Write-Host ""
                Write-Host "  ⚠  PowerShell updated: $runningShort → $installedPS" -ForegroundColor DarkYellow
                Write-Host "     Restart your terminal to apply." -ForegroundColor DarkYellow
            }
        } catch { }
    }

    Write-Host "══════════════════════════════════════`n" -ForegroundColor DarkCyan
}
Set-Alias -Name sysup -Value SYSUPDATE
