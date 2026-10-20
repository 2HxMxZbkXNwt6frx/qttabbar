<#
.SYNOPSIS
    Finds out why QTTabBar behaves differently on this PC, and repairs a stale installation.

.DESCRIPTION
    -Action Status   (default, read-only, no admin)
        Reports what is installed and running: QTTabBar's Windows Installer products and Setup.exe
        bundles, the QTTabBar.dll in the GAC (is it the build you installed?), Explorer processes
        that started before it changed, Restart Manager trouble at the last install, the Windows
        feature flags that change what Explorer does on a middle click (native tabs) or remove the
        classic toolbar, every User-priority (ViVeTool) override, the Explorer windows (native tabs,
        navigation pane), QTTabBar's mouse bindings and its exception log. Saved to -ReportPath
        (default: the Desktop) as well.

    -Action Watch    (read-only, no admin)
        For -Seconds (default 30) prints Explorer windows and native tabs as they appear, change
        and go. Start it, then middle-click a folder in the navigation pane: it shows whether
        Windows opened something of its own next to QTTabBar's tab.

    -Action Repair   (run from a NORMAL PowerShell; asks for admin rights for the install step)
        Closes the folder windows (QTTabBar keeps their tabs for the next window) and ends every
        Explorer process, removes every QTTabBar installation (MSI products and Setup.exe
        bundles), installs -Msi (default: the newest build of this repository), checks that the
        DLL in the GAC is that build's, and starts a fresh Explorer. QTTabBar's settings (HKCU)
        are kept.
        Use -WhatIf to see the plan only.

    Installing over a running Explorer can leave the previous QTTabBar.dll in the GAC: Explorer
    keeps it open, the new package finds an assembly of the same version already there and
    skips it, and Windows reports success. Status detects that; Repair fixes it.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\QTTabBarDoctor.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\QTTabBarDoctor.ps1 -Action Watch -Seconds 60
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\QTTabBarDoctor.ps1 -Action Repair
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Status', 'Watch', 'Repair', 'RepairInstall')]
    [string]$Action = 'Status',
    # Repair: the MSI to install. Default: the newest "QTTabBar Setup *.msi" built in this repository.
    [string]$Msi,
    # Watch: how long to watch.
    [int]$Seconds = 30,
    # Status: where the report is saved. Default: Desktop\QTTabBarDoctor-<time>.txt
    [string]$ReportPath,
    # RepairInstall (internal, run elevated by Repair): where its result goes.
    [string]$ResultPath
)

$ErrorActionPreference = 'Stop'

$UpgradeCode = '{ec9baff7-58fb-40cb-9f67-1c438a7524a5}'   # Installer.wxs
$GacDir      = Join-Path $env:SystemRoot 'Microsoft.NET\assembly\GAC_MSIL\QTTabBar'
$RepoRoot    = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$BuildDll    = Join-Path $RepoRoot 'QTTabBar\bin\Release\QTTabBar.dll'
$BuildMsiDir = Join-Path $RepoRoot 'Installer\bin\Release\en-US'

# Explorer's native tabs (ViVeTool's well-known trio) and the classic-toolbar bundles
# (Tools\Win11ToolbarFix).
$TabFeatures     = 37634385, 39145991, 36354489
$ToolbarFeatures = 57048237, 57048216, 58988972

