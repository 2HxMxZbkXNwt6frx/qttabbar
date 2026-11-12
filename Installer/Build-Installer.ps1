<#
.SYNOPSIS
    Bumps QTTabBar's version everywhere it needs to live, then builds the DLL,
    MSI, and bootstrapper. Run from any directory.

.EXAMPLE
    .\Installer\Build-Installer.ps1 -Version 1.6.4 -ForkId 26h2.4

    Builds "QTTabBar Setup 1.6.4-26h2.4.msi": upstream's version 1.6.4, then this fork's id.
    The app, the DLL's product version and Programs and Features show 1.6.4-26h2.4. The
    number at the end of the id becomes the fourth part of the file and MSI versions
    (1.6.4.4); the assembly version stays 1.6.4.0.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+(\.\d+)?$')]
    [string]$Version,
    # This fork's id, e.g. 26h2.4. Letters, digits and dots, ending in the build number.
    [ValidatePattern('^[0-9a-z]+(\.[0-9a-z]+)*\.\d{1,4}$')]
    [string]$ForkId,
    # v143 covers every VS2022 MSVC; pass v145 when only VS2026 Build Tools are installed.
    [string]$PlatformToolset = 'v143',
    # Folder containing candle.exe/light.exe. Defaults to %WIX%\bin, then the WiX install folder.
    [string]$WixDir
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$installerDir = $PSScriptRoot

# The CLR always pads an assembly identity to 4 parts (AssemblyVersion "1.5.7"
# loads as "1.5.7.0"), and the installer's StrongName must match that padded
# identity exactly or COM/assembly binding breaks. So a 3-part release version
# stays 3-part everywhere user-facing (product name, MSI filename, MSI/bundle
# ProductVersion) but the assembly identity and StrongName get the .0.
$assemblyVersion = if ($Version -match '^\d+\.\d+\.\d+$') { "$Version.0" } else { $Version }

# With a fork id: "1.6.4-26h2.4" is the name everywhere a person reads it, and the id's last
# number is the fourth part of the file version and of the MSI's ProductVersion (1.6.4.4).
# Windows Installer ignores that part when it compares versions, which is what the Upgrade
# table relies on to let any build of the same base replace another.
if ($ForkId) {
    if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "-ForkId needs a three-part -Version, like 1.6.4" }
    $displayVersion = "$Version-$ForkId"
    $numericVersion = "$Version.$([int]($ForkId -replace '^.*\.', ''))"
} else {
    $displayVersion = $Version
    $numericVersion = $Version
}
$fileVersion = if ($numericVersion -match '^\d+\.\d+\.\d+$') { "$numericVersion.0" } else { $numericVersion }
$baseVersion = ($assemblyVersion -split '\.')[0..2] -join '.'

# --- 1. Stamp the version into the three files that still need it ---------

$assemblyInfo = Join-Path $root "QTTabBar\Properties\AssemblyInfo.cs"
(Get-Content $assemblyInfo -Raw) `
    -replace 'AssemblyVersion\("[\d.]+"\)', "AssemblyVersion(`"$assemblyVersion`")" `
    -replace 'AssemblyFileVersion\("[\d.]+"\)', "AssemblyFileVersion(`"$fileVersion`")" `
    -replace 'AssemblyInformationalVersion\("[^"]*"\)', "AssemblyInformationalVersion(`"$displayVersion`")" `
    | Set-Content $assemblyInfo -NoNewline
Write-Host "Updated $assemblyInfo"

