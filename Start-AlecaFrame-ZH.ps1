$ErrorActionPreference = "Stop"

$appId = "afmcagbpgggkpdkokjhjkllpegnadmkignlonpjm"
$overwolfExe = $null
$launcherExe = $null
$extensionsRoot = Join-Path $env:LOCALAPPDATA "Overwolf\Extensions\$appId"
$packagesRoot = Join-Path $env:LOCALAPPDATA "Overwolf\PackagesCache\$appId"
$stateRoot = Join-Path $env:LOCALAPPDATA "AlecaFrame-ZH-Patch"
$localizerSource = Join-Path $PSScriptRoot "alecaframe-zh-cn.js"
$itemTranslationsSource = Join-Path $PSScriptRoot "alecaframe-zh-cn-items.js"
$relicDucatsSource = Join-Path $PSScriptRoot "alecaframe-zh-cn-relic-ducats.js"
$relicOcrBridgeSource = Join-Path $PSScriptRoot "alecaframe-zh-cn-relic-ocr.js"
$rivenOcrBridgeSource = Join-Path $PSScriptRoot "alecaframe-zh-cn-riven-ocr.js"
$rivenOverlaySource = Join-Path $PSScriptRoot "alecaframe-zh-cn-riven-overlay.js"
$relicOverlaySource = Join-Path $PSScriptRoot "alecaframe-zh-cn-relic-overlay.js"
$relicRecommendationSource = Join-Path $PSScriptRoot "alecaframe-zh-cn-relic-recommendation.js"
$relicPlannerCacheSource = Join-Path $PSScriptRoot "alecaframe-zh-cn-relic-planner-cache.js"
$inventoryPriceSyncSource = Join-Path $PSScriptRoot "alecaframe-zh-cn-inventory-price-sync.js"
$inventoryImagesSource = Join-Path $PSScriptRoot "alecaframe-zh-cn-inventory-images.js"
$relicOcrServerSource = Join-Path $PSScriptRoot "alecaframe-relic-ocr-server.js"
$relicOcrWorkerSource = Join-Path $PSScriptRoot "Invoke-AlecaFrame-RelicChineseOcr.ps1"
$paddleRewardWorkerSource = Join-Path $PSScriptRoot "alecaframe-paddle-reward-worker.py"
$paddlePythonSource = Join-Path $PSScriptRoot ".tools\python311-portable\python.exe"
$localNodeSource = Join-Path $PSScriptRoot ".tools\node\node.exe"
$ocrSettingsPath = Join-Path $PSScriptRoot "AlecaFrame-ZH.settings.json"
$relicCaptureSource = Join-Path $PSScriptRoot "Capture-AlecaFrame-WarframeScreen.ps1"
$relicOcrStateRoot = Join-Path $stateRoot "RelicChineseOcr"
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
$scriptTag = '<script src="assets/js/alecaframe-zh-cn.js"></script>'
$itemTranslationsScriptTag = '<script src="assets/js/alecaframe-zh-cn-items.js"></script>'
$relicDucatsScriptTag = '<script src="assets/js/alecaframe-zh-cn-relic-ducats.js"></script>'
$relicOcrBridgeScriptTag = '<script src="assets/js/alecaframe-zh-cn-relic-ocr.js"></script>'
$rivenOcrBridgeScriptTag = '<script src="assets/js/alecaframe-zh-cn-riven-ocr.js"></script>'
$rivenOverlayScriptTag = '<script src="assets/js/alecaframe-zh-cn-riven-overlay.js"></script>'
$relicOverlayScriptTag = '<script src="assets/js/alecaframe-zh-cn-relic-overlay.js"></script>'
$relicRecommendationScriptTag = '<script src="assets/js/alecaframe-zh-cn-relic-recommendation.js"></script>'
$relicPlannerCacheScriptTag = '<script src="assets/js/alecaframe-zh-cn-relic-planner-cache.js"></script>'
$inventoryPriceSyncScriptTag = '<script src="assets/js/alecaframe-zh-cn-inventory-price-sync.js"></script>'
$inventoryImagesScriptTag = '<script src="assets/js/alecaframe-zh-cn-inventory-images.js"></script>'

function Write-LauncherLog {
    param([string]$Message)
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
    $line = "$(Get-Date -Format o) $Message"
    Add-Content -LiteralPath (Join-Path $stateRoot "launcher.log") -Value $line -Encoding UTF8
}

function Get-RelicOcrEnabled {
    if (-not (Test-Path -LiteralPath $ocrSettingsPath)) { return $true }
    try {
        $settings = Get-Content -LiteralPath $ocrSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $settings.relicOcr -and $null -ne $settings.relicOcr.enabled) {
            return [bool]$settings.relicOcr.enabled
        }
    }
    catch {
        Write-LauncherLog "OCR settings could not be read; using enabled default: $($_.Exception.Message)"
    }
    return $true
}

function Test-RelicOcrPrerequisites {
    $nodeAvailable = (Test-Path -LiteralPath $localNodeSource) -or $null -ne (Get-Command node -ErrorAction SilentlyContinue)
    if (-not $nodeAvailable) { return $false }
    foreach ($path in @($relicOcrServerSource, $relicOcrWorkerSource, $relicCaptureSource, $paddleRewardWorkerSource, $paddlePythonSource)) {
        if (-not (Test-Path -LiteralPath $path)) { return $false }
    }
    return $true
}