# BindAction ordinals of the mouse-only actions (Config.cs; persisted, never renumbered).
$MouseActionNames = @('Nothing', 'UpOneLevel', 'Refresh', 'Paste', 'Maximize', 'Minimize',
    'ItemOpenInNewTab', 'ItemOpenInNewTabNoSel', 'ItemOpenInNewWindow', 'ItemCut', 'ItemCopy',
    'ItemDelete', 'ItemProperties', 'CopyItemPath', 'CopyItemName', 'ChecksumItem', 'CloseTab',
    'CloseLeftTab', 'CloseRightTab', 'UpOneLevelTab', 'LockTab', 'ShowTabMenu', 'TearOffTab',
    'CloneTab', 'CopyTabPath', 'TabProperties', 'ShowTabSubfolderMenu', 'CloseAllButThis',
    'OpenCmd', 'ItemsOpenInNewTabNoSel', 'SortTab', 'TurnOffRepeat', 'SelectAll')

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class QTDoctor
{
    [StructLayout(LayoutKind.Sequential)]
    public struct FEATURE { public uint FeatureId; public uint CompactState; public uint VariantPayload; }

    [DllImport("ntdll.dll")]
    static extern int RtlQueryFeatureConfiguration(uint featureId, int featureType, ref ulong changeStamp, out FEATURE config);
    [DllImport("ntdll.dll")]
    static extern int RtlQueryAllFeatureConfigurations(int featureType, out ulong changeStamp, [Out] FEATURE[] configs, ref int count);

    // -1: no configuration, else (priority << 8) | enabledState. Run-time store.
    public static int Query(uint id)
    {
        ulong stamp = 0; FEATURE f;
        if (RtlQueryFeatureConfiguration(id, 1, ref stamp, out f) != 0) return -1;
        return (int)(((f.CompactState & 0xF) << 8) | ((f.CompactState >> 4) & 0x3));
    }

    public static FEATURE[] All()
    {
        ulong stamp; int n = 0;
        RtlQueryAllFeatureConfigurations(1, out stamp, null, ref n);
        FEATURE[] a = new FEATURE[n];
        if (RtlQueryAllFeatureConfigurations(1, out stamp, a, ref n) != 0) return new FEATURE[0];
        return a;
    }

    public delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string name);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);

    // SMTO_ABORTIFHUNG: a hung window does not hold the caller up.
    public static bool Send(IntPtr h, uint msg, IntPtr w, IntPtr l, uint timeoutMs)
    {
        IntPtr result;
        return SendMessageTimeout(h, msg, w, l, 2, timeoutMs, out result) != IntPtr.Zero;
    }

    public static string ClassOf(IntPtr h) { StringBuilder s = new StringBuilder(256); GetClassName(h, s, 256); return s.ToString(); }
    public static string TextOf(IntPtr h) { StringBuilder s = new StringBuilder(256); GetWindowText(h, s, 256); return s.ToString(); }

    public static IntPtr[] TopWindows(string cls)
    {
        List<IntPtr> l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { if (ClassOf(h) == cls) l.Add(h); return true; }, IntPtr.Zero);
        return l.ToArray();
    }

    public static IntPtr[] Children(IntPtr parent, string cls)
    {
        List<IntPtr> l = new List<IntPtr>();
        EnumChildWindows(parent, delegate(IntPtr h, IntPtr p) { if (string.IsNullOrEmpty(cls) || ClassOf(h) == cls) l.Add(h); return true; }, IntPtr.Zero);
        return l.ToArray();
    }
}
'@

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Format-Feature([int]$q) {
    if ($q -lt 0) { return 'no configuration' }
    $prio = $q -shr 8; $state = $q -band 0xFF
    $prioName = switch ($prio) { 15 { 'ImageOverride' } 10 { 'Policy' } 9 { 'Security' } 8 { 'User/ViVeTool' } 4 { 'Service' } 1 { 'EKB' } 0 { 'ImageDefault' } default { "$prio" } }
    $stateName = switch ($state) { 0 { 'Default' } 1 { 'Disabled' } 2 { 'Enabled' } default { "$state" } }
    return "$stateName (priority $prio $prioName)"
}

function Get-FileSha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

