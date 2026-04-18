#Requires -Version 7

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $PSCommandPath) ".."))
$piRepoDir = Join-Path $repoRoot "pi"

if (-not (Get-Command pi -ErrorAction SilentlyContinue)) {
    throw "`pi` was not found on PATH. Install Pi first, then rerun this script."
}

if ($env:PI_CODING_AGENT_DIR) {
    $configuredAgentDir = [System.Environment]::ExpandEnvironmentVariables($env:PI_CODING_AGENT_DIR)
    if ($configuredAgentDir -eq "~") {
        $configuredAgentDir = $HOME
    } elseif ($configuredAgentDir.StartsWith("~/") -or $configuredAgentDir.StartsWith("~\\")) {
        $configuredAgentDir = Join-Path $HOME $configuredAgentDir.Substring(2)
    }
    $agentDir = [System.IO.Path]::GetFullPath($configuredAgentDir)
} else {
    $agentDir = Join-Path $HOME ".pi\agent"
}

Write-Host "[INFO] Repo root: $repoRoot"
Write-Host "[INFO] Pi agent dir: $agentDir"

function Read-JsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{}
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($content)) {
        return @{}
    }

    $value = $content | ConvertFrom-Json -AsHashtable
    if ($null -eq $value) {
        return @{}
    }
    if ($value -isnot [System.Collections.IDictionary]) {
        throw "Expected a JSON object in $Path"
    }

    return $value
}

function Merge-Hashtable {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Base,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Override
    )

    $result = [ordered]@{}
    foreach ($key in $Base.Keys) {
        $result[$key] = $Base[$key]
    }

    foreach ($key in $Override.Keys) {
        $overrideValue = $Override[$key]
        if ($result.Contains($key) -and $result[$key] -is [System.Collections.IDictionary] -and $overrideValue -is [System.Collections.IDictionary]) {
            $result[$key] = Merge-Hashtable -Base $result[$key] -Override $overrideValue
        } else {
            $result[$key] = $overrideValue
        }
    }

    return $result
}

function ConvertTo-PrettyJson {
    param(
        [Parameter(Mandatory = $true)]
        $Value
    )

    return (($Value | ConvertTo-Json -Depth 100) + "`n")
}

function Read-OptionalMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($content)) {
        return $null
    }

    return ($content.TrimEnd() + "`n")
}

function Render-ManagedMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SharedPath,
        [Parameter(Mandatory = $true)]
        [string]$LocalPath
    )

    $parts = [System.Collections.Generic.List[string]]::new()
    $sharedText = Read-OptionalMarkdown -Path $SharedPath
    $localText = Read-OptionalMarkdown -Path $LocalPath

    if ($sharedText -or $localText) {
        $parts.Add("<!-- Managed by dotfiles pi bootstrap. Edit $(Split-Path -Leaf $SharedPath) and $(Split-Path -Leaf $LocalPath), then rerun bootstrap. -->")
    }
    if ($sharedText) {
        $parts.Add($sharedText.TrimEnd())
    }
    if ($localText) {
        $parts.Add($localText.TrimEnd())
    }
    if ($parts.Count -eq 0) {
        return ""
    }

    return (($parts -join "`n`n") + "`n")
}

function New-BackupPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $candidate = "$Path.pre-dotfiles-pi-$stamp.bak"
    $index = 1
    while (Test-Path -LiteralPath $candidate) {
        $candidate = "$Path.pre-dotfiles-pi-$stamp-$index.bak"
        $index += 1
    }
    return $candidate
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Read-Manifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        $manifest = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    } catch {
        return $null
    }

    if ($manifest -isnot [System.Collections.IDictionary]) {
        return $null
    }

    return $manifest
}

$changes = 0
$backupCount = 0
$resourceDirs = [ordered]@{
    prompts = [System.IO.Path]::GetFullPath((Join-Path $piRepoDir "prompts"))
    skills = [System.IO.Path]::GetFullPath((Join-Path $piRepoDir "skills"))
    extensions = [System.IO.Path]::GetFullPath((Join-Path $piRepoDir "extensions"))
    themes = [System.IO.Path]::GetFullPath((Join-Path $piRepoDir "themes"))
}
$manifestPath = Join-Path $agentDir "dotfiles-pi-bootstrap.json"

