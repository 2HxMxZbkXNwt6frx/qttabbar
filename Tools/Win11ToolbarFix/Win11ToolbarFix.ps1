<#
.SYNOPSIS
    Brings back the classic Explorer toolbar that QTTabBar docks into on Windows 11 24H2 / 25H2 / 26H2.

.DESCRIPTION
    Starting with the late-2025 cumulative updates, Windows 11 ships feature overrides that remove
    Explorer's classic toolbar (the rebar band site). Without it QTTabBar loads but has nowhere to
    show its tab bar / button bar, so it looks like it "doesn't work at all".

    Those overrides are stored at ImageOverride priority (15). `ViVeTool /disable` writes User
    priority (8), which loses to 15 - that is why the ViVeTool workaround stopped working.

    -Action Apply
        1. Backs up the priority-15 overrides listed in $Features (and any priority-8 ones).
        2. Deletes the priority-15 overrides. The keys are owned by TrustedInstaller and read-only for
           Administrators; they are opened with SeRestorePrivilege (backup/restore semantics) instead
           of taking ownership, so no ACL is changed.
        3. Writes User-priority (8) "disabled" overrides, the same entries ViVeTool /disable writes.
        Restart Windows afterwards: the overrides are read at boot.

    -Action Restore     Puts back exactly what Apply backed up, and removes the scheduled task.
    -Action Status      Shows the running state (what Explorer sees now) and the registry state
                        (what the next boot will use). Does not need admin.
    -Action InstallTask Copies this script to Program Files and registers a SYSTEM task that runs
                        Apply at every startup, because a cumulative update can put the overrides back.
    -Action RemoveTask  Removes that task.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Win11ToolbarFix.ps1 -Action Status
.EXAMPLE
    # elevated
    powershell -ExecutionPolicy Bypass -File .\Win11ToolbarFix.ps1 -Action Apply