function Get-NewestMsi {
    if (-not (Test-Path $BuildMsiDir)) { return $null }
    Get-ChildItem -LiteralPath $BuildMsiDir -Filter 'QTTabBar Setup *.msi' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# -Msi, or the newest MSI built in this repository.
function Resolve-Msi {
    $path = $Msi
    if (-not $path) { $m = Get-NewestMsi; if ($m) { $path = $m.FullName } }
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { throw 'No MSI found. Build one (Installer\Build-Installer.ps1) or pass -Msi.' }
    return (Resolve-Path -LiteralPath $path).Path
}

# Windows Installer products with QTTabBar's UpgradeCode.
function Get-QTProducts {
    $installer = New-Object -ComObject WindowsInstaller.Installer
    foreach ($code in @($installer.RelatedProducts($UpgradeCode))) {
        $info = { param($p) try { $installer.ProductInfo($code, $p) } catch { '' } }
        [pscustomobject]@{
            ProductCode = $code
            Name        = & $info 'ProductName'
            Version     = & $info 'VersionString'
            InstallDate = & $info 'InstallDate'
            Source      = & $info 'InstallSource'
        }
    }
}

# Setup.exe (WiX Burn) bundles registered in Apps & Features.
function Get-QTBundles {
    $roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($k in Get-ChildItem $root) {
            $p = Get-ItemProperty $k.PSPath
            if ($p.DisplayName -like 'QTTabBar*' -and $p.BundleCachePath) {
                [pscustomobject]@{
                    Key          = $k.PSPath
                    Name         = $p.DisplayName
                    Version      = $p.DisplayVersion
                    CachePath    = $p.BundleCachePath
                    CacheExists  = (Test-Path -LiteralPath $p.BundleCachePath)
                }
            }
        }
    }
}

function Get-GacDll {
    if (-not (Test-Path $GacDir)) { return $null }
    Get-ChildItem -LiteralPath $GacDir -Recurse -Filter QTTabBar.dll -File | Select-Object -First 1
}

function Get-ExplorerProcesses {
    $session = (Get-Process -Id $PID).SessionId
    Get-Process explorer -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $session }
}

function Test-ClrLoaded($Process) {
    try { return [bool]($Process.Modules | Where-Object { $_.ModuleName -eq 'clr.dll' }) } catch { return $false }
}

# Explorer processes that loaded .NET (so QTTabBar) and started before the DLL in the GAC last
# changed: they still run the previous build. One that has not loaded it yet gets the new one.
function Get-StaleExplorers {
    $gac = Get-GacDll
    if (-not $gac) { return @() }
    @(Get-ExplorerProcesses | Where-Object { $_.StartTime -lt $gac.LastWriteTime -and (Test-ClrLoaded $_) })
}

# ---------------------------------------------------------------- Status

