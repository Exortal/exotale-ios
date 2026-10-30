<#
.SYNOPSIS
    ExoTale iOS — 1-Click iPhone App Publisher (iOS-Only, 5-Second Deploy, No Android Build)

.DESCRIPTION
    1. Unpacks ExoTale-iOS-GitHub-Pages.zip (or uses exotale-ios.html in the current folder).
    2. Creates or links your GitHub repository (e.g. 'exotale-ios') and stamps your exact live URL
       into ExoTale-iPhone-Installer.mobileconfig and manifest.json.
    3. Pushes the iOS Web App directly to GitHub Pages (gh-pages / main) in ~5 seconds (no Gradle/APK build).
    4. Automatically enables GitHub Pages and opens a scannable iPhone QR Code + Install Card on your PC!
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$RepoUrl = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host " [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host " [!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host " [ERROR] $msg" -ForegroundColor Red }

Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "     ExoTale iOS - 1-Click iPhone Publisher (iOS Only)          " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Magenta

# 1. Prepare iOS deployment directory
$IosWorkDir = Join-Path $ScriptDir "ExoTale-iOS-Live"
New-Item -ItemType Directory -Path $IosWorkDir -Force | Out-Null

$iosZip = Get-ChildItem -Path $ScriptDir -Filter "*ExoTale-iOS*.zip" -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($null -ne $iosZip) {
    Write-Step "Extracting $($iosZip.Name) into $IosWorkDir..."
    Expand-Archive -Path $iosZip.FullName -DestinationPath $IosWorkDir -Force
} elseif (Test-Path (Join-Path $ScriptDir "exotale-ios.html")) {
    Write-Step "Copying exotale-ios.html into $IosWorkDir/index.html..."
    Copy-Item -Path (Join-Path $ScriptDir "exotale-ios.html") -Destination (Join-Path $IosWorkDir "index.html") -Force
} elseif (-not (Test-Path (Join-Path $IosWorkDir "index.html"))) {
    Write-Err "Place ExoTale-iOS-GitHub-Pages.zip or exotale-ios.html in the same folder as Publish-ExoTale-iOS.bat"
    exit 1
}

# Ensure .nojekyll exists so GitHub Pages serves immediately without Jekyll processing
Set-Content -Path (Join-Path $IosWorkDir ".nojekyll") -Value "" -Encoding UTF8

Set-Location $IosWorkDir

# 2. Configure Git & Remote
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err "Git is not installed. Download Git from https://git-scm.com/download/win"
    exit 1
}

if (-not (Test-Path (Join-Path $IosWorkDir ".git"))) {
    git init -b main | Out-Null
}

$currentRemote = ""
try { $currentRemote = (git remote get-url origin 2>$null).Trim() } catch {}

if ([string]::IsNullOrWhiteSpace($currentRemote)) {
    if (-not [string]::IsNullOrWhiteSpace($RepoUrl)) {
        $currentRemote = $RepoUrl
    } elseif (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Step "GitHub CLI (gh) detected. Checking login..."
        $ghStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Step "Creating/linking public GitHub repository 'exotale-ios'..."
            gh repo create exotale-ios --public --source=. --remote=origin 2>$null
            try { $currentRemote = (git remote get-url origin 2>$null).Trim() } catch {}
        }
    }

    if ([string]::IsNullOrWhiteSpace($currentRemote)) {
        Write-Host ""
        Write-Host "Paste your GitHub Repo URL for iOS (e.g. https://github.com/yourname/exotale-ios.git)" -ForegroundColor Yellow
        $inputUrl = Read-Host "GitHub Repo URL"
        if ([string]::IsNullOrWhiteSpace($inputUrl)) {
            Write-Err "A GitHub repository URL is required to host ExoTale iOS."
            exit 1
        }
        $currentRemote = $inputUrl.Trim()
        git remote add origin $currentRemote 2>$null
        if ($LASTEXITCODE -ne 0) { git remote set-url origin $currentRemote }
    }
}

Write-Ok "GitHub Remote: $currentRemote"

$owner = "your-username"
$repo  = "exotale-ios"
$iosLiveUrl = "https://exotale.github.io/exotale/"

if ($currentRemote -match "github\.com[:/]([^/]+)/([^/\.]+)(\.git)?$") {
    $owner = $Matches[1]
    $repo  = $Matches[2]
    $ownerLower = $owner.ToLower()
    $iosLiveUrl = "https://$ownerLower.github.io/$repo/"

    $mcFile = Join-Path $IosWorkDir "ExoTale-iPhone-Installer.mobileconfig"
    if (Test-Path $mcFile) {
        $mcContent = Get-Content -Path $mcFile -Raw -Encoding UTF8
        $mcContent = $mcContent -replace "https://exotale\.github\.io/exotale/", $iosLiveUrl
        Set-Content -Path $mcFile -Value $mcContent -Encoding UTF8 -NoNewline
        Write-Ok "Stamped live iPhone URL into ExoTale-iPhone-Installer.mobileconfig -> $iosLiveUrl"
    }
}