#>
[CmdletBinding()]
param(
    [ValidateSet('Status', 'Apply', 'Restore', 'InstallTask', 'RemoveTask')]
    [string]$Action = 'Status',
    # Which feature bundles to disable (see $AllFeatures). Status and Restore ignore it.
    [ValidateSet('Minimal', 'Pair', 'Full', 'Extended')]
    [string]$Mode = 'Minimal',
    # Used by the startup task: log only, no console output.
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Feature ids (what ViVeTool takes). They are monthly Explorer feature bundles that are Enabled at
# ImageOverride priority on 24H2/25H2/26H2; reports differ on which of them remove the classic
# toolbar, hence the modes. Wenbang's fix tool disables only 57048237 by default; disabling
# 57048216 has been reported to also hide the Widgets button.
$AllFeatures = @(
    [pscustomobject]@{ Id = 57048237; Modes = 'Minimal', 'Pair', 'Full', 'Extended' }   # Dec 2025 bundle
    [pscustomobject]@{ Id = 57048216; Modes = 'Pair', 'Full', 'Extended' }              # Aug 2025 bundle
    [pscustomobject]@{ Id = 58988972; Modes = 'Full', 'Extended' }                      # Feb 2026 bundle
    # Siblings of 57048216..57048237 that ExplorerFrame.dll (the rebar host) checks.
    [pscustomobject]@{ Id = 57048218; Modes = , 'Extended' }
    [pscustomobject]@{ Id = 57048226; Modes = , 'Extended' }
    [pscustomobject]@{ Id = 57048231; Modes = , 'Extended' }
)

$OverridesPath = 'SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides'
$PolicyOverridesPath = 'SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides'
$PriorityImageOverride = 15
$PriorityUser = 8
$StateDisabled = 1

# Everything this script keeps lives under Program Files, which only Administrators can write: the
# SYSTEM startup task and an elevated Restore read the backup, so it must not be user-writable
# (ProgramData subfolders are).
$DataDir    = Join-Path $env:ProgramFiles 'QTTabBar\Win11ToolbarFix'
$BackupFile = Join-Path $DataDir 'backup.json'
$LogFile    = Join-Path $DataDir 'Win11ToolbarFix.log'
$TaskName   = 'QTTabBar Win11 Toolbar Fix'
$TaskScript = Join-Path $DataDir 'Win11ToolbarFix.ps1'

function Write-Log([string]$Message) {
    if (-not $Quiet) { Write-Host $Message }
    try {
        if (-not (Test-Admin)) { return }
        Initialize-DataDir
        Add-Content -Path $LogFile -Value ("{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $Message)
    } catch { }
}

function Initialize-DataDir {
    if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
    foreach ($p in $DataDir, $BackupFile) {
        if ((Test-Path $p) -and ((Get-Item $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "$p is a reparse point; refusing to use it."
        }
    }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin {
    if (-not (Test-Admin)) { throw "Run this from an elevated (Administrator) PowerShell to use -Action $Action." }
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class QTFeatureNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RTL_FEATURE_CONFIGURATION
    {
        public uint FeatureId;
        public uint CompactState;   // Priority:4, EnabledState:2, IsWexpConfiguration:1, HasSubscriptions:1, Variant:6, VariantPayloadKind:2
        public uint VariantPayload;
    }

    [DllImport("ntdll.dll")]
    static extern int RtlQueryFeatureConfiguration(uint featureId, int featureType, ref ulong changeStamp, out RTL_FEATURE_CONFIGURATION config);

    [DllImport("ntdll.dll")]
    static extern int NtDeleteKey(IntPtr keyHandle);

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegCreateKeyExW(IntPtr hKey, string subKey, int reserved, string cls, int options, int samDesired,
                                      IntPtr securityAttributes, out IntPtr result, out int disposition);

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegSetValueExW(IntPtr hKey, string valueName, int reserved, int type, ref int data, int cbData);

    [DllImport("advapi32.dll")]
    static extern int RegCloseKey(IntPtr hKey);

    [DllImport("advapi32.dll", SetLastError = true)]
    static extern bool OpenProcessToken(IntPtr process, int access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool LookupPrivilegeValueW(string system, string name, out long luid);

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    struct TOKEN_PRIVILEGES { public int Count; public long Luid; public int Attributes; }

    [DllImport("advapi32.dll", SetLastError = true)]
    static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TOKEN_PRIVILEGES newState, int len, IntPtr prev, IntPtr retLen);

    [DllImport("kernel32.dll")]
    static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr handle);

    static readonly IntPtr HKEY_LOCAL_MACHINE = new IntPtr(unchecked((int)0x80000002));
    const int REG_OPTION_BACKUP_RESTORE = 4;
    const int REG_DWORD = 4;
    const int TOKEN_ADJUST_PRIVILEGES = 0x20, TOKEN_QUERY = 0x8, SE_PRIVILEGE_ENABLED = 2, ERROR_NOT_ALL_ASSIGNED = 1300;

    // Name of a feature's key under FeatureManagement\Overrides\<priority> (same obfuscation as ViVeTool).
    public static uint ObfuscateId(uint id)
    {
        uint x = id ^ 0x74161A4E;
        x = (x >> 24) | ((x >> 8) & 0xFF00) | ((x << 8) & 0xFF0000) | (x << 24);
        x ^= 0x8FB23D4F;
        x = (x << 1) | (x >> 31);
        return x ^ 0x833EA8FF;
    }

    // Returns -1 when the feature has no configuration, otherwise (priority << 8) | enabledState.
    // featureType: 0 = boot store, 1 = runtime store.
    public static int Query(uint featureId, int featureType)
    {
        ulong stamp = 0;
        RTL_FEATURE_CONFIGURATION cfg;
        int status = RtlQueryFeatureConfiguration(featureId, featureType, ref stamp, out cfg);
        if (status != 0) return -1;
        return (int)(((cfg.CompactState & 0xF) << 8) | ((cfg.CompactState >> 4) & 0x3));
    }

    public static void EnablePrivilege(string name)
    {
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out token))
            throw new System.ComponentModel.Win32Exception();
        try {
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.Count = 1;
            tp.Attributes = SE_PRIVILEGE_ENABLED;
            if (!LookupPrivilegeValueW(null, name, out tp.Luid)) throw new System.ComponentModel.Win32Exception();
            if (!AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero)) throw new System.ComponentModel.Win32Exception();
            if (Marshal.GetLastWin32Error() == ERROR_NOT_ALL_ASSIGNED) throw new InvalidOperationException(name + " is not held by this account.");
        } finally {
            CloseHandle(token);
        }
    }

    // Opens (or creates) an HKLM key with backup/restore semantics: with SeRestorePrivilege enabled
    // the handle gets DELETE | KEY_WRITE regardless of the key's DACL.
    static IntPtr OpenForRestore(string path)
    {
        IntPtr h; int disposition;
        int err = RegCreateKeyExW(HKEY_LOCAL_MACHINE, path, 0, null, REG_OPTION_BACKUP_RESTORE, 0, IntPtr.Zero, out h, out disposition);
        if (err != 0) throw new System.ComponentModel.Win32Exception(err, "RegCreateKeyEx(" + path + ")");
        return h;
    }

    public static void DeleteKey(string path)
    {
        IntPtr h = OpenForRestore(path);
        try {
            int status = NtDeleteKey(h);
            if (status != 0) throw new InvalidOperationException(string.Format("NtDeleteKey({0}) failed: 0x{1:X8}", path, status));
        } finally {
            RegCloseKey(h);
        }
    }

    public static void WriteDwords(string path, string[] names, int[] values)
    {
        IntPtr h = OpenForRestore(path);
        try {
            for (int i = 0; i < names.Length; i++) {
                int v = values[i];
                int err = RegSetValueExW(h, names[i], 0, REG_DWORD, ref v, 4);
                if (err != 0) throw new System.ComponentModel.Win32Exception(err, "RegSetValueEx(" + path + "\\" + names[i] + ")");
            }
        } finally {
            RegCloseKey(h);
        }
    }
}
'@

if ([QTFeatureNative]::ObfuscateId(57048216) -ne 815149711) { throw 'Feature id obfuscation self-check failed.' }
foreach ($f in $AllFeatures) { $f | Add-Member -NotePropertyName Key -NotePropertyValue ([string][QTFeatureNative]::ObfuscateId([uint32]$f.Id)) }
$Features = @($AllFeatures | Where-Object { $_.Modes -contains $Mode })

function Get-OverrideKeyPath([int]$Priority, [string]$Key) { "$OverridesPath\$Priority\$Key" }

# Priority folders (0..15) that hold an override for this key.
function Get-OverridePriorities([string]$Key) {
    $root = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($OverridesPath)
    if ($null -eq $root) { return @() }
    try {
        return @($root.GetSubKeyNames() | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Sort-Object |
            Where-Object { $null -ne (Read-Override $_ $Key) })
    } finally { $root.Close() }
}

# Reads an override key as an ordered name -> DWORD map, or $null if it doesn't exist.
function Read-Override([int]$Priority, [string]$Key) {
    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey((Get-OverrideKeyPath $Priority $Key))
    if ($null -eq $k) { return $null }
    try {
        $values = [ordered]@{}
        foreach ($n in $k.GetValueNames()) { $values[$n] = [int]$k.GetValue($n) }
        return $values
    } finally { $k.Close() }
}

function Format-State([int]$q) {
    if ($q -lt 0) { return 'no override (Windows default)' }
    $prio = $q -shr 8; $state = $q -band 0xFF
    $prioName = switch ($prio) { 15 { 'ImageOverride' } 9 { 'Security' } 8 { 'User' } 4 { 'Service' } 1 { 'EKB' } 0 { 'ImageDefault' } default { "$prio" } }
    $stateName = switch ($state) { 0 { 'Default' } 1 { 'Disabled' } 2 { 'Enabled' } default { "$state" } }
    return "$stateName (priority $prio $prioName)"
}

function Show-Status {
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    Write-Host ("Windows {0}  build {1}.{2}" -f $cv.DisplayVersion, $cv.CurrentBuild, $cv.UBR)
    foreach ($m in "$env:SystemRoot\explorer.exe", "$env:SystemRoot\System32\ExplorerFrame.dll") {
        if (Test-Path $m) { Write-Host ("  {0} {1}" -f (Split-Path $m -Leaf), (Get-Item $m).VersionInfo.ProductVersion) }
    }
    $backedUp = @(Read-Backup | ForEach-Object { $_.FeatureId } | Sort-Object -Unique)
    Write-Host ''
    $needsFix = $false; $needsReboot = $false; $blockedAbove = $false; $allOff = $true
    # Show every known bundle, not only the ones -Mode selects, so the effect of each mode is visible.
    foreach ($f in $AllFeatures) {
        $running = [QTFeatureNative]::Query([uint32]$f.Id, 1)
        $prios = Get-OverridePriorities $f.Key
        $selected = $Features -contains $f
        Write-Host ("Feature {0} (key {1}){2}{3}" -f $f.Id, $f.Key, $(if ($selected) { " [mode $Mode]" } else { '' }), $(if ($backedUp -contains $f.Id) { ' [backed up]' } else { '' }))
        Write-Host ("  running now : {0}" -f (Format-State $running))
        if ($prios.Count -eq 0) { Write-Host '  registry    : no overrides' }
        foreach ($p in $prios) { Write-Host ("  registry    : priority {0}, EnabledState={1}" -f $p, (Read-Override $p $f.Key)['EnabledState']) }
        $pol = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($PolicyOverridesPath)
        if ($pol) { try { if ($null -ne $pol.GetValue($f.Key)) { Write-Host ("  policy      : {0}" -f $pol.GetValue($f.Key)); $blockedAbove = $true } } finally { $pol.Close() } }
        if (-not $selected) { continue }
        $p8 = Read-Override $PriorityUser $f.Key
        # Anything above User priority other than the ImageOverride we remove wins over our override.
        foreach ($p in $prios) { if ($p -gt $PriorityUser -and $p -ne $PriorityImageOverride) { $blockedAbove = $true } }
        $regOk = ($prios -notcontains $PriorityImageOverride) -and $p8 -and ($p8['EnabledState'] -eq $StateDisabled)
        # A child bundle can be off at run time through its parent (Definitions\Associations) while
        # its own ImageOverride key is still there, so what Explorer sees decides first.
        $off = $running -ge 0 -and ($running -band 0xFF) -eq $StateDisabled
        if (-not $off) { $allOff = $false }
        if (-not $regOk) { $needsFix = $true }
        elseif (-not $off) { $needsReboot = $true }
    }
    Write-Host ''
    if ($blockedAbove) { Write-Host 'Warning: an override above User priority (9-14) or a policy override exists; this script cannot beat it.' }
    if ($allOff) { $needsFix = $false; $needsReboot = $false }
    if ($needsFix) { Write-Host "Result: the classic toolbar is blocked. Run -Action Apply -Mode $Mode (elevated), then restart Windows." }
    elseif ($needsReboot) { Write-Host 'Result: registry is fixed; restart Windows to apply it.' }
    else { Write-Host 'Result: OK - the classic toolbar is available to QTTabBar.' }
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Write-Host ("Startup re-apply task: {0}" -f $(if ($task) { 'installed' } else { 'not installed' }))
}

function Read-Backup {
    if (-not (Test-Path $BackupFile)) { return @() }
    # Windows PowerShell 5.1's ConvertFrom-Json emits a JSON array as ONE object - unroll it.
    $parsed = Get-Content $BackupFile -Raw | ConvertFrom-Json
    $entries = @(foreach ($e in $parsed) { $e })
    foreach ($e in $entries) {
        if (-not ("$($e.Key)" -match '^\d+$') -or -not ("$($e.Priority)" -match '^\d+$')) { throw "Malformed entry in $BackupFile." }
    }
    return $entries
}

function Save-Backup([object[]]$Entries) {
    Initialize-DataDir
    ConvertTo-Json -InputObject @($Entries) -Depth 4 | Set-Content -Path $BackupFile -Encoding UTF8
}

function Invoke-Apply {
    Assert-Admin
    [QTFeatureNative]::EnablePrivilege('SeRestorePrivilege')
    [QTFeatureNative]::EnablePrivilege('SeBackupPrivilege')

    # Backup first, and never overwrite an entry that is already backed up: after the first Apply the
    # current priority-8 keys are ours, the originals are the ones recorded the first time.
    $backup = [System.Collections.ArrayList]@(Read-Backup)
    foreach ($f in $Features) {
        foreach ($prio in $PriorityImageOverride, $PriorityUser) {
            if ($backup | Where-Object { $_.Key -eq $f.Key -and $_.Priority -eq $prio }) { continue }
            $values = Read-Override $prio $f.Key
            if ($prio -eq $PriorityUser -and $null -eq $values) {
                # Record that there was no user override, so Restore removes ours.
                [void]$backup.Add([pscustomobject]@{ FeatureId = $f.Id; Key = $f.Key; Priority = $prio; Existed = $false; Values = $null })
            } elseif ($null -ne $values) {
                [void]$backup.Add([pscustomobject]@{ FeatureId = $f.Id; Key = $f.Key; Priority = $prio; Existed = $true; Values = [pscustomobject]$values })
            }
        }
    }
    Save-Backup $backup.ToArray()

    $changed = $false
    foreach ($f in $Features) {
        if (Read-Override $PriorityImageOverride $f.Key) {
            [QTFeatureNative]::DeleteKey((Get-OverrideKeyPath $PriorityImageOverride $f.Key))
            Write-Log "Feature $($f.Id): removed ImageOverride (15) override."
            $changed = $true
        }
        $p8 = Read-Override $PriorityUser $f.Key
        if (-not $p8 -or $p8['EnabledState'] -ne $StateDisabled) {
            # Same value set ViVeTool /disable writes.
            [QTFeatureNative]::WriteDwords((Get-OverrideKeyPath $PriorityUser $f.Key),
                [string[]]@('EnabledState', 'EnabledStateOptions', 'Variant', 'VariantPayload', 'VariantPayloadKind'),
                [int[]]@($StateDisabled, 0, 0, 0, 0))
            Write-Log "Feature $($f.Id): set User (8) override to Disabled."
            $changed = $true
        }
    }
    if ($changed) { Write-Log "Done (mode $Mode). Restart Windows to bring back the classic Explorer toolbar." }
    else { Write-Log 'Nothing to do: the overrides are already in place.' }
}

function Invoke-Restore {
    Assert-Admin
    $backup = @(Read-Backup)
    if ($backup.Count -eq 0) { throw "No backup found at $BackupFile." }
    [QTFeatureNative]::EnablePrivilege('SeRestorePrivilege')
    [QTFeatureNative]::EnablePrivilege('SeBackupPrivilege')
    foreach ($e in $backup) {
        $path = Get-OverrideKeyPath $e.Priority $e.Key
        if (Read-Override $e.Priority $e.Key) { [QTFeatureNative]::DeleteKey($path) }
        if ($e.Existed) {
            $names = @($e.Values.PSObject.Properties | ForEach-Object { $_.Name })
            $vals = @($e.Values.PSObject.Properties | ForEach-Object { [int]$_.Value })
            [QTFeatureNative]::WriteDwords($path, [string[]]$names, [int[]]$vals)
            Write-Log "Feature $($e.FeatureId): restored priority $($e.Priority) override."
        } else {
            Write-Log "Feature $($e.FeatureId): removed priority $($e.Priority) override (there was none before)."
        }
    }
    Remove-Task
    Remove-Item $BackupFile -Force
    Write-Log 'Restored. Restart Windows to apply.'
}

function Install-Task {
    Assert-Admin
    # The task runs as SYSTEM, so it must run a copy that only Administrators can modify.
    Initialize-DataDir
    if ($PSCommandPath -ne $TaskScript) { Copy-Item -Path $PSCommandPath -Destination $TaskScript -Force }
    $action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$TaskScript`" -Action Apply -Mode $Mode -Quiet"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
        -Description 'Re-applies the QTTabBar classic-toolbar fix after Windows updates restore the ImageOverride feature overrides.' -Force | Out-Null
    Write-Log "Installed startup task '$TaskName' ($TaskScript)."
}

function Remove-Task {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Log "Removed startup task '$TaskName'."
    }
    # Keep the backup and log; only the task's copy of the script goes.
    if ((Test-Path $TaskScript) -and ($PSCommandPath -ne $TaskScript)) { Remove-Item $TaskScript -Force }
}

try {
    switch ($Action) {
        'Status'      { Show-Status }
        'Apply'       { Invoke-Apply }
        'Restore'     { Invoke-Restore }
        'InstallTask' { Invoke-Apply; Install-Task }
        'RemoveTask'  { Assert-Admin; Remove-Task }
    }
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
