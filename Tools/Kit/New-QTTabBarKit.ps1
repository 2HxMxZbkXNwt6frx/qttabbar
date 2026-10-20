<#
.SYNOPSIS
    Puts what it takes to set up this QTTabBar fork on another Windows 11 26H2 PC in one folder,
    and a .zip of it: the MSI, the tools and a step-by-step guide (Japanese).

.DESCRIPTION
    Takes the newest Installer\bin\Release\en-US\QTTabBar Setup *.msi (build it first with
    Installer\Build-Installer.ps1) and the QTTabBar.dll it packages, and writes

      <OutDir>\QTTabBar-26H2-Kit\
        手順書.md                       the guide (README-ja.md next to this script)
        QTTabBar Setup <version>.msi
        QTTabBar.dll.sha256             what QTTabBarDoctor checks the installed DLL against
        kit-info.txt                    when and from which commit the kit was made
        tools\                          QTTabBarDoctor.ps1, Win11ToolbarFix.ps1,
                                        Import-QTTabBar2048Settings.ps1 (+ .Data.psd1)
        settings\                       -IncludeSettings: this PC's QTTabBar settings (reg export),
                                        and the -ExtraFiles (e.g. an ExplorerPatcher .reg)
      <OutDir>\QTTabBar-26H2-Kit-<yyyyMMdd-HHmm>.zip

    The settings hold personal paths and history: the kit must not be written into the
    repository (refused when -IncludeSettings or -ExtraFiles is given).

.EXAMPLE
    .\Tools\Kit\New-QTTabBarKit.ps1 -IncludeSettings -ExtraFiles ..\user_settings\ExplorerPatcher_26100.8457.70.4.reg
#>
param(
    # Default: a "dist" folder next to the repository.
    [string]$OutDir,
    # Add this PC's QTTabBar settings (HKCU\Software\QTTabBar) to the kit.
    [switch]$IncludeSettings,
    # Other files for the kit's settings folder.
    [string[]]$ExtraFiles,
    [switch]$NoZip
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $OutDir) { $OutDir = Join-Path (Split-Path $repo -Parent) 'dist' }
$OutDir = [IO.Path]::GetFullPath($OutDir)
if (($IncludeSettings -or $ExtraFiles) -and ($OutDir + '\').StartsWith($repo + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Personal settings must not go into the repository: choose an -OutDir outside $repo."
}

# --- the build ------------------------------------------------------------------------------

$msi = Get-ChildItem -LiteralPath (Join-Path $repo 'Installer\bin\Release\en-US') -Filter 'QTTabBar Setup *.msi' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$dll = Get-Item -LiteralPath (Join-Path $repo 'QTTabBar\bin\Release\QTTabBar.dll') -ErrorAction SilentlyContinue
if (-not $msi -or -not $dll) { throw 'No build found. Run Installer\Build-Installer.ps1 first.' }

# The DLL must be the one inside the MSI: compare with the size in the MSI's File table.
$installer = New-Object -ComObject WindowsInstaller.Installer
# Rows of an MSI query, each as an array of its fields (MSI SQL has no LIKE).
function Get-MsiRows([string]$Query, [int]$Fields) {
    $db = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($msi.FullName, 0))
    $view = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @($Query))
    try {
        [void]$view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
        while ($true) {
            $rec = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
            if ($null -eq $rec) { break }
            , @(1..$Fields | ForEach-Object { $rec.GetType().InvokeMember('StringData', 'GetProperty', $null, $rec, $_) })
        }
    } finally {
        [void]$view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($view)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($db)
    }
}
function Get-MsiProperty([string]$Name) {
    $row = @(Get-MsiRows "SELECT Value FROM Property WHERE Property = '$Name'" 1)
    if ($row.Count) { return $row[0][0] }
    return $null
}
# FileName is "SHORT~1.DLL|LongName.dll" or just the name.
$msiDllSize = @(Get-MsiRows 'SELECT FileName, FileSize FROM File' 2 | Where-Object { ($_[0] -split '\|')[-1] -eq 'QTTabBar.dll' } | ForEach-Object { $_[1] }) | Select-Object -First 1
if ($msiDllSize -and [int64]$msiDllSize -ne $dll.Length) {
    throw "QTTabBar.dll ($($dll.Length) bytes) is not the one in $($msi.Name) ($msiDllSize bytes): rebuild with Installer\Build-Installer.ps1."
}
$productCode = Get-MsiProperty 'ProductCode'
$version = Get-MsiProperty 'ProductVersion'
$hash = (Get-FileHash -LiteralPath $dll.FullName -Algorithm SHA256).Hash

