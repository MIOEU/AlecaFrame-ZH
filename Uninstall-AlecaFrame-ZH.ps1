$ErrorActionPreference = "Stop"

$appId = "afmcagbpgggkpdkokjhjkllpegnadmkignlonpjm"
$extensionsRoot = Join-Path $env:LOCALAPPDATA "Overwolf\Extensions\$appId"
$packagesRoot = Join-Path $env:LOCALAPPDATA "Overwolf\PackagesCache\$appId"
$stateRoot = Join-Path $env:LOCALAPPDATA "AlecaFrame-ZH-Patch"
$targetPages = @(
    "background.html",
    "main.html",
    "AFBuilds.html",
    "InGameNotification.html",
    "relicOverlay.html",
    "relicRecommendation.html",
    "rivenOverlay.html",
    "SquadMakingMain.html",
    "SquadMakingSquad.html",
    "tradeFinishedNotification.html"
)

Get-Process -Name "Overwolf" -ErrorAction SilentlyContinue | Stop-Process
Start-Sleep -Seconds 4

$versionDirectory = Get-ChildItem -LiteralPath $extensionsRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "manifest.json") } |
    Sort-Object { [version]$_.Name } -Descending |
    Select-Object -First 1
if ($versionDirectory) {
    $expectedRoot = [IO.Path]::GetFullPath($extensionsRoot).TrimEnd("\") + "\"
    $resolved = [IO.Path]::GetFullPath($versionDirectory.FullName)
    if (-not $resolved.StartsWith($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "安全检查失败：目标目录不属于 AlecaFrame。"
    }

    $opk = Join-Path $packagesRoot "$($versionDirectory.Name)\app.opk"
    $backupRoot = Join-Path $stateRoot "OfficialBackup\$($versionDirectory.Name)"
    $entries = @("_metadata/verified_contents.json")
    $entries += $targetPages | ForEach-Object { "web/$_" }
    $backupComplete = $true
    foreach ($entryName in $entries) {
        $backup = Join-Path $backupRoot ($entryName.Replace("/", "\"))
        if (-not (Test-Path -LiteralPath $backup)) {
            $backupComplete = $false
            break
        }
    }

    if ($backupComplete) {
        foreach ($entryName in $entries) {
            $source = Join-Path $backupRoot ($entryName.Replace("/", "\"))
            $target = Join-Path $versionDirectory.FullName ($entryName.Replace("/", "\"))
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) `
                -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
    }
    elseif (Test-Path -LiteralPath $opk) {
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($opk)
        try {
            foreach ($entryName in $entries) {
                $entry = $archive.GetEntry($entryName)
                if (-not $entry) { continue }
                $target = Join-Path $versionDirectory.FullName ($entryName.Replace("/", "\"))
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) `
                    -Force | Out-Null
                $input = $entry.Open()
                $output = [IO.File]::Create($target)
                try { $input.CopyTo($output) }
                finally {
                    $output.Dispose()
                    $input.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    else {
        throw "没有官方 OPK 或本地备份，无法安全还原。请在 Overwolf 中重新安装 AlecaFrame。"
    }

    $extra = Join-Path $versionDirectory.FullName "web\assets\js\alecaframe-zh-cn.js"
    foreach ($extraName in @(
        "alecaframe-zh-cn.js",
        "alecaframe-zh-cn-items.js",
        "alecaframe-zh-cn-relic-ocr.js",
        "alecaframe-zh-cn-relic-overlay.js",
        "alecaframe-zh-cn-relic-recommendation.js",
        "alecaframe-zh-cn-relic-planner-cache.js",
        "alecaframe-zh-cn-inventory-price-sync.js",
        "alecaframe-zh-cn-inventory-images.js"
    )) {
        $extra = Join-Path $versionDirectory.FullName "web\assets\js\$extraName"
        if (Test-Path -LiteralPath $extra) {
            Remove-Item -LiteralPath $extra -Force
        }
    }
}

$shortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "AlecaFrame-ZH.lnk"
if (Test-Path -LiteralPath $shortcut) {
    Remove-Item -LiteralPath $shortcut -Force
}
$legacyShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "AlecaFrame 中文版.lnk"
if (Test-Path -LiteralPath $legacyShortcut) {
    Remove-Item -LiteralPath $legacyShortcut -Force
}

Write-Host ""
Write-Host "中文版快捷方式已移除，AlecaFrame 官方英文文件已恢复。" -ForegroundColor Green
