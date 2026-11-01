# Builds the Windows app in release mode and packs it with Inno Setup.
# Result: app\build\installer\thask-setup-<version>.exe
$ErrorActionPreference = 'Stop'
$appDir = Resolve-Path "$PSScriptRoot\..\.."

$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw 'Inno Setup 6 not found: winget install --id JRSoftware.InnoSetup --exact --scope user'
}

# "version: 0.7.0+4" -> "0.7.0"
$line = Select-String -Path "$appDir\pubspec.yaml" -Pattern '^version:\s*([0-9.]+)' | Select-Object -First 1
$version = $line.Matches[0].Groups[1].Value

Push-Location $appDir
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
} finally {
    Pop-Location
}

& $iscc "/DAppVersion=$version" "$PSScriptRoot\thask.iss"
if ($LASTEXITCODE -ne 0) { throw 'ISCC failed' }