# --- the kit folder -------------------------------------------------------------------------

$kit = Join-Path $OutDir 'QTTabBar-26H2-Kit'
if (Test-Path $kit) {
    # Only ever replace a folder this script made.
    if (-not (Test-Path (Join-Path $kit 'kit-info.txt'))) { throw "$kit exists and is not a kit made by this script." }
    Remove-Item -LiteralPath $kit -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $kit, (Join-Path $kit 'tools') | Out-Null

$utf8Bom = New-Object Text.UTF8Encoding($true)   # Notepad and Windows PowerShell read it either way
[IO.File]::WriteAllText((Join-Path $kit '手順書.md'), (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'README-ja.md') -Raw -Encoding UTF8), $utf8Bom)
Copy-Item -LiteralPath $msi.FullName -Destination $kit
Set-Content -LiteralPath (Join-Path $kit 'QTTabBar.dll.sha256') -Value "$hash  QTTabBar.dll" -Encoding ASCII
foreach ($tool in 'Tools\QTTabBarDoctor\QTTabBarDoctor.ps1', 'Tools\Win11ToolbarFix\Win11ToolbarFix.ps1',
                  'Tools\Import2048Settings\Import-QTTabBar2048Settings.ps1', 'Tools\Import2048Settings\Import-QTTabBar2048Settings.Data.psd1') {
    Copy-Item -LiteralPath (Join-Path $repo $tool) -Destination (Join-Path $kit 'tools')
}

$settingsNote = 'none'
if ($IncludeSettings -or $ExtraFiles) {
    $settings = Join-Path $kit 'settings'
    New-Item -ItemType Directory -Force -Path $settings | Out-Null
    $names = @()
    if ($IncludeSettings) {
        if (-not (Test-Path 'HKCU:\Software\QTTabBar')) { throw 'There are no QTTabBar settings on this PC to include.' }
        $name = "QTTabBar-settings-{0}-{1:yyyyMMdd}.reg" -f $env:COMPUTERNAME, (Get-Date)
        # reg.exe may report success on stderr: only its exit code counts.
        $ErrorActionPreference = 'Continue'
        & reg.exe export 'HKCU\Software\QTTabBar' (Join-Path $settings $name) /y 2>&1 | Out-Null
        $exit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($exit -ne 0) { throw "reg export failed (exit $exit)." }
        $names += $name
    }
    foreach ($f in $ExtraFiles) {
        Copy-Item -LiteralPath $f -Destination $settings
        $names += (Split-Path $f -Leaf)
    }
    $settingsNote = $names -join ', '
}

$commit = 'unknown'
if (Get-Command git -ErrorAction SilentlyContinue) {
    $commit = (& git -C $repo rev-parse --short HEAD 2>$null)
    if (& git -C $repo status --porcelain --untracked-files=no 2>$null) { $commit += ' (with uncommitted changes)' }
}
@(
    'QTTabBar 26H2 kit'
    ('Made          : {0:yyyy-MM-dd HH:mm} on {1}' -f (Get-Date), $env:COMPUTERNAME)
    ('MSI           : {0}  {1} bytes  built {2:yyyy-MM-dd HH:mm}' -f $msi.Name, $msi.Length, $msi.LastWriteTime)
    ('Version       : {0}  ProductCode {1}' -f $version, $productCode)
    ('QTTabBar.dll  : SHA256 {0}  {1} bytes' -f $hash, $dll.Length)
    ('Source commit : {0}' -f $commit)
    ('Settings      : {0}' -f $settingsNote)
) | Set-Content -LiteralPath (Join-Path $kit 'kit-info.txt') -Encoding UTF8

# --- the zip --------------------------------------------------------------------------------

if (-not $NoZip) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = Join-Path $OutDir ('QTTabBar-26H2-Kit-{0:yyyyMMdd-HHmm}.zip' -f (Get-Date))
    if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
    # UTF-8 entry names: the guide's name is Japanese.
    [IO.Compression.ZipFile]::CreateFromDirectory($kit, $zip, [IO.Compression.CompressionLevel]::Optimal, $true, [Text.Encoding]::UTF8)
    Write-Host "Zip : $zip"
}
Write-Host "Kit : $kit"
Get-Content -LiteralPath (Join-Path $kit 'kit-info.txt') | ForEach-Object { Write-Host "  $_" }