function Show-Status {
    $out = New-Object System.Collections.Generic.List[string]
    $warn = New-Object System.Collections.Generic.List[string]
    function Say([string]$s) { $out.Add($s); Write-Host $s }

    Say ("QTTabBar Doctor - {0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date))
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    Say ("Windows {0} build {1}.{2}, last boot {3}" -f $cv.DisplayVersion, $cv.CurrentBuild, $cv.UBR, (Get-CimInstance Win32_OperatingSystem).LastBootUpTime)
    foreach ($m in "$env:SystemRoot\explorer.exe", "$env:SystemRoot\System32\ExplorerFrame.dll") {
        Say ("  {0} {1}" -f (Split-Path $m -Leaf), (Get-Item $m).VersionInfo.ProductVersion)
    }

    Say ''
    Say '== QTTabBar installation'
    $products = @(Get-QTProducts)
    if ($products.Count -eq 0) { Say '  Windows Installer: no QTTabBar product installed'; $warn.Add('QTTabBar is not installed.') }
    foreach ($p in $products) { Say ("  product {0}  {1} {2}, installed {3} from {4}" -f $p.ProductCode, $p.Name, $p.Version, $p.InstallDate, $p.Source) }
    if ($products.Count -gt 1) { $warn.Add("$($products.Count) QTTabBar products are installed side by side; run -Action Repair.") }
    foreach ($b in @(Get-QTBundles)) {
        Say ("  Setup.exe bundle: {0} {1} (cache {2})" -f $b.Name, $b.Version, $(if ($b.CacheExists) { 'present' } else { 'missing' }))
    }
    if (@(Get-QTBundles).Count -gt 0 -and $products.Count -gt 0) {
        Say '    (a Setup.exe registration next to a directly installed MSI is left over from an earlier install)'
    }

    $gac = Get-GacDll
    $gacHash = $null
    if ($gac) {
        $gacHash = Get-FileSha $gac.FullName
        Say ("  GAC  QTTabBar.dll  {0:yyyy-MM-dd HH:mm:ss}  {1} bytes  SHA256 {2}" -f $gac.LastWriteTime, $gac.Length, $gacHash.Substring(0, 16))
    } else {
        Say '  GAC  QTTabBar.dll  missing'
    }
    $msiFile = Get-NewestMsi
    if (Test-Path $BuildDll) {
        $buildHash = Get-FileSha $BuildDll
        $b = Get-Item $BuildDll
        Say ("  this repo's build {0:yyyy-MM-dd HH:mm:ss}  {1} bytes  SHA256 {2}" -f $b.LastWriteTime, $b.Length, $buildHash.Substring(0, 16))
        if ($msiFile) { Say ("  this repo's MSI   {0:yyyy-MM-dd HH:mm:ss}  {1}" -f $msiFile.LastWriteTime, $msiFile.Name) }
        if ($gac -and $gacHash -eq $buildHash) {
            Say '  -> the GAC holds this repository''s latest build.'
        } elseif ($gac) {
            Say '  -> the GAC does NOT hold this repository''s latest build.'
            $fromRepo = @($products | Where-Object { $_.Source -and $BuildMsiDir.StartsWith($_.Source.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) })
            if ($fromRepo.Count -gt 0 -and $msiFile -and $gac.LastWriteTime -lt $msiFile.LastWriteTime) {
                $warn.Add('The MSI from this repository is installed, but the GAC still has an older QTTabBar.dll (it was in use during the install). Run -Action Repair.')
            } else {
                $warn.Add('The installed QTTabBar.dll is not this repository''s latest build. Install the new MSI with -Action Repair.')
            }
        }
    }

    Say ''
    Say '== Explorer'
    foreach ($p in @(Get-ExplorerProcesses)) {
        $clr = Test-ClrLoaded $p
        Say ("  explorer pid {0} started {1:yyyy-MM-dd HH:mm:ss}{2}" -f $p.Id, $p.StartTime, $(if ($clr) { ', .NET loaded (QTTabBar)' } else { '' }))
        if ($gac -and $clr -and $p.StartTime -lt $gac.LastWriteTime) { $warn.Add("Explorer pid $($p.Id) loaded QTTabBar before QTTabBar.dll was replaced; restart Explorer.") }
    }
    $frames = @([QTDoctor]::TopWindows('CabinetWClass'))
    if ($frames.Count -eq 0) { Say '  no folder window open (open one and run Status again to check it)' }
    foreach ($f in $frames) {
        $tabs = @([QTDoctor]::Children($f, 'ShellTabWindowClass'))
        $tree = @([QTDoctor]::Children($f, 'SysTreeView32'))
        $xaml = @([QTDoctor]::Children($f, $null) | Where-Object { [QTDoctor]::ClassOf($_) -match 'DesktopChildSiteBridge|DesktopWindowContentBridge|XamlExplorerHost' })
        $pidF = [uint32]0; [void][QTDoctor]::GetWindowThreadProcessId($f, [ref]$pidF)
        Say ("  window '{0}' (pid {1}): {2} native tab(s), navigation pane {3}, {4} XAML island(s)" -f [QTDoctor]::TextOf($f), $pidF, $tabs.Count, $(if ($tree.Count) { 'SysTreeView32' } else { 'not found' }), $xaml.Count)
        if ($tabs.Count -gt 1) { $warn.Add("Window '$([QTDoctor]::TextOf($f))' has $($tabs.Count) native tabs: Windows opened tabs of its own next to QTTabBar's (the middle click reached Explorer).") }
    }

    Say ''
    Say '== Last QTTabBar installs (Windows Installer / Restart Manager, 7 days)'
    $since = (Get-Date).AddDays(-7)
    $msiEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'MsiInstaller'; Id = 1040, 1042; StartTime = $since } -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -match 'QTTabBar' } | Sort-Object TimeCreated)
    $rmEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Microsoft-Windows-RestartManager'; Id = 10005, 10010; StartTime = $since } -ErrorAction SilentlyContinue)
    $begins = @($msiEvents | Where-Object { $_.Id -eq 1040 })
    if ($begins.Count -eq 0) { Say '  none' }
    foreach ($e in $begins | Select-Object -Last 5) {
        $end = $msiEvents | Where-Object { $_.Id -eq 1042 -and $_.TimeCreated -ge $e.TimeCreated } | Select-Object -First 1
        $until = if ($end) { $end.TimeCreated.AddSeconds(2) } else { $e.TimeCreated.AddMinutes(5) }
        $inUse = @($rmEvents | Where-Object { $_.TimeCreated -ge $e.TimeCreated -and $_.TimeCreated -le $until })
        $file = if ($e.Message -match 'transaction: (.+?)\. Client') { $Matches[1] } else { '' }
        Say ("  {0:yyyy-MM-dd HH:mm:ss}  {1}" -f $e.TimeCreated, $file)
        if ($inUse.Count -gt 0) {
            Say '    Restart Manager: files were in use (Explorer could not be restarted; "machine restart is required")'
            if ($e -eq $begins[-1]) { $warn.Add('The last install ran while Explorer was using QTTabBar.dll, so the old DLL may have stayed in place.') }
        }
    }

    Say ''
    Say '== Windows feature flags'
    $tabStates = foreach ($id in $TabFeatures) { $q = [QTDoctor]::Query([uint32]$id); Say ("  native tabs   {0}: {1}" -f $id, (Format-Feature $q)); $q }
    $off = @($tabStates | Where-Object { $_ -ge 0 -and ($_ -band 0xFF) -eq 1 }).Count
    if ($off -eq $TabFeatures.Count) {
        Say '    -> native tabs disabled: a folder middle-clicked in the navigation pane opens a NEW WINDOW (QTTabBar captures it as a tab).'
    } elseif ($off -gt 0) {
        Say '    -> native tabs partly disabled: Explorer may open a middle-clicked folder in a native tab or in a new window.'
    } else {
        Say '    -> native tabs enabled: a folder middle-clicked in the navigation pane opens in a hidden native tab.'
    }
    Say '    QTTabBar (build of 2026-10-20 or later) keeps middle clicks in the navigation pane from Explorer in all cases.'
    foreach ($id in $ToolbarFeatures) { Say ("  toolbar       {0}: {1}" -f $id, (Format-Feature ([QTDoctor]::Query([uint32]$id)))) }
    $user = @([QTDoctor]::All() | Where-Object { ($_.CompactState -band 0xF) -eq 8 } | Sort-Object FeatureId)
    Say ("  User-priority (ViVeTool) overrides: {0}" -f $user.Count)
    foreach ($f in $user) { Say ("    {0}: {1}" -f $f.FeatureId, $(if ((($f.CompactState -shr 4) -band 3) -eq 2) { 'Enabled' } else { 'Disabled' })) }

    Say ''
    Say '== QTTabBar settings'
    $cfg = 'HKCU:\Software\QTTabBar\Config'
    $w = Get-ItemProperty "$cfg\Window" -ErrorAction SilentlyContinue
    $mi = Get-ItemProperty "$cfg\Misc" -ErrorAction SilentlyContinue
    $mo = Get-ItemProperty "$cfg\Mouse" -ErrorAction SilentlyContinue
    $adv = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -ErrorAction SilentlyContinue
    Say ("  capture new windows as tabs: {0}; log: {1}; folder windows in a separate process: {2}" -f $w.CaptureNewWindows, $mi.EnableLog, $adv.SeparateProcess)
    if ($mo -and $mo.ItemActions) {
        foreach ($pair in ($mo.ItemActions | ConvertFrom-Json)) {
            $key = [int]$pair.Key
            if (($key -band 32) -eq 0) { continue }   # middle-button chords only
            $mods = @(); if ($key -band 2) { $mods += 'Ctrl' }; if ($key -band 1) { $mods += 'Shift' }; if ($key -band 4) { $mods += 'Alt' }
            $v = [int]$pair.Value
            $name = if ($v -ge 1000 -and $v - 1000 -lt $MouseActionNames.Count) { $MouseActionNames[$v - 1000] } else { "action $v" }
            Say ("  middle click on an item {0}: {1}" -f $(if ($mods) { '+' + ($mods -join '+') } else { '' }), $name)
        }
    }

    $exc = Join-Path $env:APPDATA 'QTTabBar\QTTabBarException.log'
    if (Test-Path $exc) {
        $recent = (Get-Item $exc).LastWriteTime
        $infos = @(Get-Content $exc -Tail 4000 | Where-Object { $_ -like 'Additional Info:*' } | Group-Object | Sort-Object Count -Descending | Select-Object -First 5)
        Say ("  exception log: last written {0:yyyy-MM-dd HH:mm:ss}" -f $recent)
        foreach ($g in $infos) { Say ("    {0,4} x {1}" -f $g.Count, $g.Name.Substring(17)) }
    }

    Say ''
    if ($warn.Count -eq 0) { Say 'Result: nothing wrong found.' }
    else { Say 'Result:'; foreach ($x in ($warn | Select-Object -Unique)) { Say "  ! $x" } }

    if (-not $ReportPath) { $ReportPath = Join-Path ([Environment]::GetFolderPath('Desktop')) ("QTTabBarDoctor-{0:yyyyMMdd-HHmmss}.txt" -f (Get-Date)) }
    $out | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    Write-Host ''
    Write-Host "Saved: $ReportPath"
}