function Find-OverwolfInstall {
    $candidateDirectories = New-Object System.Collections.Generic.List[string]

    $running = Get-Process -Name "Overwolf" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path } |
        Select-Object -First 1
    if ($running) {
        $candidateDirectories.Add((Split-Path -Parent $running.Path))
    }

    $uninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue |
            ForEach-Object {
                Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            } |
            Where-Object {
                $_.DisplayName -eq "Overwolf" -and $_.InstallLocation
            } |
            ForEach-Object {
                $candidateDirectories.Add($_.InstallLocation.TrimEnd("\"))
            }
    }

    $candidateDirectories.Add((Join-Path $env:LOCALAPPDATA "Overwolf"))
    if (${env:ProgramFiles(x86)}) {
        $candidateDirectories.Add((Join-Path ${env:ProgramFiles(x86)} "Overwolf"))
    }
    if ($env:ProgramFiles) {
        $candidateDirectories.Add((Join-Path $env:ProgramFiles "Overwolf"))
    }
    $candidateDirectories.Add("G:\overwolf")

    foreach ($directory in $candidateDirectories | Select-Object -Unique) {
        $overwolf = Join-Path $directory "Overwolf.exe"
        $launcher = Join-Path $directory "OverwolfLauncher.exe"
        if ((Test-Path -LiteralPath $overwolf) -and
            (Test-Path -LiteralPath $launcher)) {
            return [pscustomobject]@{
                Overwolf = $overwolf
                Launcher = $launcher
            }
        }
    }
    throw "找不到 Overwolf 安装目录，请先安装或修复 Overwolf。"
}

function Get-LatestVersionDirectory {
    $directory = Get-ChildItem -LiteralPath $extensionsRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "manifest.json") } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $directory) {
        throw "没有找到 AlecaFrame 安装版本。"
    }
    return $directory
}

function Assert-AppPath {
    param([string]$Path)
    $resolvedRoot = [IO.Path]::GetFullPath($extensionsRoot).TrimEnd("\") + "\"
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "安全检查失败：路径不属于 AlecaFrame 扩展目录。"
    }
}

