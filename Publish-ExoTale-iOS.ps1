<#
.SYNOPSIS
    ExoTale iOS — 1-Click Publisher (5-Second Deploy to GitHub Pages)
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
function Write-Err($msg)  { Write-Host " [ERROR] $msg" -ForegroundColor Red }

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "          ExoTale iOS - 1-Click GitHub Pages Publisher          " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

$IosWorkDir = Join-Path $ScriptDir "ExoTale-iOS-Live"
New-Item -ItemType Directory -Path $IosWorkDir -Force | Out-Null

# Clean any old cached files inside ExoTale-iOS-Live (preserving .git)
Get-ChildItem -Path $IosWorkDir -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

$iosZip = Get-ChildItem -Path $ScriptDir -Filter "*ExoTale-iOS*.zip" -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($null -ne $iosZip) {
    Write-Step "Extracting $($iosZip.Name) into $IosWorkDir..."
    Expand-Archive -Path $iosZip.FullName -DestinationPath $IosWorkDir -Force
} elseif (Test-Path (Join-Path $ScriptDir "exotale-ios.html")) {
    Write-Step "Copying exotale-ios.html into $IosWorkDir/index.html..."
    Copy-Item -Path (Join-Path $ScriptDir "exotale-ios.html") -Destination (Join-Path $IosWorkDir "index.html") -Force
} else {
    Write-Err "Place ExoTale-iOS-GitHub-Pages.zip or exotale-ios.html in the same folder as Publish-ExoTale-iOS.bat"
    exit 1
}

Set-Content -Path (Join-Path $IosWorkDir ".nojekyll") -Value "" -Encoding UTF8
Set-Location $IosWorkDir

if (-not (Test-Path (Join-Path $IosWorkDir ".git"))) {
    git init -b main | Out-Null
}

$currentRemote = ""
try { $currentRemote = (git remote get-url origin 2>$null).Trim() } catch {}

if ([string]::IsNullOrWhiteSpace($currentRemote)) {
    if (-not [string]::IsNullOrWhiteSpace($RepoUrl)) {
        $currentRemote = $RepoUrl
    } else {
        Write-Host ""
        Write-Host "Paste your GitHub Repo URL (e.g. https://github.com/exortal/exotale-ios.git)" -ForegroundColor Yellow
        $inputUrl = Read-Host "GitHub Repo URL"
        $currentRemote = $inputUrl.Trim()
        git remote add origin $currentRemote 2>$null
        if ($LASTEXITCODE -ne 0) { git remote set-url origin $currentRemote }
    }
}

$gitName = (git config user.name 2>$null)
if ([string]::IsNullOrWhiteSpace($gitName)) {
    git config user.name "ExoTale Publisher"
    git config user.email "ios@exotale.app"
}

Write-Step "Pushing clean ExoTale v0.43.1 to GitHub Pages..."
git add -A
git commit -m "Deploy ExoTale v0.43.1 Clean iOS App" --allow-empty | Out-Null
git branch -M main
git push -u origin main --force
git push origin main:refs/heads/gh-pages --force

Write-Ok "Published! Refresh your browser on https://exortal.github.io/exotale-ios/"
Write-Host "`nPress Enter to close." -ForegroundColor Cyan
Read-Host | Out-Null
