#Requires -Version 7
<#
.SYNOPSIS
  Sets up WezTerm and Nushell integration from the dotfiles repo.
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSCommandPath

function Set-SymbolicLink {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if ($item.LinkType -eq "SymbolicLink") {
            $currentTarget = $item.Target
            if ($currentTarget -is [array]) {
                $currentTarget = $currentTarget[0]
            }

            if ([System.IO.Path]::GetFullPath($currentTarget) -eq [System.IO.Path]::GetFullPath($Target)) {
                Write-Host "[SKIP] Symlink already correct: $Path" -ForegroundColor Yellow
                return
            }

            Remove-Item -LiteralPath $Path -Force
        } else {
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $backupPath = "$Path.pre-dotfiles-$timestamp.bak"
            Move-Item -LiteralPath $Path -Destination $backupPath
            Write-Host "[BACKUP] Moved existing file to $backupPath" -ForegroundColor Yellow
        }
    }

    New-Item -ItemType SymbolicLink -Path $Path -Target $Target | Out-Null
    Write-Host "[OK] Symlink: $Path -> $Target" -ForegroundColor Green
}

# ── 1. Developer Mode check (required for symlinks without admin) ──────────────
$devMode = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
    -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
    Write-Warning "Windows Developer Mode is OFF. Enable it at: Settings > System > For Developers"
    Write-Warning "Without it, symlink creation requires running this script as Administrator."
    # Continue anyway — user may be running as admin
}

# ── 2. Symlink shared config files ─────────────────────────────────────────────
$weztermPath = "$HOME\.wezterm.lua"
$weztermTarget = Join-Path $repoRoot ".wezterm.lua"
$nushellDir = Join-Path $env:APPDATA "nushell"
$nuConfigPath = Join-Path $nushellDir "config.nu"
$nuEnvPath = Join-Path $nushellDir "env.nu"
$nuConfigTarget = Join-Path $repoRoot "nushell\config.nu"
$nuEnvTarget = Join-Path $repoRoot "nushell\env.nu"

Set-SymbolicLink -Path $weztermPath -Target $weztermTarget
Set-SymbolicLink -Path $nuConfigPath -Target $nuConfigTarget
Set-SymbolicLink -Path $nuEnvPath -Target $nuEnvTarget

# ── 3. Explorer context menu (right-click "Open in WezTerm") ──────────────────
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\WezTerm" `
    -Value "Open in WezTerm" -Force | Out-Null
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\WezTerm\command" `
    -Value 'wezterm-gui.exe start --cwd "%V"' -Force | Out-Null
Write-Host "[OK] Explorer context menu registered" -ForegroundColor Green

# ── 4. SSH config for 1Password agent ─────────────────────────────────────────
$sshDir = "$HOME\.ssh"
$sshConfigPath = "$sshDir\config"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
}

if (-not (Test-Path $sshConfigPath)) {
    @"
Host *
  IdentityAgent "\\.\pipe\openssh-ssh-agent"
"@ | Set-Content -Path $sshConfigPath -Encoding UTF8
    Write-Host "[OK] SSH config created for 1Password agent" -ForegroundColor Green
} else {
    Write-Host "[SKIP] SSH config already exists — review manually if 1Password agent is needed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "WezTerm and Nushell Windows integration complete." -ForegroundColor Cyan
Write-Host 'Install Nushell separately if `nu` is not already available on PATH.' -ForegroundColor Cyan
