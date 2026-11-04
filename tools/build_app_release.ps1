# Builds the Android APK and the Windows setup for a GitHub release.
# Result: app\build\release\thask-<version>.apk and thask-setup-<version>.exe (version from app\pubspec.yaml).
# With -Tag the files are attached to that existing GitHub release (gh CLI, replaces files of the same name).
#
# The in-app updater looks for exactly these file names. The APK must be signed with the release key from
# the private companion repo (tHAsk-local\android\release.properties); without it the script stops.
param([string]$Tag)
$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."
$appDir = "$root\app"

$companion = @("$root\local\android", "$root\..\tHAsk-local\android") | Where-Object { Test-Path "$_\release.properties" } | Select-Object -First 1
if (-not $companion) { throw 'release.properties not found (tHAsk-local\android); the APK would be signed with the debug key' }

$line = Select-String -Path "$appDir\pubspec.yaml" -Pattern '^version:\s*([0-9.]+)' | Select-Object -First 1
$version = $line.Matches[0].Groups[1].Value
$out = "$appDir\build\release"
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -File | Remove-Item

Push-Location $appDir
try {
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed' }
} finally {
    Pop-Location
}
Copy-Item "$appDir\build\app\outputs\flutter-apk\app-release.apk" "$out\thask-$version.apk"

& "$appDir\windows\installer\build_installer.ps1"
Copy-Item "$appDir\build\installer\thask-setup-$version.exe" "$out\thask-setup-$version.exe"

Get-ChildItem $out -File | ForEach-Object {
    '{0}  {1:N1} MB  sha256 {2}' -f $_.Name, ($_.Length / 1MB), (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
}

if ($Tag) {
    gh release upload $Tag "$out\thask-$version.apk" "$out\thask-setup-$version.exe" --clobber --repo Schumey/tHAsk
    if ($LASTEXITCODE -ne 0) { throw 'gh release upload failed' }
}