New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
foreach ($subdir in @("prompts", "skills", "extensions", "themes", "sessions")) {
    New-Item -ItemType Directory -Path (Join-Path $agentDir $subdir) -Force | Out-Null
}
foreach ($dir in $resourceDirs.Values) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$seedFiles = [ordered]@{
    (Join-Path $agentDir "settings.local.json") = "{}`n"
    (Join-Path $agentDir "keybindings.local.json") = "{}`n"
    (Join-Path $agentDir "AGENTS.local.md") = "`n"
    (Join-Path $agentDir "APPEND_SYSTEM.local.md") = "`n"
}

foreach ($entry in $seedFiles.GetEnumerator()) {
    if (Test-Path -LiteralPath $entry.Key) {
        continue
    }
    Write-Utf8File -Path $entry.Key -Content $entry.Value
    $changes += 1
    Write-Host "[CREATE] $($entry.Key)"
}

$settingsBasePath = Join-Path $piRepoDir "settings.base.json"
$settingsLocalPath = Join-Path $agentDir "settings.local.json"
$keybindingsBasePath = Join-Path $piRepoDir "keybindings.base.json"
$keybindingsLocalPath = Join-Path $agentDir "keybindings.local.json"
$agentsBasePath = Join-Path $piRepoDir "AGENTS.base.md"
$agentsLocalPath = Join-Path $agentDir "AGENTS.local.md"
$appendBasePath = Join-Path $piRepoDir "APPEND_SYSTEM.base.md"
$appendLocalPath = Join-Path $agentDir "APPEND_SYSTEM.local.md"

$settingsValue = Merge-Hashtable -Base (Read-JsonObject -Path $settingsBasePath) -Override (Read-JsonObject -Path $settingsLocalPath)
foreach ($key in $resourceDirs.Keys) {
    $settingsValue[$key] = @($resourceDirs[$key])
}
$keybindingsValue = Merge-Hashtable -Base (Read-JsonObject -Path $keybindingsBasePath) -Override (Read-JsonObject -Path $keybindingsLocalPath)

$managedTargets = [ordered]@{
    "settings.json" = [ordered]@{
        kind = "json"
        path = Join-Path $agentDir "settings.json"
        sources = @(
            [System.IO.Path]::GetFullPath($settingsBasePath),
            [System.IO.Path]::GetFullPath($settingsLocalPath),
            $resourceDirs["prompts"],
            $resourceDirs["skills"],
            $resourceDirs["extensions"],
            $resourceDirs["themes"]
        )
    }
    "keybindings.json" = [ordered]@{
        kind = "json"
        path = Join-Path $agentDir "keybindings.json"
        sources = @(
            [System.IO.Path]::GetFullPath($keybindingsBasePath),
            [System.IO.Path]::GetFullPath($keybindingsLocalPath)
        )
    }
    "AGENTS.md" = [ordered]@{
        kind = "markdown"
        path = Join-Path $agentDir "AGENTS.md"
        sources = @(
            [System.IO.Path]::GetFullPath($agentsBasePath),
            [System.IO.Path]::GetFullPath($agentsLocalPath)
        )
    }
    "APPEND_SYSTEM.md" = [ordered]@{
        kind = "markdown"
        path = Join-Path $agentDir "APPEND_SYSTEM.md"
        sources = @(
            [System.IO.Path]::GetFullPath($appendBasePath),
            [System.IO.Path]::GetFullPath($appendLocalPath)
        )
    }
}

$expectedContent = [ordered]@{
    "settings.json" = ConvertTo-PrettyJson -Value $settingsValue
    "keybindings.json" = ConvertTo-PrettyJson -Value $keybindingsValue
    "AGENTS.md" = Render-ManagedMarkdown -SharedPath $agentsBasePath -LocalPath $agentsLocalPath
    "APPEND_SYSTEM.md" = Render-ManagedMarkdown -SharedPath $appendBasePath -LocalPath $appendLocalPath
}