function Restore-OfficialFiles {
    param(
        [string]$Version,
        [string]$VersionPath
    )
    Assert-AppPath $VersionPath
    $opk = Join-Path $packagesRoot "$Version\app.opk"
    $backupRoot = Join-Path $stateRoot "OfficialBackup\$Version"
    $entries = @("_metadata/verified_contents.json", "web/assets/js/relicOverlay/main.js")
    $entries += $targetPages | ForEach-Object { "web/$_" }

    $backupComplete = $true
    foreach ($entryName in $entries) {
        $backupFile = Join-Path $backupRoot ($entryName.Replace("/", "\"))
        if (-not (Test-Path -LiteralPath $backupFile)) {
            $backupComplete = $false
            break
        }
    }

    if (Test-Path -LiteralPath $opk) {
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($opk)
        try {
            foreach ($entryName in $entries) {
                $entry = $archive.GetEntry($entryName)
                if (-not $entry) {
                    throw "官方 OPK 中缺少文件：$entryName"
                }
                $target = Join-Path $VersionPath ($entryName.Replace("/", "\"))
                $targetParent = Split-Path -Parent $target
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
                $input = $entry.Open()
                $output = [IO.File]::Create($target)
                try {
                    $input.CopyTo($output)
                }
                finally {
                    $output.Dispose()
                    $input.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }

        foreach ($entryName in $entries) {
            $source = Join-Path $VersionPath ($entryName.Replace("/", "\"))
            $backup = Join-Path $backupRoot ($entryName.Replace("/", "\"))
            New-Item -ItemType Directory -Path (Split-Path -Parent $backup) `
                -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $backup -Force
        }
        Write-LauncherLog "Official files restored from OPK and backed up"
    }
    elseif ($backupComplete) {
        foreach ($entryName in $entries) {
            $source = Join-Path $backupRoot ($entryName.Replace("/", "\"))
            $target = Join-Path $VersionPath ($entryName.Replace("/", "\"))
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) `
                -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
        Write-LauncherLog "Official OPK unavailable; restored local official backup"
    }
    else {
        $extraLocalizer = Join-Path $VersionPath "web\assets\js\alecaframe-zh-cn.js"
        if (Test-Path -LiteralPath $extraLocalizer) {
            throw "官方 OPK 缓存和本地备份都不存在。请在 Overwolf 中重新安装 AlecaFrame 后再启动中文版。"
        }
        foreach ($entryName in $entries) {
            $source = Join-Path $VersionPath ($entryName.Replace("/", "\"))
            if (-not (Test-Path -LiteralPath $source)) {
                throw "AlecaFrame 官方文件不完整：$entryName。请重新安装 AlecaFrame。"
            }
            if ($entryName -like "web/*") {
                $content = [IO.File]::ReadAllText($source, [Text.Encoding]::UTF8)
                if ($content.Contains($scriptTag)) {
                    throw "检测到旧汉化文件，但没有可用的官方备份。请重新安装 AlecaFrame。"
                }
            }
            $backup = Join-Path $backupRoot ($entryName.Replace("/", "\"))
            New-Item -ItemType Directory -Path (Split-Path -Parent $backup) `
                -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $backup -Force
        }
        Write-LauncherLog "Official OPK unavailable; created local official backup"
    }

    foreach ($extraScript in @(
        "alecaframe-zh-cn.js",
        "alecaframe-zh-cn-items.js",
        "alecaframe-zh-cn-relic-ducats.js",
        "alecaframe-zh-cn-relic-ocr.js",
        "alecaframe-zh-cn-riven-ocr.js",
        "alecaframe-zh-cn-riven-overlay.js",
        "alecaframe-zh-cn-relic-overlay.js",
        "alecaframe-zh-cn-relic-recommendation.js",
        "alecaframe-zh-cn-relic-planner-cache.js",
        "alecaframe-zh-cn-inventory-price-sync.js",
        "alecaframe-zh-cn-inventory-images.js"
    )) {
        $extraLocalizer = Join-Path $VersionPath "web\assets\js\$extraScript"
        if (Test-Path -LiteralPath $extraLocalizer) {
            Remove-Item -LiteralPath $extraLocalizer -Force
        }
    }
}

function Add-ChineseFiles {
    param(
        [string]$VersionPath,
        [bool]$EnableRelicOcr
    )
    Assert-AppPath $VersionPath
    $webRoot = Join-Path $VersionPath "web"
    foreach ($relativePage in $targetPages) {
        $target = Join-Path $webRoot $relativePage
        $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
        if (-not $content.Contains($scriptTag)) {
            if ($content -notmatch "(?i)</body>") {
                throw "页面缺少 </body>，无法注入：$relativePage"
            }
            $patched = [regex]::Replace(
                $content,
                "(?i)</body>",
                "    $itemTranslationsScriptTag`r`n    $scriptTag`r`n</body>",
                1
            )
            [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
        }
        if ($EnableRelicOcr -and $relativePage -eq "background.html") {
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            if (-not $content.Contains($relicOcrBridgeScriptTag)) {
                $patched = [regex]::Replace(
                    $content,
                    "(?i)</body>",
                    "    $relicOcrBridgeScriptTag`r`n</body>",
                    1
                )
                [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
            }
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            if (-not $content.Contains($rivenOcrBridgeScriptTag)) {
                $patched = [regex]::Replace(
                    $content,
                    "(?i)</body>",
                    "    $rivenOcrBridgeScriptTag`r`n</body>",
                    1
                )
                [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
            }
        }
        if ($EnableRelicOcr -and $relativePage -eq "rivenOverlay.html") {
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            if (-not $content.Contains($rivenOverlayScriptTag)) {
                $patched = [regex]::Replace(
                    $content,
                    "(?i)</body>",
                    "    $rivenOverlayScriptTag`r`n</body>",
                    1
                )
                [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
            }
            # Vue's original stat lists have no keys.  A short OCR frame can
            # otherwise leave a previously rendered truncated row in the DOM
            # after the canonical trait array has only three entries.
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            $keyed = [regex]::Replace(
                $content,
                '(<div class="rivenDetailsStat (?:positive|negative)" v-for="stat in [^"]+")',
                '$1 :key="stat.description"'
            )
            if ($keyed -ne $content) {
                [IO.File]::WriteAllText($target, $keyed, [Text.UTF8Encoding]::new($false))
            }
        }
        if ($relativePage -eq "relicRecommendation.html") {
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            if (-not $content.Contains($relicRecommendationScriptTag)) {
                $patched = [regex]::Replace(
                    $content,
                    "(?i)</body>",
                    "    $relicRecommendationScriptTag`r`n</body>",
                    1
                )
                [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
            }
        }
        if ($relativePage -eq "relicOverlay.html") {
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            if (-not $content.Contains($relicDucatsScriptTag)) {
                $patched = [regex]::Replace(
                    $content,
                    "(?i)</body>",
                    "    $relicDucatsScriptTag`r`n</body>",
                    1
                )
                [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
            }
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            if (-not $content.Contains($relicOverlayScriptTag)) {
                $patched = [regex]::Replace(
                    $content,
                    "(?i)</body>",
                    "    $relicOverlayScriptTag`r`n</body>",
                    1
                )
                [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
            }
        }
        if ($relativePage -eq "main.html") {
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            if (-not $content.Contains($relicPlannerCacheScriptTag)) {
                $patched = [regex]::Replace(
                    $content,
                    "(?i)</body>",
                    "    $relicPlannerCacheScriptTag`r`n</body>",
                    1
                )
                [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
            }
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            if (-not $content.Contains($inventoryPriceSyncScriptTag)) {
                $patched = [regex]::Replace(
                    $content,
                    "(?i)</body>",
                    "    $inventoryPriceSyncScriptTag`r`n</body>",
                    1
                )
                [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
            }
            $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
            if (-not $content.Contains($inventoryImagesScriptTag)) {
                $patched = [regex]::Replace(
                    $content,
                    "(?i)</body>",
                    "    $inventoryImagesScriptTag`r`n</body>",
                    1
                )
                [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
            }
        }
    }
    Copy-Item -LiteralPath $localizerSource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn.js") `
        -Force
    Copy-Item -LiteralPath $itemTranslationsSource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-items.js") `
        -Force
    Copy-Item -LiteralPath $relicDucatsSource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-relic-ducats.js") `
        -Force
    if ($EnableRelicOcr) {
        Copy-Item -LiteralPath $relicOcrBridgeSource `
            -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-relic-ocr.js") `
            -Force
        Copy-Item -LiteralPath $rivenOcrBridgeSource `
            -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-riven-ocr.js") `
            -Force
        Copy-Item -LiteralPath $rivenOverlaySource `
            -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-riven-overlay.js") `
            -Force
    }
    Copy-Item -LiteralPath $relicOverlaySource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-relic-overlay.js") `
        -Force
    Copy-Item -LiteralPath $relicRecommendationSource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-relic-recommendation.js") `
        -Force
    Copy-Item -LiteralPath $relicPlannerCacheSource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-relic-planner-cache.js") `
        -Force
    Copy-Item -LiteralPath $inventoryPriceSyncSource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-inventory-price-sync.js") `
        -Force
    Copy-Item -LiteralPath $inventoryImagesSource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-inventory-images.js") `
        -Force

    if ($EnableRelicOcr) {
    # The official reward window always executes this file. Patch only its
    # English-language failure branch so reward selection can consume the
    # short-lived Chinese OCR result. This is independent of the refinement
    # recommendation overlay and its planner cache.
    $relicOverlayMain = Join-Path $webRoot "assets\js\relicOverlay\main.js"
    $mainContent = [IO.File]::ReadAllText($relicOverlayMain, [Text.Encoding]::UTF8)
    $helperMarker = "// ALECAFRAME_ZH_CN_REWARD_FALLBACK"
    if (-not $mainContent.Contains($helperMarker)) {
        $helper = @'
// ALECAFRAME_ZH_CN_REWARD_FALLBACK
var alecaFrameZhCnRewardResultKey = "__alecaframeZhCnRewardOverlayResult";
var alecaFrameZhCnRewardResultEndpoint = "http://127.0.0.1:38147/latest-reward";
var alecaFrameZhCnRewardCaptureEndpoint = "http://127.0.0.1:38147/capture-reward";
var alecaFrameZhCnRewardFallbackInProgress = false;
var alecaFrameZhCnRewardFallbackCompleted = false;
function alecaFrameZhCnRewardDisplayName(englishName) {
    try {
        var translations = window.__ALECAFRAME_ZH_CN_ITEMS__ || {};
        var chineseName = translations[englishName];
        return chineseName && chineseName !== englishName ? chineseName + "\n" + englishName : englishName;
    } catch (e) {
        return englishName;
    }
}
function alecaFrameZhCnRewardItem(name) {
    return {
        name: alecaFrameZhCnRewardDisplayName(name), platinum: -1, ducats: -1,
        isItemVaulted: false, isFav: false, isPartOfOwned: false,
        countOwned: "-", totalToOwn: "-", componentData: [], setPlat: -1, detected: true
    };
}
function alecaFrameZhCnRewardRead(startedAt, done) {
    try {
        var cached = JSON.parse(localStorage.getItem(alecaFrameZhCnRewardResultKey) || "");
        if (cached && Array.isArray(cached.rewards) && cached.rewards.length &&
            cached.updatedAt >= startedAt - 15000 && Date.now() - cached.updatedAt < 30000) {
            done(cached.rewards);
            return;
        }
    } catch (e) { }
    fetch(alecaFrameZhCnRewardResultEndpoint).then(function (response) {
        return response.ok ? response.json() : null;
    }).then(function (payload) {
        if (payload && Array.isArray(payload.rewards) && payload.rewards.length &&
            payload.updatedAt >= startedAt - 15000) {
            done(payload.rewards);
        }
    }).catch(function () { });
}
function alecaFrameZhCnRewardApplyPrices(names) {
    try {
        var nativePlugin = window.plugin && window.plugin.get && window.plugin.get();
        if (!nativePlugin || typeof nativePlugin.getHugePriceList !== "function") return;
        nativePlugin.getHugePriceList(JSON.stringify(names), function (success, data) {
            if (!success) return;
            try {
                var prices = JSON.parse(data);
                relicsApp.relics = relicsApp.relics.map(function (relic, index) {
                    var price = prices[index] && prices[index].post;
                    if (Number.isFinite(Number(price))) relic.platinum = Number(price);
                    return relic;
                });
            } catch (e) { }
        });
    } catch (e) { }
}
function alecaFrameZhCnRequestRewardCapture() {
    // Ask the background page for its native Overwolf game-window capture.
    // The fallback keeps compatibility only if the background bridge is not
    // yet available during application startup.
    try {
        var mainWindow = overwolf.windows.getMainWindow();
        var background = mainWindow && mainWindow.window ? mainWindow.window : mainWindow;
        if (background && typeof background.__ALECAFRAME_ZH_CN_CAPTURE_REWARD__ === "function") {
            background.__ALECAFRAME_ZH_CN_CAPTURE_REWARD__();
            return;
        }
        fetch(alecaFrameZhCnRewardCaptureEndpoint, { method: "POST" }).catch(function () { });
    } catch (e) {
        try {
            fetch(alecaFrameZhCnRewardCaptureEndpoint, { method: "POST" }).catch(function () { });
        } catch (ignored) { }
    }
}
function alecaFrameZhCnStartRewardFallback() {
    if (alecaFrameZhCnRewardFallbackInProgress || alecaFrameZhCnRewardFallbackCompleted) return;
    alecaFrameZhCnRewardFallbackInProgress = true;
    var fallbackStartedAt = Date.now();
    var attempts = 0;
    var completed = false;
    relicsApp.loading = true;
    relicsApp.error = false;
    alecaFrameZhCnRequestRewardCapture();
    var timer = setInterval(function () {
        attempts += 1;
        alecaFrameZhCnRewardRead(fallbackStartedAt, function (names) {
            if (completed) return;
            completed = true;
            alecaFrameZhCnRewardFallbackCompleted = true;
            alecaFrameZhCnRewardFallbackInProgress = false;
            clearInterval(timer);
            relicsApp.relics = names.map(alecaFrameZhCnRewardItem);
            relicsApp.globalData = { platinum: -1, ducats: -1 };
            relicsApp.error = false;
            relicsApp.errorMessage = "";
            relicsApp.loading = false;
            alecaFrameZhCnRewardApplyPrices(names);
            console.log("[AlecaFrame ZH] Chinese reward fallback applied: " + names.join(" | "));
        });
        if (attempts >= 35 && !completed) {
            clearInterval(timer);
            alecaFrameZhCnRewardFallbackInProgress = false;
            relicsApp.loading = false;
            relicsApp.error = true;
            relicsApp.errorMessage = "Unsupported Warframe language detected. Chinese OCR did not return a current reward result.";
        }
    }, 100);
}
'@
        $mainContent = $mainContent.Replace("var relicWindowInitialized = false;", "$helper`r`nvar relicWindowInitialized = false;")
        $replacementBranch = @'
                            console.log("Failed to get relic data: " + data);

                            if (String(data || "").toLowerCase().includes("unsupported warframe language detected")) {
                                alecaFrameZhCnStartRewardFallback();
                            } else {
                                relicsApp.error = true;
                                relicsApp.errorMessage = data;
                            }
'@
        $failurePattern = '(?ms)^\s*console\.log\("Failed to get relic data: " \+ data\);\s*relicsApp\.error = true;\s*relicsApp\.errorMessage = data;'
        if (-not [regex]::IsMatch($mainContent, $failurePattern)) {
            throw "奖励窗口主脚本版本不匹配，未应用中文奖励回退补丁。"
        }
        $mainContent = [regex]::Replace($mainContent, $failurePattern, $replacementBranch, 1)
        [IO.File]::WriteAllText($relicOverlayMain, $mainContent, [Text.UTF8Encoding]::new($false))
    }
    # Keep the injected reward helper up to date across launcher runs. The
    # first implementation only inserted once, which left deployed users on
    # its old 2.5-second capture path even after source fixes were made.
    $mainContent = [IO.File]::ReadAllText($relicOverlayMain, [Text.Encoding]::UTF8)
    $mainContent = $mainContent.Replace('var alecaFrameZhCnRewardCaptureEndpoint = "http://127.0.0.1:38147/capture";', 'var alecaFrameZhCnRewardCaptureEndpoint = "http://127.0.0.1:38147/capture-reward";')
    # The reward cards use English names internally for price and inventory
    # queries. Render only the Chinese display name in this overlay; the main
    # market card renderer remains independent and can keep its bilingual UI.
    $mainContent = $mainContent.Replace('return chineseName && chineseName !== englishName ? chineseName + "\n" + englishName : englishName;', 'return chineseName && chineseName !== englishName ? chineseName : (englishName === "Forma Blueprint" ? "Forma 蓝图" : englishName);')
    # Existing installations already contain the first helper implementation.
    # Replace its direct PowerShell capture request with the background page's
    # native Overwolf screenshot bridge without touching planner logic.
    if (-not $mainContent.Contains('background.__ALECAFRAME_ZH_CN_CAPTURE_REWARD__')) {
        $oldRewardCaptureRequest = @'
function alecaFrameZhCnRequestRewardCapture() {
    // This request is made only after the official reward window has already
    // reported the Chinese-language error. It is intentionally independent
    // from the relic-planner recommendation probe and does not poll.
    try {
        fetch(alecaFrameZhCnRewardCaptureEndpoint, { method: "POST" }).catch(function () { });
    } catch (e) { }
}
'@
        $newRewardCaptureRequest = @'
function alecaFrameZhCnRequestRewardCapture() {
    // Ask the background page for its native Overwolf game-window capture.
    // The fallback keeps compatibility only if the background bridge is not
    // yet available during application startup.
    try {
        overwolf.windows.getMainWindow().then(function (result) {
            var background = result && result.window;
            if (background && typeof background.__ALECAFRAME_ZH_CN_CAPTURE_REWARD__ === "function") {
                background.__ALECAFRAME_ZH_CN_CAPTURE_REWARD__();
                return;
            }
            fetch(alecaFrameZhCnRewardCaptureEndpoint, { method: "POST" }).catch(function () { });
        }).catch(function () {
            fetch(alecaFrameZhCnRewardCaptureEndpoint, { method: "POST" }).catch(function () { });
        });
    } catch (e) { }
}
'@
        if (-not $mainContent.Contains($oldRewardCaptureRequest)) {
            throw "奖励截图请求函数版本不匹配，未应用原生截图更新。"
        }
        $mainContent = $mainContent.Replace($oldRewardCaptureRequest, $newRewardCaptureRequest)
    }
    # Upgrade the Promise-based bridge deployed by the previous launcher. In
    # this Overwolf context getMainWindow is synchronous, so that version
    # never reached the native game-window capture function.
    $deployedPromiseRewardCaptureRequest = @'
function alecaFrameZhCnRequestRewardCapture() {
    // Ask the background page for its native Overwolf game-window capture.
    // The fallback keeps compatibility only if the background bridge is not
    // yet available during application startup.
    try {
        overwolf.windows.getMainWindow().then(function (result) {
            var background = result && result.window;
            if (background && typeof background.__ALECAFRAME_ZH_CN_CAPTURE_REWARD__ === "function") {
                background.__ALECAFRAME_ZH_CN_CAPTURE_REWARD__();
                return;
            }
            fetch(alecaFrameZhCnRewardCaptureEndpoint, { method: "POST" }).catch(function () { });
        }).catch(function () {
            fetch(alecaFrameZhCnRewardCaptureEndpoint, { method: "POST" }).catch(function () { });
        });
    } catch (e) { }
}
'@
    $synchronousRewardCaptureRequest = @'
function alecaFrameZhCnRequestRewardCapture() {
    // Ask the background page for its native Overwolf game-window capture.
    // The fallback keeps compatibility only if the background bridge is not
    // yet available during application startup.
    try {
        var mainWindow = overwolf.windows.getMainWindow();
        var background = mainWindow && mainWindow.window ? mainWindow.window : mainWindow;
        if (background && typeof background.__ALECAFRAME_ZH_CN_CAPTURE_REWARD__ === "function") {
            background.__ALECAFRAME_ZH_CN_CAPTURE_REWARD__();
            return;
        }
        fetch(alecaFrameZhCnRewardCaptureEndpoint, { method: "POST" }).catch(function () { });
    } catch (e) {
        try {
            fetch(alecaFrameZhCnRewardCaptureEndpoint, { method: "POST" }).catch(function () { });
        } catch (ignored) { }
    }
}
'@
    $mainContent = $mainContent.Replace($deployedPromiseRewardCaptureRequest, $synchronousRewardCaptureRequest)
    if (-not $mainContent.Contains('var alecaFrameZhCnRewardFallbackInProgress = false;')) {
        $mainContent = $mainContent.Replace(
            'var alecaFrameZhCnRewardCaptureEndpoint = "http://127.0.0.1:38147/capture-reward";',
            "var alecaFrameZhCnRewardCaptureEndpoint = `"http://127.0.0.1:38147/capture-reward`";`r`nvar alecaFrameZhCnRewardFallbackInProgress = false;`r`nvar alecaFrameZhCnRewardFallbackCompleted = false;"
        )
    }
    if (-not $mainContent.Contains('if (alecaFrameZhCnRewardFallbackInProgress || alecaFrameZhCnRewardFallbackCompleted) return;')) {
        $mainContent = $mainContent.Replace('function alecaFrameZhCnStartRewardFallback() {', "function alecaFrameZhCnStartRewardFallback() {`r`n    if (alecaFrameZhCnRewardFallbackInProgress || alecaFrameZhCnRewardFallbackCompleted) return;`r`n    alecaFrameZhCnRewardFallbackInProgress = true;")
        $mainContent = $mainContent.Replace('            completed = true;', "            completed = true;`r`n            alecaFrameZhCnRewardFallbackCompleted = true;`r`n            alecaFrameZhCnRewardFallbackInProgress = false;")
        $mainContent = $mainContent.Replace('            clearInterval(timer);`r`n            relicsApp.loading = false;', "            clearInterval(timer);`r`n            alecaFrameZhCnRewardFallbackInProgress = false;`r`n            relicsApp.loading = false;")
    }
    $slowRewardStart = "    setTimeout(() => {`r`n        sendPage(`"relic`");`r`n    }, 2500);"
    $fastRewardStart = "    // Start Chinese reward recognition immediately; native English OCR may fail later.`r`n    alecaFrameZhCnStartRewardFallback();`r`n    setTimeout(() => {`r`n        sendPage(`"relic`");`r`n    }, 300);"
    $mainContent = $mainContent.Replace($slowRewardStart, $fastRewardStart)
    [IO.File]::WriteAllText($relicOverlayMain, $mainContent, [Text.UTF8Encoding]::new($false))
    }

}

function Start-RelicChineseOcrHelper {
    $nodeCommand = if (Test-Path -LiteralPath $localNodeSource) {
        $localNodeSource
    }
    elseif (Get-Command node -ErrorAction SilentlyContinue) {
        (Get-Command node -ErrorAction Stop).Source
    }
    else {
        throw "未找到 Node.js。请先运行 安装OCR前置组件.cmd。"
    }
    foreach ($path in @($relicOcrServerSource, $relicOcrWorkerSource, $relicCaptureSource, $paddleRewardWorkerSource, $paddlePythonSource)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "缺少中文遗物 OCR 文件：$path"
        }
    }

    $healthUri = "http://127.0.0.1:38147/health"

    # The helper loads the OCR server code only at process startup. Stop the
    # previous instance so a launcher restart always applies source updates.
    $listeningConnection = Get-NetTCPConnection -LocalAddress "127.0.0.1" -LocalPort 38147 -State Listen `
        -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($listeningConnection) {
        $owner = Get-CimInstance Win32_Process -Filter "ProcessId = $($listeningConnection.OwningProcess)" `
            -ErrorAction SilentlyContinue
        if ($owner -and $owner.Name -eq "node.exe" -and
            $owner.CommandLine -like "*alecaframe-relic-ocr-server.js*") {
            Stop-Process -Id $listeningConnection.OwningProcess -Force
            Start-Sleep -Milliseconds 350
            Write-LauncherLog "Previous Chinese relic OCR helper stopped"
        }
        else {
            throw "端口 38147 正被其他程序占用，无法启动中文遗物 OCR 服务。"
        }
    }

    New-Item -ItemType Directory -Path $relicOcrStateRoot -Force | Out-Null
    $paddleCacheRoot = Join-Path $PSScriptRoot ".tools\paddleocr-home"
    New-Item -ItemType Directory -Path $paddleCacheRoot -Force | Out-Null
    $helperStdoutLog = Join-Path $relicOcrStateRoot "helper.out.log"
    $helperStderrLog = Join-Path $relicOcrStateRoot "helper.err.log"
    $previousPaddleHome = $env:PADDLE_HOME
    $previousXdgCacheHome = $env:XDG_CACHE_HOME
    $previousHome = $env:HOME
    $previousUserProfile = $env:USERPROFILE
    try {
        # Paddle 2.x uses XDG_CACHE_HOME/HOME for its model cache rather than
        # PADDLE_HOME alone. Keep all downloads inside this project.
        $env:PADDLE_HOME = $paddleCacheRoot
        $env:XDG_CACHE_HOME = $paddleCacheRoot
        $env:HOME = (Join-Path $PSScriptRoot ".tools")
        $env:USERPROFILE = (Join-Path $PSScriptRoot ".tools")
        Start-Process -FilePath $nodeCommand `
            -ArgumentList @($relicOcrServerSource, $itemTranslationsSource, $relicOcrWorkerSource, $relicOcrStateRoot, $relicCaptureSource, $paddlePythonSource, $paddleRewardWorkerSource) `
            -WindowStyle Hidden `
            -RedirectStandardOutput $helperStdoutLog `
            -RedirectStandardError $helperStderrLog
    }
    finally {
        $env:PADDLE_HOME = $previousPaddleHome
        $env:XDG_CACHE_HOME = $previousXdgCacheHome
        $env:HOME = $previousHome
        $env:USERPROFILE = $previousUserProfile
    }

    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 250
        try {
            if ((Invoke-RestMethod -Uri $healthUri -TimeoutSec 1).ready) {
                Write-LauncherLog "Chinese relic OCR helper started"
                return
            }
        }
        catch { }
    }
    throw "中文遗物 OCR 服务启动失败。"
}

function Get-AlecaFrameRenderer {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq "OverwolfBrowser.exe" -and
            $_.CommandLine -match "AlecaFrame"
        } |
        Select-Object -First 1
}

function Get-CurrentSessionLogLines {
    param([string]$Path, [datetime]$StartedAt, [int]$Tail = 160)

    # 只读取本次会话的记录，避免旧校验错误或旧加载标记影响判断。
    $lines = @(Get-Content -LiteralPath $Path -Tail $Tail -Encoding UTF8 -ErrorAction SilentlyContinue)
    foreach ($line in $lines) {
        if ([string]$line -match '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3})') {
            $timestamp = [datetime]::ParseExact(
                $Matches[1],
                'yyyy-MM-dd HH:mm:ss,fff',
                [Globalization.CultureInfo]::InvariantCulture
            )
            if ($timestamp -ge $StartedAt) { [string]$line }
        }
    }
}

function Assert-AlecaFrameSessionHealthy {
    param([datetime]$StartedAt)

    $traceRoot = Join-Path $env:LOCALAPPDATA "Overwolf\Log"
    $traces = @(Get-ChildItem -LiteralPath $traceRoot -Filter "Trace_*.log" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $StartedAt } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 2)
    $blockedPattern = "Closing extension '" + [regex]::Escape($appId) +
        "' - '(HashMismatch|InvalidSignature|MissingFile|MissingData)'"
    foreach ($trace in $traces) {
        $lines = @(Get-CurrentSessionLogLines -Path $trace.FullName -StartedAt $StartedAt)
        foreach ($line in $lines) {
            if ($line -match $blockedPattern) {
                $reason = $Matches[1]
                Write-LauncherLog "Overwolf blocked AlecaFrame: $line"
                throw "Overwolf 拒绝加载 AlecaFrame（$reason）。已停止重复启动，将恢复官方文件。请查看 $stateRoot\launcher.log。"
            }
        }
    }
}

function Wait-OverwolfExtensionReady {
    param([datetime]$StartedAt)

    # Overwolf can move or delay its trace logs after a Windows restart. The
    # launcher below also retries the actual app launch, so waiting only for a
    # specific trace line turns a slow cold start into a false failure.
    $traceRoot = Join-Path $env:LOCALAPPDATA "Overwolf\Log"
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Milliseconds 500
        $trace = Get-ChildItem -LiteralPath $traceRoot -Filter "Trace_*.log" -File `
            -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $StartedAt.AddSeconds(-2) } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($trace) {
            $tail = Get-Content -LiteralPath $trace.FullName -Tail 500 `
                -ErrorAction SilentlyContinue
            if ($tail -match "Loading extension '$appId") {
                Start-Sleep -Seconds 2
                return
            }
        }
    }
    Write-LauncherLog "Overwolf extension trace was not available; continuing with renderer-based readiness check"
}

function Start-AlecaFrameAndWait {
    param([int]$TimeoutSeconds = 60, [datetime]$SessionStartedAt = (Get-Date))

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $nextLaunch = Get-Date
    do {
        Assert-AlecaFrameSessionHealthy -StartedAt $SessionStartedAt
        if ((Get-Date) -ge $nextLaunch) {
            Start-Process -FilePath $launcherExe `
                -ArgumentList "-launchapp", $appId, "-from-desktop" -WindowStyle Hidden
            # 为冷启动预留初始化时间，避免频繁弹出又关闭应用。
            $nextLaunch = (Get-Date).AddSeconds(15)
        }
        Start-Sleep -Milliseconds 500
        $renderer = Get-AlecaFrameRenderer
        if ($renderer) {
            return $renderer
        }
    } while ((Get-Date) -lt $deadline)

    throw "AlecaFrame 启动超时。"
}

try {
    $overwolfInstall = Find-OverwolfInstall
    $overwolfExe = $overwolfInstall.Overwolf
    $launcherExe = $overwolfInstall.Launcher
    if (-not (Test-Path -LiteralPath $overwolfExe)) {
        throw "找不到 Overwolf：$overwolfExe"
    }
    if (-not (Test-Path -LiteralPath $launcherExe)) {
        throw "找不到 OverwolfLauncher：$launcherExe"
    }
    if (-not (Test-Path -LiteralPath $localizerSource)) {
        throw "缺少汉化词库：$localizerSource"
    }
    if (-not (Test-Path -LiteralPath $itemTranslationsSource)) {
        throw "缺少物品汉化词库：$itemTranslationsSource"
    }
    if (-not (Test-Path -LiteralPath $relicDucatsSource)) {
        throw "缺少遗物奖励杜卡德词库：$relicDucatsSource"
    }
    if (-not (Test-Path -LiteralPath $relicOcrBridgeSource)) {
        throw "缺少中文遗物 OCR 桥接脚本：$relicOcrBridgeSource"
    }
    if (-not (Test-Path -LiteralPath $relicOverlaySource)) {
        throw "缺少中文遗物奖励叠加层脚本：$relicOverlaySource"
    }
    if (-not (Test-Path -LiteralPath $relicRecommendationSource)) {
        throw "缺少中文遗物推荐显示脚本：$relicRecommendationSource"
    }
    if (-not (Test-Path -LiteralPath $relicPlannerCacheSource)) {
        throw "缺少遗物规划缓存脚本：$relicPlannerCacheSource"
    }
    if (-not (Test-Path -LiteralPath $inventoryPriceSyncSource)) {
        throw "缺少仓库价格同步脚本：$inventoryPriceSyncSource"
    }

    $versionDirectory = Get-LatestVersionDirectory
    Write-LauncherLog "Starting AlecaFrame ZH for $($versionDirectory.Name)"
    $relicOcrRequested = Get-RelicOcrEnabled
    $relicOcrAvailable = Test-RelicOcrPrerequisites
    $enableRelicOcr = $relicOcrRequested -and $relicOcrAvailable
    if ($enableRelicOcr) {
        Start-RelicChineseOcrHelper
    }
    elseif ($relicOcrRequested) {
        Write-LauncherLog "Chinese relic OCR skipped because optional prerequisites are not installed"
    }
    else {
        Write-LauncherLog "Chinese relic OCR disabled by AlecaFrame-ZH.settings.json"
    }

    Get-Process -Name "Overwolf" -ErrorAction SilentlyContinue | Stop-Process
    Start-Sleep -Seconds 4
    Restore-OfficialFiles -Version $versionDirectory.Name -VersionPath $versionDirectory.FullName

    $overwolfStartedAt = Get-Date
    # 0.311 对部分应用强制校验，仅禁用 extension-validation 已不足以加载汉化。
    # 报告模式记录校验差异而继续加载；仅影响本次会话，不改官方包、签名或校验清单。
    $overwolfArguments = @(
        "--ow-disable-features=extension-validation,read-opk-from-memory",
        "--ow-enable-features=force-validation-report-only"
    )
    Write-LauncherLog "Overwolf compatibility arguments: $($overwolfArguments -join ' ')"
    Start-Process -FilePath $overwolfExe `
        -ArgumentList $overwolfArguments -WindowStyle Hidden
    Wait-OverwolfExtensionReady -StartedAt $overwolfStartedAt

    # First launch uses untouched official files so Overwolf can complete its normal
    # integrity check and initialize AlecaFrame.
    $originalRenderer = Start-AlecaFrameAndWait -TimeoutSeconds 120 -SessionStartedAt $overwolfStartedAt
    Start-Sleep -Seconds 4

    Add-ChineseFiles -VersionPath $versionDirectory.FullName -EnableRelicOcr $enableRelicOcr
    $patchTime = Get-Date
    Write-LauncherLog "Chinese files injected; reloading AlecaFrame"

    # Reload only AlecaFrame's renderer so the rest of Overwolf remains running.
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq "OverwolfBrowser.exe" -and
            $_.CommandLine -match "AlecaFrame"
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
        }
    Start-Sleep -Seconds 3

    $null = Start-AlecaFrameAndWait -TimeoutSeconds 120 -SessionStartedAt $overwolfStartedAt

    $loaded = $false
    $mainLog = Join-Path $env:LOCALAPPDATA "Overwolf\Log\Apps\AlecaFrame\MainWindow.html.log"
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        Start-Sleep -Milliseconds 500
        Assert-AlecaFrameSessionHealthy -StartedAt $overwolfStartedAt
        if (Test-Path -LiteralPath $mainLog) {
            $logItem = Get-Item -LiteralPath $mainLog
            if ($logItem.LastWriteTime -ge $patchTime.AddSeconds(-2)) {
                $tail = @(Get-CurrentSessionLogLines -Path $mainLog -StartedAt $patchTime -Tail 120)
                # 固定 ASCII 标记避免中文日志乱码导致误报加载失败。
                if ($tail -match '\[AlecaFrame-ZH\] loaded') {
                    $loaded = $true
                    break
                }
            }
        }
    }
    if (-not $loaded) {
        throw "中文脚本未能加载，请查看 $stateRoot\launcher.log"
    }

    # 继续观察短暂时间，避免把瞬间出现的加载记录当作稳定启动。
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        Start-Sleep -Milliseconds 500
        Assert-AlecaFrameSessionHealthy -StartedAt $overwolfStartedAt
        if (-not (Get-AlecaFrameRenderer)) {
            throw "汉化页面加载后 AlecaFrame 意外退出，将恢复官方文件。"
        }
    }
    Write-LauncherLog "Chinese UI loaded successfully; renderer remained running for 5 seconds"
}
catch {
    # 保存启动错误，避免恢复过程覆盖弹窗需要显示的信息。
    $launchFailure = $_.Exception.Message
    Write-LauncherLog "ERROR: $launchFailure"
    try {
        Get-Process -Name "Overwolf" -ErrorAction SilentlyContinue | Stop-Process
        Start-Sleep -Seconds 3
        if ($versionDirectory) {
            Restore-OfficialFiles -Version $versionDirectory.Name -VersionPath $versionDirectory.FullName
        }
    }
    catch {
        Write-LauncherLog "RESTORE ERROR: $($_.Exception.Message)"
    }
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show(
        $launchFailure,
        "AlecaFrame 中文启动失败",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