# ---------------------------------------------------------------- Watch

function Get-WindowState {
    $state = @{}
    foreach ($f in [QTDoctor]::TopWindows('CabinetWClass')) {
        $tabs = @([QTDoctor]::Children($f, 'ShellTabWindowClass'))
        $vis = @($tabs | Where-Object { [QTDoctor]::IsWindowVisible($_) }).Count
        $state["$f"] = '{0} | visible={1} | native tabs={2} ({3} shown)' -f [QTDoctor]::TextOf($f), [QTDoctor]::IsWindowVisible($f), $tabs.Count, $vis
    }
    return $state
}

function Invoke-Watch {
    Write-Host "Watching Explorer windows for $Seconds s. Middle-click a folder in the navigation pane now."
    Write-Host '(read-only; Ctrl+C stops)'
    $prev = Get-WindowState
    foreach ($k in $prev.Keys) { Write-Host ("  {0:HH:mm:ss.fff}  window {1}: {2}" -f (Get-Date), $k, $prev[$k]) }
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        Start-Sleep -Milliseconds 100
        $now = Get-WindowState
        foreach ($k in $now.Keys) {
            if (-not $prev.ContainsKey($k)) { Write-Host ("  {0:HH:mm:ss.fff}  NEW window {1}: {2}" -f (Get-Date), $k, $now[$k]) }
            elseif ($prev[$k] -ne $now[$k]) { Write-Host ("  {0:HH:mm:ss.fff}  window {1}: {2}" -f (Get-Date), $k, $now[$k]) }
        }
        foreach ($k in $prev.Keys) { if (-not $now.ContainsKey($k)) { Write-Host ("  {0:HH:mm:ss.fff}  window {1} CLOSED" -f (Get-Date), $k) } }
        $prev = $now
    }
    Write-Host 'Done. "native tabs=2" after a middle click: Windows opened a native tab (old QTTabBar build, or the click got past it).'
    Write-Host '"NEW window" that closes again at once: Windows opened a window and QTTabBar captured it.'
}

