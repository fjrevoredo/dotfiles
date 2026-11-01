#Requires -Version 7

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSCommandPath

if ($env:HERDR_APP_HOME) {
    $destRoot = $env:HERDR_APP_HOME
} else {
    $destRoot = Join-Path $HOME ".config\herdr-app"
}

function Copy-ConfigFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $Destination) {
        $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
        $destHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
        if ($sourceHash -eq $destHash) {
            Write-Host "[SKIP] Up to date: $Destination" -ForegroundColor Yellow
            return
        }

        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $backupPath = "$Destination.pre-dotfiles-$timestamp.bak"
        Copy-Item -LiteralPath $Destination -Destination $backupPath
        Write-Host "[BACKUP] Copied existing file to $backupPath" -ForegroundColor Yellow
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-Host "[OK] Copied: $Destination" -ForegroundColor Green
}

Copy-ConfigFile -Source (Join-Path $repoRoot "settings.json") -Destination (Join-Path $destRoot "settings.json")
Copy-ConfigFile -Source (Join-Path $repoRoot "themes\matrix.json") -Destination (Join-Path $destRoot "themes\matrix.json")

Write-Host ""
Write-Host "Herdr app theme files are in place. Changes apply while the app runs." -ForegroundColor Cyan
Write-Host "Start the Herdr app, or switch to it, to see the Matrix theme." -ForegroundColor Cyan