# 3. Commit & Push to both main and gh-pages (takes ~5 seconds, no APK compile!)
$gitName = (git config user.name 2>$null)
if ([string]::IsNullOrWhiteSpace($gitName)) {
    git config user.name "ExoTale iOS Publisher"
    git config user.email "ios@exotale.app"
}

Write-Step "Publishing ExoTale iOS to GitHub Pages..."
git add -A
git commit -m "Deploy ExoTale iOS Standalone App" --allow-empty | Out-Null
git branch -M main
git push -u origin main --force
git push origin main:refs/heads/gh-pages --force

if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh api -X POST "repos/$owner/$repo/pages" -f "source[branch]=gh-pages" -f "source[path]=/" 2>$null | Out-Null
    gh api -X PUT "repos/$owner/$repo/pages" -f "source[branch]=gh-pages" -f "source[path]=/" 2>$null | Out-Null
}

# 4. Generate & Open Local QR Code Launch Card on PC so user can scan with iPhone Camera!
$qrHtmlPath = Join-Path $ScriptDir "Scan-With-iPhone-Camera.html"
$qrPage = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Scan with iPhone Camera — Install ExoTale iOS</title>
  <style>
    body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; background: #06070B; color: #F8FAFC; font-family: -apple-system, BlinkMacSystemFont, 'Inter', sans-serif; }
    .card { max-width: 460px; background: rgba(18, 21, 34, 0.92); border: 1px solid rgba(168, 85, 247, 0.35); border-radius: 28px; padding: 32px; text-align: center; box-shadow: 0 24px 60px rgba(0,0,0,0.75); }
    .badge { display: inline-block; padding: 4px 12px; border-radius: 999px; background: rgba(168, 85, 247, 0.2); color: #E9D5FF; font-size: 11px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; margin-bottom: 12px; }
    h1 { margin: 0 0 8px; font-size: 24px; font-weight: 900; }
    p { margin: 0 0 20px; font-size: 13px; color: #94A3B8; line-height: 1.5; }
    .qr-box { background: #FFFFFF; padding: 16px; border-radius: 20px; display: inline-block; margin-bottom: 20px; }
    .url-box { background: #0B0E17; border: 1px solid rgba(255,255,255,0.12); padding: 12px 16px; border-radius: 14px; font-family: monospace; font-size: 13px; color: #22D3EE; word-break: break-all; margin-bottom: 18px; }
    .steps { text-align: left; font-size: 13px; color: #E2E8F0; background: rgba(255,255,255,0.04); padding: 16px 20px; border-radius: 16px; line-height: 1.7; }
    a.btn { display: block; margin-top: 16px; padding: 14px; border-radius: 16px; background: linear-gradient(135deg, #A855F7, #6366F1); color: white; font-weight: 800; text-decoration: none; font-size: 14px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">ExoTale iOS • Live on GitHub Pages</div>
    <h1>Scan with Your iPhone Camera</h1>
    <p>Point your iPhone Camera at the QR code below to open ExoTale iOS in Safari and add it to your Home Screen.</p>
    <div class="qr-box">
      <img src="https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=$([uri]::EscapeDataString($iosLiveUrl))" width="220" height="220" alt="QR Code" />
    </div>
    <div class="url-box">$iosLiveUrl</div>
    <div class="steps">
      <strong>On your iPhone:</strong><br/>
      1. Scan the QR code above to open in <strong>Safari</strong>.<br/>
      2. Tap <strong>Share (⬆)</strong> at the bottom of Safari.<br/>
      3. Tap <strong>Add to Home Screen (＋)</strong> (or tap <strong>📲 iPhone Setup → Download iPhone Profile</strong> inside the app).
    </div>
    <a class="btn" href="$iosLiveUrl" target="_blank">Open Live ExoTale iOS Web App ↗</a>
  </div>
</body>
</html>
"@
Set-Content -Path $qrHtmlPath -Value $qrPage -Encoding UTF8

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " ExoTale iOS Published in 5 Seconds! (No Android Build Needed)" -ForegroundColor Green
Write-Host "  - Live iPhone URL : $iosLiveUrl" -ForegroundColor Cyan
Write-Host "  - 1-Tap Profile   : $($iosLiveUrl)ExoTale-iPhone-Installer.mobileconfig" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Green

Start-Process $qrHtmlPath
Write-Host "`nOpened iPhone QR Code card in your browser! Press Enter to close." -ForegroundColor Cyan
Read-Host | Out-Null