# ---------------------------------------------------------------- Repair

function Stop-Explorer {
    $since = Get-Date
    # Folder windows first, the way QTTabBar's "Close window" does it (WM_CLOSE with lParam 1):
    # every tab closes and the session is saved for the next window. A plain WM_CLOSE may close
    # only the current tab ("the close button closes the current tab"). Sent, not posted: a
    # posted WM_CLOSE closes the window without passing QTTabBar (no session saved).
    foreach ($f in [QTDoctor]::TopWindows('CabinetWClass')) { [void][QTDoctor]::Send($f, 0x10, [IntPtr]::Zero, [IntPtr]1, 5000) }
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline -and @([QTDoctor]::TopWindows('CabinetWClass')).Count -gt 0) { Start-Sleep -Milliseconds 200 }
    # Then every Explorer process at once (waiting for the shell to exit on request did not always
    # work). Windows starts the shell again by itself (AutoRestartShell); without folder windows it
    # does not load QTTabBar, and it is replaced at the end.
    foreach ($p in @(Get-ExplorerProcesses)) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
    return @(Get-ExplorerProcesses | Where-Object { $_.StartTime -lt $since }).Count -eq 0
}

function Start-Explorer {
    # After a forced close Windows may be starting it already.
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline -and [QTDoctor]::FindWindow('Shell_TrayWnd', [NullString]::Value) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 300 }
    if ([QTDoctor]::FindWindow('Shell_TrayWnd', [NullString]::Value) -ne [IntPtr]::Zero) { return }
    Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe')
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline -and [QTDoctor]::FindWindow('Shell_TrayWnd', [NullString]::Value) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 300 }
}