$installerWxs = Join-Path $installerDir "Installer.wxs"
(Get-Content $installerWxs -Raw) `
    -replace '(?<=<\?define BaseVersion=")[\d.]+', $baseVersion `
    -replace '(?<=<\?define ProductVersion=")[\d.]+', $numericVersion `
    -replace '(?<=<\?define VersionString=")[^"]+', $displayVersion `
    -replace '(?<=StrongName="QTTabBar, Version=)[\d.]+', $assemblyVersion `
    | Set-Content $installerWxs -NoNewline
Write-Host "Updated $installerWxs"

$bundleWxs = Join-Path $installerDir "Bundle.wxs"
(Get-Content $bundleWxs -Raw) `
    -replace '(?<=<Bundle Name="QTTabBar )[^"]+', $displayVersion `
    -replace '(?<=\n            Version=")[\d.]+(?=")', $numericVersion `
    -replace '(?<=QTTabBar Setup )[^"]+(?=\.msi")', $displayVersion `
    | Set-Content $bundleWxs -NoNewline
Write-Host "Updated $bundleWxs"

# --- 2. Build every payload the installer packages ---------------------

# On CI, microsoft/setup-msbuild puts msbuild on PATH; locally fall back to the
# newest Visual Studio 2022+ install.
$msbuild = (Get-Command msbuild -ErrorAction SilentlyContinue).Source
if (-not $msbuild) {
    $msbuild = Get-ChildItem "C:\Program Files*\Microsoft Visual Studio\20*\*\MSBuild\Current\Bin\MSBuild.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(2017|2019)\\' } | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $msbuild) { throw "MSBuild.exe not found" }

# Build the code projects explicitly rather than the whole .sln: the solution
# also contains Installer.wixproj, which msbuild builds in parallel before the
# plugin DLLs exist (WiX projects have no project references to them), so a
# solution build fails with LGHT0103. QTTabBar.csproj pulls in BandObjectLib and
# QTPluginLib via project references; the plugins and SetHome are standalone.
# (Sample/SamplePlugin is intentionally omitted - the installer doesn't ship it.)
$managedProjects = @(
    "QTTabBar\QTTabBar.csproj"
    "Plugins\CreateNewItem\CreateNewItem.csproj"
    "Plugins\QTClock\QTClock.csproj"
    "Plugins\QTFileTools\QTFileTools.csproj"
    "Plugins\QTFolderButton\QTFolderButton.csproj"
    "Plugins\QTViewModeButton\ViewModeButton.csproj"
    "Plugins\QTWindowManager\QTWindowManager.csproj"
    "Plugins\ShowStatusBar\ShowStatusBar.csproj"
    "Plugins\MigemoLoader\MigemoLoader.csproj"
    "Plugins\Memo\Memo.csproj"
    "Plugins\QTQuick\QTQuick.csproj"
    "Plugins\TurnOffRepeat\TurnOffRepeat.csproj"
    "Plugins\ActivateByMouseHover\ActivateByMouseHover.csproj"
    "SetHome\SetHome.csproj"
)
foreach ($proj in $managedProjects) {
    & $msbuild "$root\$proj" /p:Configuration=Release "/p:SolutionDir=$root\" /nologo /v:minimal
    if ($LASTEXITCODE -ne 0) { throw "build failed: $proj" }
}

# Native hook, both platforms. The vcxproj files don't pin a PlatformToolset, so
# on a runner without VS2010 they default to v100 and fail with MSB8020 - force a
# modern toolset (v143 covers every VS2022+ MSVC). QTHookLib links libMinHook, so
# build that first for each platform. Win32 -> QTHookLib32.dll, x64 -> ...64.dll.
$vcProps = @("/p:PlatformToolset=$PlatformToolset", '/p:WindowsTargetPlatformVersion=10.0')
foreach ($plat in @('Win32', 'x64')) {
    & $msbuild "$root\MinHook\libMinHook.vcxproj" /p:Configuration=Release /p:Platform=$plat $vcProps /nologo /v:minimal
    if ($LASTEXITCODE -ne 0) { throw "libMinHook $plat build failed" }
    & $msbuild "$root\QTHookLib\QTHookLib.vcxproj" /p:Configuration=Release /p:Platform=$plat $vcProps /nologo /v:minimal
    if ($LASTEXITCODE -ne 0) { throw "QTHookLib $plat build failed" }
}
# The MSI's custom actions; the package is x86, so this one is Win32 only.
& $msbuild "$root\InstallerHelper\InstallerHelper.vcxproj" /p:Configuration=Release /p:Platform=Win32 $vcProps /nologo /v:minimal
if ($LASTEXITCODE -ne 0) { throw "InstallerHelper build failed" }

# --- 3. Build the MSI ---------------------------------------------------

$wix = $WixDir
if (-not $wix -and $env:WIX -and (Test-Path "$env:WIX\bin\candle.exe")) { $wix = "$env:WIX\bin" }
if (-not $wix) {
    $wix = Get-ChildItem "C:\Program Files*\WiX Toolset v3.*\bin\candle.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty DirectoryName
}
if (-not $wix -or -not (Test-Path "$wix\candle.exe")) { throw "WiX Toolset v3.x not found (pass -WixDir, or expected under 'WiX Toolset v3.*\bin')" }
Push-Location $installerDir
try {
    New-Item -ItemType Directory -Force -Path "obj\Release", "bin\Release\en-US" | Out-Null

    & "$wix\candle.exe" -ext "$wix\WixNetFxExtension.dll" -ext "$wix\WixUIExtension.dll" -ext "$wix\WixUtilExtension.dll" -out obj\Release\ Installer.wxs CustomWelcomeEulaDlg.wxs CustomWixUI_Minimal.wxs
    if ($LASTEXITCODE -ne 0) { throw "candle.exe failed on Installer.wxs" }

    # ICE38/ICE64/ICE91 take StartupFolder for a user's folder; with ALLUSERS=1 it is the all-users one.
    & "$wix\light.exe" -ext "$wix\WixNetFxExtension.dll" -ext "$wix\WixUIExtension.dll" -ext "$wix\WixUtilExtension.dll" -cultures:en-US -loc lang.wxl -sice:ICE80 -sice:ICE61 -sice:ICE38 -sice:ICE64 -sice:ICE91 -out "bin\Release\en-US\QTTabBar Setup $displayVersion.msi" obj\Release\Installer.wixobj obj\Release\CustomWelcomeEulaDlg.wixobj obj\Release\CustomWixUI_Minimal.wixobj
    if ($LASTEXITCODE -ne 0) { throw "light.exe failed on Installer.wxs" }

    # --- 4. Build the bootstrapper EXE ---------------------------------

    New-Item -ItemType Directory -Force -Path "obj\Release\Bundle" | Out-Null

    & "$wix\candle.exe" -ext "$wix\WixBalExtension.dll" -ext "$wix\WixNetFxExtension.dll" -out obj\Release\Bundle\Bundle.wixobj Bundle.wxs
    if ($LASTEXITCODE -ne 0) { throw "candle.exe failed on Bundle.wxs" }

    & "$wix\light.exe" -ext "$wix\WixBalExtension.dll" -ext "$wix\WixNetFxExtension.dll" -out "bin\Release\QTTabBar Setup $displayVersion.exe" obj\Release\Bundle\Bundle.wixobj
    if ($LASTEXITCODE -ne 0) { throw "light.exe failed on Bundle.wxs" }
}
finally {
    Pop-Location
}

Write-Host "`nBuilt: $installerDir\bin\Release\en-US\QTTabBar Setup $displayVersion.msi and $installerDir\bin\Release\QTTabBar Setup $displayVersion.exe"