$manifest = Read-Manifest -Path $manifestPath
$managedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
if ($manifest -and $manifest.Contains("generatedFiles") -and $manifest["generatedFiles"] -is [System.Collections.IDictionary]) {
    foreach ($name in $manifest["generatedFiles"].Keys) {
        [void]$managedNames.Add([string]$name)
    }
}

foreach ($name in $managedTargets.Keys) {
    $targetPath = $managedTargets[$name]["path"]
    $targetExists = Test-Path -LiteralPath $targetPath
    $isManaged = $managedNames.Contains($name)
    $item = $null
    if ($targetExists) {
        $item = Get-Item -LiteralPath $targetPath -Force
    }
    $needsBackup = $false
    if ($targetExists -and -not $isManaged) {
        $needsBackup = $true
    }
    if ($targetExists -and $isManaged -and ($item.PSIsContainer -or $item.LinkType)) {
        $needsBackup = $true
    }
    if ($needsBackup) {
        $backupPath = New-BackupPath -Path $targetPath
        Move-Item -LiteralPath $targetPath -Destination $backupPath
        $backupCount += 1
        $changes += 1
        $targetExists = $false
        Write-Host "[BACKUP] $targetPath -> $backupPath"
    }
    $currentContent = $null
    if ($targetExists) {
        $currentContent = Get-Content -LiteralPath $targetPath -Raw -Encoding utf8
        if ($null -eq $currentContent) {
            $currentContent = ""
        }
    }
    $desiredContent = [string]$expectedContent[$name]
    if ($currentContent -eq $desiredContent) {
        Write-Host "[SKIP] $targetPath is up to date"
        continue
    }
    Write-Utf8File -Path $targetPath -Content $desiredContent
    $changes += 1
    Write-Host "[WRITE] $targetPath"
}

$generatedManifestFiles = [ordered]@{}
foreach ($name in $managedTargets.Keys) {
    $generatedManifestFiles[$name] = [ordered]@{
        kind = $managedTargets[$name]["kind"]
        path = $managedTargets[$name]["path"]
        sources = $managedTargets[$name]["sources"]
    }
}

$expectedManifest = [ordered]@{
    schemaVersion = 1
    tool = "dotfiles-pi-bootstrap"
    repoRoot = [System.IO.Path]::GetFullPath($repoRoot)
    agentDir = [System.IO.Path]::GetFullPath($agentDir)
    generatedFiles = $generatedManifestFiles
    updatedAt = (Get-Date).ToUniversalTime().ToString("o")
}

$manifestNeedsWrite = $true
if ($manifest) {
    $currentComparable = [ordered]@{}
    foreach ($key in $manifest.Keys) {
        if ($key -eq "updatedAt") {
            continue
        }
        $currentComparable[$key] = $manifest[$key]
    }
    $expectedComparable = [ordered]@{}
    foreach ($key in $expectedManifest.Keys) {
        if ($key -eq "updatedAt") {
            continue
        }
        $expectedComparable[$key] = $expectedManifest[$key]
    }
    $manifestNeedsWrite = (ConvertTo-PrettyJson -Value $currentComparable) -ne (ConvertTo-PrettyJson -Value $expectedComparable)
}

if ($manifestNeedsWrite -or $changes -gt 0) {
    Write-Utf8File -Path $manifestPath -Content (ConvertTo-PrettyJson -Value $expectedManifest)
    $changes += 1
    Write-Host "[WRITE] $manifestPath"
} else {
    Write-Host "[SKIP] $manifestPath is up to date"
}

if ($changes -eq 0) {
    Write-Host ""
    Write-Host "Pi bootstrap is already up to date." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Pi bootstrap applied $changes change(s)." -ForegroundColor Green
    if ($backupCount -gt 0) {
        Write-Host "Backups created: $backupCount" -ForegroundColor Yellow
    }
}

Write-Host "Run /reload in Pi or restart Pi to pick up changes." -ForegroundColor Cyan