function Invoke-Repair {
    if (Test-Admin) {
        throw 'Run -Action Repair from a normal (not elevated) PowerShell: it restarts Explorer as you and asks for admin rights only for the install step.'
    }
    $Msi = Resolve-Msi

    Write-Host 'Plan:'
    Write-Host '  1. close the folder windows (QTTabBar keeps their tabs for next time), end Explorer'
    foreach ($b in @(Get-QTBundles)) { Write-Host "  2. uninstall Setup.exe bundle '$($b.Name)'" }
    foreach ($p in @(Get-QTProducts)) { Write-Host "  2. uninstall $($p.ProductCode) $($p.Name)" }
    Write-Host "  3. install $Msi"
    Write-Host '  4. check the QTTabBar.dll in the GAC, start Explorer afresh'
    Write-Host '  QTTabBar settings (HKCU\Software\QTTabBar) are kept.'
    if (-not $PSCmdlet.ShouldProcess($Msi, 'Reinstall QTTabBar')) { return }

    $result = Join-Path $env:TEMP ("QTTabBarDoctor-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date))
    $stopped = Stop-Explorer
    if (-not $stopped) { Write-Warning 'Explorer did not close completely; the DLL may stay in use.' }
    try {
        $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Action RepairInstall -Msi "{1}" -ResultPath "{2}"' -f $PSCommandPath, $Msi, $result
        $p = Start-Process -FilePath $psExe -ArgumentList $arguments -Verb RunAs -Wait -PassThru
        Write-Host "Install step finished (exit $($p.ExitCode))."
    } catch {
        Write-Warning "The install step did not run: $($_.Exception.Message)"
    } finally {
        # The shell Windows restarted by itself ran during the install: start a fresh one.
        [void](Stop-Explorer)
        Start-Explorer
    }
    if (Test-Path $result) {
        $r = Get-Content $result -Raw | ConvertFrom-Json
        foreach ($line in $r.Log) { Write-Host "  $line" }
        if ($r.Ok) { Write-Host 'Repaired: QTTabBar.dll in the GAC is the build that was installed.' }
        else { Write-Warning 'Not repaired - see the lines above. Restarting Windows and running -Action Repair again usually helps.' }
    }
}

function Invoke-RepairInstall {
    if (-not (Test-Admin)) { throw 'RepairInstall must run elevated (use -Action Repair).' }
    $log = New-Object System.Collections.Generic.List[string]
    $ok = $false
    try {
        $Msi = Resolve-Msi
        $logDir = Join-Path $env:TEMP 'QTTabBarDoctor'
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        $stamp = '{0:yyyyMMdd-HHmmss}' -f (Get-Date)

        foreach ($b in @(Get-QTBundles)) {
            if ($b.CacheExists) {
                $p = Start-Process -FilePath $b.CachePath -ArgumentList '/uninstall /quiet /norestart' -Wait -PassThru
                $log.Add("bundle '$($b.Name)' uninstall: exit $($p.ExitCode)")
            } else {
                $log.Add("bundle '$($b.Name)': its cached Setup.exe is missing, entry left in place")
            }
        }
        foreach ($pr in @(Get-QTProducts)) {
            $l = Join-Path $logDir "uninstall-$stamp-$($pr.ProductCode.Trim('{}')).log"
            $p = Start-Process msiexec.exe -ArgumentList "/x $($pr.ProductCode) /qn /norestart MSIRESTARTMANAGERCONTROL=Disable /l*v `"$l`"" -Wait -PassThru
            $log.Add("uninstall $($pr.ProductCode): exit $($p.ExitCode) (log $l)")
        }
        $left = Get-GacDll
        if ($left) {
            # Nothing references it any more once every product is gone.
            Add-Type -AssemblyName System.EnterpriseServices
            try { (New-Object System.EnterpriseServices.Internal.Publish).GacRemove($left.FullName) } catch { }
            $log.Add($(if (Get-GacDll) { 'old QTTabBar.dll is still in the GAC (in use?)' } else { 'removed the leftover QTTabBar.dll from the GAC' }))
        }

        $l = Join-Path $logDir "install-$stamp.log"
        $p = Start-Process msiexec.exe -ArgumentList "/i `"$Msi`" /qn /norestart MSIRESTARTMANAGERCONTROL=Disable /l*v `"$l`"" -Wait -PassThru
        $log.Add("install $(Split-Path $Msi -Leaf): exit $($p.ExitCode) (log $l)")

        $gac = Get-GacDll
        if (-not $gac) {
            $log.Add('QTTabBar.dll is not in the GAC after the install')
        } else {
            $log.Add(("GAC QTTabBar.dll now {0:yyyy-MM-dd HH:mm:ss}, {1} bytes" -f $gac.LastWriteTime, $gac.Length))
            $buildMsi = Get-NewestMsi
            if ((Test-Path $BuildDll) -and $buildMsi -and $Msi -eq $buildMsi.FullName) {
                $same = (Get-FileSha $gac.FullName) -eq (Get-FileSha $BuildDll)
                $log.Add($(if ($same) { 'matches this repository''s build' } else { 'does NOT match this repository''s build' }))
                $ok = $same -and ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010)
            } else {
                $ok = ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010)
            }
        }
    } catch {
        $log.Add("ERROR: $($_.Exception.Message)")
    }
    if ($ResultPath) { [pscustomobject]@{ Ok = $ok; Log = $log.ToArray() } | ConvertTo-Json | Set-Content -LiteralPath $ResultPath -Encoding UTF8 }
    foreach ($line in $log) { Write-Host $line }
    if (-not $ok) { exit 1 }
}

# Dot-sourcing (. .\QTTabBarDoctor.ps1) only loads the functions.
if ($MyInvocation.InvocationName -ne '.') {
    switch ($Action) {
        'Status'        { Show-Status }
        'Watch'         { Invoke-Watch }
        'Repair'        { Invoke-Repair }
        'RepairInstall' { Invoke-RepairInstall }
    }
}
