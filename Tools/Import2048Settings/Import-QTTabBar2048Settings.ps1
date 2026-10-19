<#
.SYNOPSIS
    Imports a QTTabBar "2048 Beta2" settings export (XML) into this QTTabBar fork's registry settings.

.DESCRIPTION
    QTTabBar 2048 Beta2 (Quizo's closed-source build) exports its settings as XML: a 399-section
    bit-vector (<Config><Config>, 80 bytes hex), KeyboardShortcuts (int32[183] hex), mouse event
    bindings (int32[8] per event source), plain elements (tab skin path, colours as signed ARGB,
    sizes, fonts, ...) and the command bars. This fork stores its settings in
    HKCU\Software\QTTabBar\Config\<Category>, one registry value per Config property
    (bool/int -> REG_DWORD, enums -> REG_SZ member name, Font/Color/Padding/arrays -> REG_SZ JSON in
    DataContractJsonSerializer shape).

    The script converts what has a fork equivalent:
      - keyboard shortcuts (Keys\Shortcuts, Keys\UseTabSwitcher)
      - option toggles and enums (Window, Tabs, Tweaks, Tips, Misc, Skin, BBar, Desktop)
      - tab metrics, colours, fonts, tab skin image path
      - the first command bar (BBar\ButtonIndexes, LargeButtons, ShowButtonLabels)
      - the second and vertical command bars (CmdBars\SecondBarItems, VerticalBarItems, icon sizes,
        labels, VerticalBarVisible) and the command button click / middle-click events
        (CmdBars\ClickActions, MiddleClickActions): folder, file/program and group buttons,
        separators, child items, virtual folders (menu buttons) and custom icons; 2048 basic and
        advanced (script) commands are listed as not imported
      - groups (HKCU\Software\QTTabBar\Groups): 2048 groups whose name the fork doesn't have yet are
        appended, their folder PIDLs resolved to paths on this machine; existing groups are kept
      - mouse bindings of tabs, the tab bar, folder icons and the view background (Mouse\TabActions,
        BarActions, ItemActions, MarginActions), starting from the fork defaults
    and reports what it cannot map: 2048-only options you changed, lost shortcuts, mouse bindings
    without a fork equivalent, plugins and application launchers (skipped by design).

    Keyboard policy: the fork's default shortcut table is the base. Every fork action that has a
    2048 counterpart takes the 2048 binding (a binding you cleared in 2048 clears the fork default;
    a slot that is empty in 2048 by default keeps the fork default). If one of your 2048 chords is
    bound by default to a different fork action, your binding wins and the displaced fork default is
    unbound; both are reported as conflicts. Bindings whose fork target has an empty handler in this
    fork build (NewFolder, ShowRecentFilesMenu, SortTabsBy*) are not transferred and reported.

    Without -Apply nothing is written (dry run). The dry run prints, per category, each value that
    would be written (name, kind, value), whether it differs from the value currently in HKCU and
    from the fork default, and the lists of unmapped items and conflicts.

    With -Apply the script first runs 'reg export HKCU\Software\QTTabBar <BackupPath> /y' (when the
    key exists), then writes the values with explicit kinds (New-ItemProperty -PropertyType DWord or
    String; the fork's Config uses no REG_MULTI_SZ values). Only names present in the fork's Config
    schema (derived from QTTabBar\Config.cs, kept in the .Data.psd1 next to this script) are ever
    written, and the fork's ReadConfig clamps are applied before writing.

    IMPORTANT: after -Apply restart Explorer (or sign out and in) BEFORE opening QTTabBar Options.
    An Explorer process that already has QTTabBar loaded keeps its settings in memory and writes
    all of them back when OK/Apply is pressed in Options, overwriting the imported values.

    Conversions worth knowing (details per value in the report):
      - Colours are written as ARGB and Skin\SkinAutoColorChangeClose is set to 1; otherwise the fork
        replaces them with its light/dark preset whenever an Explorer window opens.
        Skin\ToolBarTextColor (no 2048 equivalent) is derived for contrast with the toolbar colour.
      - An empty <TabFont> means the 2048 default font: "Yu Gothic UI" on a ja-JP UI, else "Segoe UI".
      - Tab history / recent file counts are clamped to the fork's 1..128.
      - 2048 sections that 2048 itself never reads (e.g. CommandBar_LockMenu) are ignored.

    Restore: double-click the backup .reg file (or 'reg import <file>'); if there was no
    HKCU\Software\QTTabBar key before the import, delete that key instead.

    Requirements: Windows PowerShell 5.1 or PowerShell 7, no modules. Nothing from the 2048 package is
    loaded or executed; the 2048 layout tables in the data file were derived offline.

.PARAMETER XmlPath
    Path of the 2048 settings export (QTTabBarConfig-*.xml).

.PARAMETER Apply
    Write the values to HKCU (after the backup). Without it the script only prints the plan.

.PARAMETER BackupPath
    Where -Apply saves 'reg export HKCU\Software\QTTabBar'. Default:
    %LOCALAPPDATA%\QTTabBar\backup-<yyyyMMdd-HHmmss>.reg

.PARAMETER Only
    Restrict writing to these fork categories: Window, Tabs, Tweaks, Tips, Misc, Skin, BBar, CmdBars,
    Keys, Mouse, Desktop, Groups (list or one comma-separated string, e.g. -Only CmdBars,Groups). The report
    still lists everything.

.PARAMETER ReportPath
    Also write the mapping report as Markdown to this file (UTF-8). The report contains your
    settings (paths, colours, shortcuts) - keep it out of source control.

.PARAMETER DefaultFontName
    Font used when the export has an empty <TabFont> (2048 then used its default font: "Yu Gothic UI"
    on a Japanese UI, otherwise "Segoe UI"). Default: decided from the current UI culture.

.PARAMETER SelfTest
    Decode the embedded 2048 default blobs and verify known defaults, the JSON shapes and the
    mapping logic (and, when QTTabBar\Config.cs is found next to the repository copy of this script,
    that the embedded fork schema, BindAction order and default shortcuts still match it).
    Exits with code 1 on failure. Needs no user data and touches no registry.

.EXAMPLE
    .\Import-QTTabBar2048Settings.ps1 -XmlPath .\QTTabBarConfig-2026-10-18.xml
    Dry run: prints what would be written and what cannot be mapped.

.EXAMPLE
    .\Import-QTTabBar2048Settings.ps1 -XmlPath .\QTTabBarConfig-2026-10-18.xml -ReportPath $env:TEMP\import2048.md
    Dry run plus a Markdown report.

.EXAMPLE
    .\Import-QTTabBar2048Settings.ps1 -XmlPath .\QTTabBarConfig-2026-10-18.xml -Apply
    Backs up HKCU\Software\QTTabBar, writes the converted settings, then restart Explorer.

.EXAMPLE
    .\Import-QTTabBar2048Settings.ps1 -XmlPath .\QTTabBarConfig-2026-10-18.xml -Apply -Only Keys,Tabs
    Imports only the keyboard shortcuts and the tab behaviour options.

.EXAMPLE
    .\Import-QTTabBar2048Settings.ps1 -SelfTest
#>
[CmdletBinding(DefaultParameterSetName = 'Import', SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Import', Position = 0)]
    [string]$XmlPath,

    [Parameter(ParameterSetName = 'Import')]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'Import')]
    [string]$BackupPath,

    [Parameter(ParameterSetName = 'Import')]
    [string[]]$Only,

    [Parameter(ParameterSetName = 'Import')]
    [string]$ReportPath,

    [Parameter(ParameterSetName = 'Import')]
    [string]$DefaultFontName,

    [Parameter(Mandatory = $true, ParameterSetName = 'SelfTest')]
    [switch]$SelfTest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Inv = [System.Globalization.CultureInfo]::InvariantCulture
$script:RegRoot = 'Software\QTTabBar'
$script:RegConfig = 'Software\QTTabBar\Config'
$script:CategoryOrder = @('Window', 'Tabs', 'Tweaks', 'Tips', 'Misc', 'Skin', 'BBar', 'CmdBars', 'Keys', 'Mouse', 'Desktop')
# -Only also accepts 'Groups' (HKCU\Software\QTTabBar\Groups, not a Config category).
$script:GroupsCategory = 'Groups'

# ---------------------------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------------------------

$script:DataFile = Join-Path $PSScriptRoot 'Import-QTTabBar2048Settings.Data.psd1'
if (-not (Test-Path -LiteralPath $script:DataFile)) { throw "Data file not found: $script:DataFile" }
$script:Data = Import-PowerShellDataFile -LiteralPath $script:DataFile

# Fork schema: Category -> (Name -> C# type), from the data file (derived from Config.cs).
$script:Schema = @{}
foreach ($cat in @($script:Data.ForkSchema.get_Keys())) {
    $t = @{}
    foreach ($entry in $script:Data.ForkSchema[$cat]) {
        $i = $entry.IndexOf(':')
        $t[$entry.Substring(0, $i)] = $entry.Substring($i + 1)
    }
    $script:Schema[$cat] = $t
}

# Fork BindAction members 0 .. KEYBOARD_ACTION_COUNT-1 (Config.cs, persisted ordinals).
$script:ForkActions = @(
    'GoBack', 'GoForward', 'GoFirst', 'GoLast', 'NextTab', 'PreviousTab', 'FirstTab', 'LastTab',
    'SwitchToLastActivated', 'NewTab', 'NewWindow', 'MergeWindows', 'CloseCurrent', 'CloseAllButCurrent',
    'CloseLeft', 'CloseRight', 'CloseWindow', 'RestoreLastClosed', 'CloneCurrent', 'TearOffCurrent',
    'LockCurrent', 'LockAll', 'BrowseFolder', 'CreateNewGroup', 'ShowOptions', 'ShowToolbarMenu',
    'ShowTabMenuCurrent', 'ShowGroupMenu', 'ShowUserAppsMenu', 'ShowRecentTabsMenu', 'ShowRecentFilesMenu',
    'NewFile', 'NewFolder', 'CopySelectedPaths', 'CopySelectedNames', 'CopyCurrentFolderPath',
    'CopyCurrentFolderName', 'ChecksumSelected', 'ToggleTopMost', 'TransparencyPlus', 'TransparencyMinus',
    'FocusFileList', 'FocusSearchBarReal', 'FocusSearchBarBBar', 'ShowSDTSelected', 'SendToTray',
    'FocusTabBar', 'SortTabsByName', 'SortTabsByPath', 'SortTabsByActive', 'FocusTree', 'FocusVerticalCommandBar',
    'CopySelectedToTab', 'MoveSelectedToTab', 'CopyFromFolder', 'MoveFromFolder', 'RenameCurrentFolder', 'CreateNewLibrary'
)

# System.Windows.Forms.Keys values used below.
$script:KShift = 0x10000
$script:KCtrl = 0x20000
$script:KAlt = 0x40000
$script:FlagEnabled = 0x100000
$script:FlagPassThrough = 0x200000

# Fork default shortcuts (Config._Keys constructor; stored as Keys | FLAG_KEYENABLED).
$script:ForkDefaultKeys = [ordered]@{
    GoBack              = 37 + $KAlt           # Left, Alt
    GoForward           = 39 + $KAlt           # Right, Alt
    GoFirst             = 37 + $KCtrl + $KAlt
    GoLast              = 39 + $KCtrl + $KAlt
    NextTab             = 9 + $KCtrl           # Tab
    PreviousTab         = 9 + $KCtrl + $KShift
    NewTab              = 84 + $KCtrl          # T
    NewWindow           = 84 + $KCtrl + $KShift
    CloseCurrent        = 87 + $KCtrl          # W
    CloseAllButCurrent  = 87 + $KCtrl + $KShift
    RestoreLastClosed   = 90 + $KCtrl + $KShift # Z
    BrowseFolder        = 79 + $KCtrl          # O
    ShowOptions         = 79 + $KAlt
    ShowToolbarMenu     = 188 + $KAlt          # Oemcomma
    ShowTabMenuCurrent  = 190 + $KAlt          # OemPeriod
    ShowGroupMenu       = 71 + $KAlt           # G
    ShowUserAppsMenu    = 72 + $KAlt           # H
    ShowRecentTabsMenu  = 85 + $KAlt           # U
    ShowRecentFilesMenu = 70 + $KAlt           # F
    NewFile             = 78 + $KCtrl + $KAlt  # N
    CreateNewGroup      = 68 + $KCtrl          # D
}

# Fork actions whose case in QTTabBarClass.DoBindAction is empty in this fork build: a key bound to
# them is swallowed without effect, so 2048 bindings are not transferred to them.
$script:ForkNoopActions = @('SortTabsByName', 'SortTabsByPath', 'SortTabsByActive')

# 2048 KeyShortcuts index -> fork BindAction (+ note for approximate equivalents).
$script:KeyMap = @(
    @(0, 'GoBack', ''), @(1, 'GoForward', ''), @(2, 'GoFirst', ''), @(3, 'GoLast', ''),
    @(4, 'NextTab', ''), @(5, 'PreviousTab', ''), @(6, 'FirstTab', ''), @(7, 'LastTab', ''),
    @(8, 'CloseCurrent', ''), @(9, 'CloseAllButCurrent', ''), @(10, 'CloseLeft', ''), @(11, 'CloseRight', ''),
    @(12, 'CloseWindow', ''), @(13, 'RestoreLastClosed', ''), @(14, 'CloneCurrent', ''),
    @(15, 'TearOffCurrent', 'approximate: the fork opens the folder in a new window AND closes the tab (if more than one)'),
    @(16, 'LockCurrent', ''), @(17, 'LockAll', ''), @(18, 'BrowseFolder', ''), @(19, 'CreateNewGroup', ''),
    @(20, 'ShowOptions', ''), @(21, 'ShowToolbarMenu', ''), @(22, 'ShowTabMenuCurrent', ''),
    @(23, 'ShowGroupMenu', 'clicks the Groups button of the fork button bar'),
    @(24, 'ShowRecentTabsMenu', 'clicks the Recent Tabs button of the fork button bar'),
    @(25, 'ShowUserAppsMenu', 'clicks the Application launcher button of the fork button bar'),
    @(27, 'CopySelectedPaths', ''), @(28, 'CopySelectedNames', ''), @(29, 'CopyCurrentFolderPath', ''),
    @(30, 'CopyCurrentFolderName', ''),
    @(31, 'ChecksumSelected', 'approximate: fork opens its checksum window for the selection'),
    @(33, 'ToggleTopMost', ''), @(34, 'TransparencyPlus', ''), @(35, 'TransparencyMinus', ''),
    @(36, 'FocusFileList', ''), @(37, 'FocusSearchBarReal', ''), @(39, 'FocusTabBar', ''),
    @(41, 'ShowSDTSelected', ''), @(43, 'SendToTray', ''),
    @(51, 'NewFolder', ''), @(52, 'NewFile', ''), @(78, 'MergeWindows', ''), @(81, 'ShowRecentFilesMenu', ''),
    @(82, 'SwitchToLastActivated', ''),
    @(100, 'FocusSearchBarBBar', 'approximate: fork focuses the search box of its button bar (2048: filter box)'),
    @(38, 'FocusTree', ''), @(40, 'FocusVerticalCommandBar', ''),
    @(56, 'CopySelectedToTab', 'approximate: the target tab is picked from a menu'), @(57, 'MoveSelectedToTab', 'approximate: the target tab is picked from a menu'),
    @(65, 'CopyFromFolder', 'approximate: the files are picked in a file dialog'), @(66, 'MoveFromFolder', 'approximate: the files are picked in a file dialog'),
    @(79, 'CreateNewLibrary', ''), @(99, 'RenameCurrentFolder', '')
)

# 2048 shortcuts that Explorer itself has with the same keys (view modes): nothing to import.
$script:ExplorerNativeKeys = @{ 125 = 'Ctrl+Shift+1'; 126 = 'Ctrl+Shift+2'; 127 = 'Ctrl+Shift+3'; 128 = 'Ctrl+Shift+4'; 129 = 'Ctrl+Shift+5'; 130 = 'Ctrl+Shift+6'; 131 = 'Ctrl+Shift+7'; 132 = 'Ctrl+Shift+8' }

# 2048 BuiltinCommandID -> fork QTButtonBar BII_* index (-1 = no equivalent).
$script:ButtonMap = @{
    0 = 0; 1 = 1; 2 = 2; 3 = 3; 4 = 4; 5 = 5; 6 = 6; 7 = 7; 8 = 8; 9 = 9; 10 = 10; 11 = 11; 12 = 12
    13 = 13; 14 = 14; 15 = 15; 16 = 16; 17 = 17; 18 = 18; 19 = 21; 20 = -1; 21 = 19; 22 = -1; 23 = 20
}
$script:ForkButtonNames = @('Separator', 'Back', 'Forward', 'Groups', 'RecentTabs', 'AppLauncher', 'NewWindow',
    'Clone', 'Lock', 'MiscTool', 'TopMost', 'CloseCurrent', 'CloseAllButCurrent', 'CloseWindow', 'CloseLeft',
    'CloseRight', 'GoUpOneLevel', 'Refresh', 'ShellSearch', 'WindowOpacity', 'FilterBar', 'Options')

# Fork ReadConfig clamps (Config.cs ReadConfig) and other value ranges the fork enforces.
$script:Clamps = @{
    'Tips.PreviewMaxWidth'   = @(128, 1920)
    'Tips.PreviewMaxHeight'  = @(96, 1200)
    'Misc.TabHistoryCount'   = @(1, 128)
    'Misc.FileHistoryCount'  = @(1, 128)
    'Misc.NetworkTimeout'    = @(0, 120)
    'Skin.TabHeight'         = @(10, 50)
    'Skin.TabMinWidth'       = @(10, 100)
    'Skin.TabMaxWidth'       = @(50, 999)
    'Desktop.FirstItem'      = @(0, 3)
    'Desktop.SecondItem'     = @(0, 3)
    'Desktop.ThirdItem'      = @(0, 3)
    'Desktop.FourthItem'     = @(0, 3)
    'CmdBars.SecondBarIconSize'   = @(16, 256)
    'CmdBars.VerticalBarIconSize' = @(16, 256)
}

# The fork's default font name is "Microsoft YaHei" written with CJK characters (kept ASCII here).
$script:YaHei = -join ([char[]]@(0x5FAE, 0x8F6F, 0x96C5, 0x9ED1))

# Fork defaults (constructors in Config.cs, Windows 10/11, not XP/Win7) in canonical form, for the
# "vs fork default" column. Colours: the fork's light/dark auto colouring (Skin.SwitchNighMode)
# replaces these at runtime unless Skin.SkinAutoColorChangeClose = 1.
$script:ForkDefaults = @{
    'Window.CaptureNewWindows' = '1'; 'Window.RestoreSession' = '1'; 'Window.RestoreOnlyLocked' = '0'; 'Window.TrayOnMinimize' = '0'
    'Tabs.NewTabPosition' = 'Rightmost'; 'Tabs.NextAfterClosed' = 'LastActive'; 'Tabs.ActivateNewTab' = '1'; 'Tabs.NeverOpenSame' = '1'
    'Tabs.RenameAmbTabs' = '1'; 'Tabs.DragOverTabOpensSDT' = '1'; 'Tabs.ShowFolderIcon' = '1'; 'Tabs.ShowSubDirTipOnTab' = '0'
    'Tabs.ShowDriveLetters' = '0'; 'Tabs.ShowCloseButtons' = '1'; 'Tabs.CloseBtnsWithAlt' = '0'; 'Tabs.CloseBtnsOnHover' = '0'
    'Tabs.ShowNavButtons' = '0'; 'Tabs.NavButtonsOnRight' = '1'; 'Tabs.MultipleTabRows' = '1'; 'Tabs.ActiveTabOnBottomRow' = '0'
    'Tabs.NeedPlusButton' = '1'
    'Tweaks.AlwaysShowHeaders' = '0'; 'Tweaks.F2Selection' = '0'; 'Tweaks.WrapArrowKeySelection' = '1'; 'Tweaks.BackspaceUpLevel' = '1'
    'Tweaks.HorizontalScroll' = '1'; 'Tweaks.ToggleFullRowSelect' = '0'
    'Tips.ShowSubDirTips' = '1'; 'Tips.SubDirTipsPreview' = '1'; 'Tips.SubDirTipsFiles' = '1'; 'Tips.SubDirTipsWithShift' = '0'
    'Tips.ShowTooltipPreviews' = '1'; 'Tips.ShowPreviewsWithShift' = '1'; 'Tips.ShowPreviewInfo' = '1'
    'Tips.PreviewMaxWidth' = '600'; 'Tips.PreviewMaxHeight' = '400'; 'Tips.PreviewFont' = ('Font:' + $script:YaHei + '|9|0')
    'Misc.KeepHistory' = '1'; 'Misc.TabHistoryCount' = '15'; 'Misc.KeepRecentFiles' = '1'; 'Misc.FileHistoryCount' = '15'; 'Misc.AutoUpdate' = '1'
    'Skin.UseTabSkin' = '0'; 'Skin.TabImageFile' = ''; 'Skin.TabSizeMargin' = 'Pad:0,0,0,0'; 'Skin.TabContentMargin' = 'Pad:0,0,0,0'
    'Skin.TabHeight' = '30'; 'Skin.TabMinWidth' = '100'; 'Skin.TabMaxWidth' = '200'; 'Skin.FixedWidthTabs' = '0'
    'Skin.TabTextFont' = ('Font:' + $script:YaHei + '|9|0')
    'Skin.ToolBarTextColor' = 'ARGB:FF000000'; 'Skin.TabTextActiveColor' = 'ARGB:FF000000'; 'Skin.TabTextInactiveColor' = 'ARGB:FF000000'
    'Skin.TabTextHotColor' = 'ARGB:FF000000'; 'Skin.TabShadActiveColor' = 'ARGB:FFF5F5F5'; 'Skin.TabShadInactiveColor' = 'ARGB:FFF5F5F5'
    'Skin.TabShadHotColor' = 'ARGB:FFF5F5F5'; 'Skin.RebarColor' = 'ARGB:FFF5F5F5'
    'Skin.TabTitleShadows' = '0'; 'Skin.TabTextCentered' = '1'; 'Skin.UseRebarBGColor' = '1'; 'Skin.UseRebarImage' = '0'
    'Skin.RebarStretchMode' = 'Tile'; 'Skin.RebarImageFile' = ''; 'Skin.RebarImageSeperateBars' = '0'; 'Skin.ActiveTabInBold' = '1'
    'Skin.SkinAutoColorChangeClose' = '0'; 'Skin.DrawHorizontalExplorerBarBgColor' = '0'; 'Skin.DrawVerticalExplorerBarBgColor' = '0'
    'BBar.ButtonIndexes' = '[3,4,5,6,7,17,11,12,14,15,13,21,9,19,10]'; 'BBar.LargeButtons' = '1'; 'BBar.LockDropDownButtons' = '1'
    'BBar.ShowButtonLabels' = '1'; 'BBar.ImageStripPath' = ''
    'CmdBars.SecondBarItems' = ''; 'CmdBars.VerticalBarItems' = ''; 'CmdBars.SecondBarIconSize' = '32'; 'CmdBars.VerticalBarIconSize' = '48'
    'CmdBars.SecondBarShowLabels' = '0'; 'CmdBars.VerticalBarShowLabels' = '0'; 'CmdBars.VerticalBarVisible' = '0'
    'CmdBars.ClickActions' = '[0,12,1,-1,5,-1,-1,-1]'; 'CmdBars.MiddleClickActions' = '[15,-1,-1,-1,13,-1,-1,-1]'
    'Keys.UseTabSwitcher' = '1'
    'Desktop.FirstItem' = '0'; 'Desktop.SecondItem' = '1'; 'Desktop.ThirdItem' = '2'; 'Desktop.FourthItem' = '3'
    'Desktop.GroupExpanded' = '0'; 'Desktop.RecentTabExpanded' = '0'; 'Desktop.ApplicationExpanded' = '0'; 'Desktop.RecentFileExpanded' = '0'
    'Desktop.TaskBarDblClickEnabled' = '1'; 'Desktop.DesktopDblClickEnabled' = '1'; 'Desktop.LockMenu' = '0'; 'Desktop.TitleBackground' = '0'
    'Desktop.IncludeGroup' = '0'; 'Desktop.IncludeRecentTab' = '1'; 'Desktop.IncludeApplication' = '1'; 'Desktop.IncludeRecentFile' = '1'
    'Desktop.OneClickMenu' = '0'; 'Desktop.EnableAppShortcuts' = '1'
}

# Simple 1:1 boolean options: fork Category.Name <- 2048 section.
$script:BoolMap = @(
    @('Window', 'CaptureNewWindows', 'CaptureWindow'),
    @('Window', 'RestoreSession', 'RestoreTabs'),
    @('Window', 'RestoreOnlyLocked', 'RestoreLockedTabs'),
    @('Window', 'TrayOnMinimize', 'SendWindowToTrayOnMinimize'),
    @('Tabs', 'ActivateNewTab', 'ActivateNewTab'),
    @('Tabs', 'NeverOpenSame', 'NoSameTab'),
    @('Tabs', 'RenameAmbTabs', 'TabAutoSuffix'),
    @('Tabs', 'ShowFolderIcon', 'TabFolderIcon'),
    @('Tabs', 'ShowSubDirTipOnTab', 'TabFolderIconShowMenu'),
    @('Tabs', 'ShowDriveLetters', 'TabFolderIconDriveLetter'),
    @('Tabs', 'ShowCloseButtons', 'TabCloseButton'),
    @('Tabs', 'CloseBtnsWithAlt', 'TabCloseButtonWithAlt'),
    @('Tabs', 'CloseBtnsOnHover', 'TabCloseButtonOnHover'),
    @('Tabs', 'NeedPlusButton', 'PlusButtonOnTabBar'),
    @('Keys', 'UseTabSwitcher', 'ShowTabSwitcher'),
    @('Tweaks', 'AlwaysShowHeaders', 'AlwaysColumnHeader'),
    @('Tweaks', 'F2Selection', 'ViewF2ChangeTextSelection'),
    @('Tweaks', 'WrapArrowKeySelection', 'ViewCursorLoop'),
    @('Tweaks', 'BackspaceUpLevel', 'ViewBSKeyGoUp'),
    @('Tweaks', 'HorizontalScroll', 'ViewHorizontalScroll'),
    @('Tips', 'ShowPreviewsWithShift', 'PreviewWithShiftKeyDown'),
    @('Tips', 'ShowPreviewInfo', 'PreviewShowImageDetails'),
    @('Tips', 'SubDirTipsFiles', 'SubDirTipMenuIncludeFiles'),
    @('Tips', 'SubDirTipsPreview', 'SubDirTipMenuShowPreview'),
    @('Misc', 'AutoUpdate', 'CheckUpdate'),
    @('Misc', 'KeepHistory', 'SaveRecentTab'),
    @('Skin', 'TabTitleShadows', 'TabTextShadow'),
    @('Skin', 'UseRebarBGColor', 'RebarBackgroundColor'),
    @('Skin', 'UseRebarImage', 'RebarBackgroundImage'),
    @('Desktop', 'GroupExpanded', 'Desktop_GroupExpanded'),
    @('Desktop', 'RecentTabExpanded', 'Desktop_RecentTabExpanded'),
    @('Desktop', 'ApplicationExpanded', 'Desktop_ApplicationExpanded'),
    @('Desktop', 'RecentFileExpanded', 'Desktop_RecentFileExpanded'),
    @('Desktop', 'DesktopDblClickEnabled', 'Desktop_DesktopDoubleClickEnabled'),
    @('Desktop', 'TitleBackground', 'Desktop_TitleBackground'),
    @('Desktop', 'IncludeGroup', 'Desktop_IncludeGroup'),
    @('Desktop', 'IncludeRecentTab', 'Desktop_IncludeRecentTab'),
    @('Desktop', 'IncludeApplication', 'Desktop_IncludeApplication'),
    @('Desktop', 'IncludeRecentFile', 'Desktop_IncludeRecentFile'),
    @('Desktop', 'EnableAppShortcuts', 'Desktop_EnbleApplicationShortcuts')
)
# 2048 sections that 2048 itself never reads (only created in Config.InitializeSection), so their
# values carry no user choice: not mapped to CommandBar_LockMenu -> BBar.LockDropDownButtons,
# Desktop_TaskBarDoubleClickEnabled, Desktop_LockMenu, Desktop_1ClickMenu, ButtonBar_LargeButton,
# TabTextBoldActive (2048 uses TabFontStyleActive and the command bar IconSize instead).
$script:DeadSections = @('CommandBar_LockMenu', 'Desktop_TaskBarDoubleClickEnabled', 'Desktop_LockMenu', 'Desktop_1ClickMenu', 'ButtonBar_LargeButton', 'TabTextBoldActive')

# XML <Config> scalar elements that are imported (everything else is listed as not imported).
$script:ImportedScalars = @('RecentTabMax', 'RecentFileMax', 'ToolbarBGImage', 'TabFont', 'TabFontSize', 'TabFontStyle',
    'TabFontStyleActive', 'TabImage', 'TabImageSizingMargin', 'TabPadding', 'TabWidth', 'TabHeight', 'TabWidthMax',
    'TabWidthMin', 'ColorActive', 'ColorInactive', 'ColorHighlightClassic', 'ColorShadowActive', 'ColorShadowInacitve',
    'ColorToolbarBackground', 'ColorVerticalBarBackground', 'ColorHorizontalBarBackground', 'PreviewMaxWidth',
    'PreviewMaxHeight', 'PreviewFont', 'PreviewFontSize', 'PreviewFontStyle', 'CommandBarIconSize1st')

# Mouse (report only): 2048 sources with a fork counterpart -> fork target + button, the fork's default
# bindings, and 2048 list entries with an equivalent fork action.
$script:MouseTargets = [ordered]@{
    TabClick = @('TabActions', 'Left'); TabDoubleClick = @('TabActions', 'Double'); TabMiddleClick = @('TabActions', 'Middle')
    TabBarDoubleClick = @('BarActions', 'Double'); TabBarMiddleClick = @('BarActions', 'Middle')
    ViewIconDoubleClick = @('ItemActions', 'Double'); ViewIconMiddleClick = @('ItemActions', 'Middle')
    ViewFileIconMiddleClick = @('ItemActions', 'Middle')
    ViewBackgroundDoubleClick = @('MarginActions', 'Double'); ViewBackgroundMiddleClick = @('MarginActions', 'Middle')
}
$script:ForkMouseDefaults = @{
    TabActions    = @{ 'Middle' = 'CloseTab'; 'Ctrl+Left' = 'LockTab'; 'Double' = 'UpOneLevelTab' }
    BarActions    = @{ 'Double' = 'NewTab'; 'Middle' = 'RestoreLastClosed'; 'Ctrl+Middle' = 'TearOffCurrent' }
    ItemActions   = @{ 'Middle' = 'ItemOpenInNewTab'; 'Ctrl+Middle' = 'ItemOpenInNewTabNoSel' }
    MarginActions = @{ 'Double' = 'UpOneLevel'; 'Middle' = 'BrowseFolder'; 'Ctrl+Double' = 'OpenCmd'; 'Ctrl+Middle' = 'ItemsOpenInNewTabNoSel' }
}
$script:MouseEquiv = @{
    Tab            = @{ 0 = 'CloseTab'; 1 = 'UpOneLevelTab'; 2 = 'LockTab'; 3 = 'ShowTabMenu'; 4 = 'TearOffTab'; 5 = 'CloneTab'; 6 = 'CopyTabPath'; 7 = 'TabProperties'; 8 = 'ShowTabSubfolderMenu' }
    TabDouble      = @{ 0 = 'CloseTab'; 1 = 'UpOneLevelTab'; 2 = 'LockTab'; 3 = 'ShowTabMenu'; 4 = 'TearOffTab'; 5 = 'CloneTab'; 6 = 'CopyTabPath'; 7 = 'TabProperties'; 8 = 'ShowTabSubfolderMenu' }
    TabBar         = @{ 0 = 'UpOneLevel'; 1 = 'BrowseFolder'; 2 = 'CloseAllButCurrent'; 3 = 'LockAll'; 4 = 'ShowToolbarMenu'; 5 = 'RestoreLastClosed'; 6 = 'ShowOptions'; 7 = 'CloseWindow'; 8 = 'CloneCurrent'; 9 = 'SwitchToLastActivated' }
    # Extra View variants (3..11) act on the current view, as in the command bars.
    ViewIcon       = @{ 0 = 'ItemOpenInNewTab'; 1 = 'ItemOpenInNewTabNoSel'; 3 = 'ItemOpenInNewTab'; 4 = 'ItemOpenInNewTabNoSel'; 6 = 'ItemOpenInNewTab'; 7 = 'ItemOpenInNewTabNoSel'; 9 = 'ItemOpenInNewTab'; 10 = 'ItemOpenInNewTabNoSel'; 12 = 'ItemOpenInNewWindow'; 13 = 'ItemCopy'; 14 = 'ItemCut'; 16 = 'ItemProperties'; 17 = 'CopyItemPath' }
    ViewIconMiddle = @{ 0 = 'ItemOpenInNewTab'; 1 = 'ItemOpenInNewTabNoSel'; 3 = 'ItemOpenInNewTab'; 4 = 'ItemOpenInNewTabNoSel'; 6 = 'ItemOpenInNewTab'; 7 = 'ItemOpenInNewTabNoSel'; 9 = 'ItemOpenInNewTab'; 10 = 'ItemOpenInNewTabNoSel'; 12 = 'ItemOpenInNewWindow'; 13 = 'ItemCopy'; 14 = 'ItemCut'; 16 = 'ItemProperties'; 17 = 'CopyItemPath' }
    ViewFileIcon   = @{ 0 = 'ItemCopy'; 1 = 'ItemCut'; 2 = 'ItemProperties'; 3 = 'CopyItemPath' }
    ViewBackground = @{ 0 = 'UpOneLevel'; 1 = 'BrowseFolder'; 2 = 'NewWindow'; 3 = 'CloneCurrent'; 4 = 'CopyCurrentFolderPath'; 5 = 'CopyCurrentFolderName'; 7 = 'CloseWindow'; 8 = 'CloseCurrent'; 9 = 'SelectAll'; 11 = 'NewFolder'; 12 = 'NewFile'; 16 = 'Paste' }
}

# ---------------------------------------------------------------------------------------------
# Generic helpers
# ---------------------------------------------------------------------------------------------

function Format-Inv([string]$Format) {
    return [string]::Format($script:Inv, $Format, [object[]]$args)
}

function ConvertFrom-Hex([string]$Hex) {
    $h = ($Hex -replace '\s', '')
    if (($h.Length % 2) -ne 0 -or $h -notmatch '^[0-9A-Fa-f]*$') { throw "Invalid hex data (length $($h.Length))." }
    $b = New-Object byte[] ($h.Length / 2)
    for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [Convert]::ToByte($h.Substring($i * 2, 2), 16) }
    return ,$b
}

function ConvertTo-Int32Array([byte[]]$Bytes) {
    if (($Bytes.Length % 4) -ne 0) { throw "Byte array length $($Bytes.Length) is not a multiple of 4." }
    $r = New-Object int[] ($Bytes.Length / 4)
    for ($i = 0; $i -lt $r.Length; $i++) { $r[$i] = [BitConverter]::ToInt32($Bytes, $i * 4) }
    return ,$r
}

function Get-BitLength([int]$Value) {
    $n = 0
    while ($Value -gt 0) { $n++; $Value = $Value -shr 1 }
    return $n
}

function New-B2Layout {
    $list = New-Object System.Collections.Generic.List[object]
    $map = @{}
    $prev = $null
    foreach ($s in $script:Data.B2Sections) {
        $i = $s.IndexOf(':')
        $name = $s.Substring(0, $i)
        $max = [int]$s.Substring($i + 1)
        $bits = Get-BitLength $max
        if ($null -eq $prev) { $vec = 0; $off = 0 }
        else {
            $vec = $prev.Vector
            $off = $prev.Offset + $prev.Bits
            if ($off + $bits -gt 32) { $vec++; $off = 0 }
        }
        $e = [pscustomobject]@{ Name = $name; Max = $max; Bits = $bits; Mask = ([int](([long]1 -shl $bits) - 1)); Vector = $vec; Offset = $off }
        $list.Add($e)
        $map[$name] = $e
        $prev = $e
    }
    return [pscustomobject]@{ List = $list; Map = $map; VectorCount = ($prev.Vector + 1) }
}

function Read-B2Sections([byte[]]$Blob, $Layout) {
    if ($Blob.Length -ne $Layout.VectorCount * 4) { throw "Config blob has $($Blob.Length) bytes, expected $($Layout.VectorCount * 4)." }
    $h = @{}
    foreach ($e in $Layout.List) {
        $vec = [long][BitConverter]::ToUInt32($Blob, $e.Vector * 4)
        $h[$e.Name] = [int](($vec -shr $e.Offset) -band $e.Mask)
    }
    return $h
}

$script:KeyNames = @{
    8 = 'Backspace'; 9 = 'Tab'; 13 = 'Enter'; 19 = 'Pause'; 20 = 'CapsLock'; 27 = 'Esc'; 32 = 'Space'; 33 = 'PageUp'; 34 = 'PageDown'
    35 = 'End'; 36 = 'Home'; 37 = 'Left'; 38 = 'Up'; 39 = 'Right'; 40 = 'Down'; 44 = 'PrintScreen'; 45 = 'Insert'; 46 = 'Delete'
    93 = 'Apps'; 106 = 'Num*'; 107 = 'Num+'; 109 = 'Num-'; 110 = 'Num.'; 111 = 'Num/'
    186 = ';'; 187 = '='; 188 = ','; 189 = '-'; 190 = '.'; 191 = '/'; 192 = '`'; 219 = '['; 220 = '\'; 221 = ']'; 222 = "'"
}

function Format-Chord([int]$Value) {
    $code = $Value -band 0xFFFF
    if ($code -eq 0) { return '(none)' }
    $parts = @()
    if (($Value -band $script:KCtrl) -ne 0) { $parts += 'Ctrl' }
    if (($Value -band $script:KShift) -ne 0) { $parts += 'Shift' }
    if (($Value -band $script:KAlt) -ne 0) { $parts += 'Alt' }
    if ($code -ge 65 -and $code -le 90) { $k = [string][char]$code }
    elseif ($code -ge 48 -and $code -le 57) { $k = [string][char]$code }
    elseif ($code -ge 96 -and $code -le 105) { $k = 'Num' + ($code - 96) }
    elseif ($code -ge 112 -and $code -le 135) { $k = 'F' + ($code - 111) }
    elseif ($script:KeyNames.ContainsKey($code)) { $k = $script:KeyNames[$code] }
    else { $k = Format-Inv 'Key0x{0:X2}' $code }
    $parts += $k
    return ($parts -join '+')
}

function Format-Shortcut([int]$Value) {
    if ($Value -eq 0) { return '(none)' }
    $s = Format-Chord $Value
    if (($Value -band $script:FlagEnabled) -eq 0) { $s += ' (disabled)' }
    return $s
}

function ConvertTo-JsonText([string]$Value) {
    if ($null -eq $Value) { return 'null' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $Value.ToCharArray()) {
        $c = [int]$ch
        if ($ch -eq '"') { [void]$sb.Append('\"') }
        elseif ($ch -eq '\') { [void]$sb.Append('\\') }
        elseif ($c -lt 32) { [void]$sb.Append((Format-Inv '\u{0:x4}' $c)) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function ConvertTo-UInt32Argb([long]$Value) {
    if ($Value -lt 0) { $Value += 4294967296 }
    if ($Value -lt 0 -or $Value -gt 4294967295) { throw "Colour value out of range: $Value" }
    return $Value
}

# System.Drawing.Color as DataContractJsonSerializer writes an ARGB colour (Color.FromArgb).
function New-ColorJson([long]$Argb) {
    $u = ConvertTo-UInt32Argb $Argb
    return '{"knownColor":0,"name":null,"state":2,"value":' + $u.ToString($script:Inv) + '}'
}

# QTTabBarLib.XmlSerializableFont as DataContractJsonSerializer writes it.
function New-FontJson([string]$Name, [single]$Size, [int]$Style) {
    return '{"<FontName>k__BackingField":' + (ConvertTo-JsonText $Name) + ',"<FontSize>k__BackingField":' +
        $Size.ToString('R', $script:Inv) + ',"<FontStyle>k__BackingField":' + $Style.ToString($script:Inv) + '}'
}

# System.Windows.Forms.Padding as DataContractJsonSerializer writes it.
function New-PaddingJson([int]$Left, [int]$Top, [int]$Right, [int]$Bottom) {
    $all = ($Left -eq $Top -and $Top -eq $Right -and $Right -eq $Bottom)
    return Format-Inv '{{"_all":{0},"_bottom":{1},"_left":{2},"_right":{3},"_top":{4}}}' ($(if ($all) { 'true' } else { 'false' })) $Bottom $Left $Right $Top
}

function Format-Argb([long]$Argb) {
    $u = ConvertTo-UInt32Argb $Argb
    return Format-Inv '#{0:X8}' $u
}

function Get-Luminance([long]$Argb) {
    $u = ConvertTo-UInt32Argb $Argb
    $r = ($u -shr 16) -band 255; $g = ($u -shr 8) -band 255; $b = $u -band 255
    return (0.299 * $r + 0.587 * $g + 0.114 * $b) / 255.0
}

$script:DrawingLoaded = $null
function Get-KnownColorArgb([int]$Known) {
    if ($null -eq $script:DrawingLoaded) {
        try { Add-Type -AssemblyName System.Drawing; $script:DrawingLoaded = $true } catch { $script:DrawingLoaded = $false }
    }
    if (-not $script:DrawingLoaded) { return $null }
    try { return [long]([System.Drawing.Color]::FromKnownColor([System.Drawing.KnownColor]$Known).ToArgb()) } catch { return $null }
}

# Canonical comparable form of a registry value for a schema type.
function ConvertTo-Canonical([string]$Type, $Value) {
    if ($null -eq $Value) { return $null }
    switch -regex ($Type) {
        '^(bool|int)$' { return ([int]$Value).ToString($script:Inv) }
        '^Color$' {
            $s = [string]$Value
            $m = [regex]::Match($s, '"knownColor"\s*:\s*(-?\d+).*"state"\s*:\s*(-?\d+).*"value"\s*:\s*(-?\d+)')
            if (-not $m.Success) { return $s }
            $known = [int]$m.Groups[1].Value; $state = [int]$m.Groups[2].Value; $val = [long]$m.Groups[3].Value
            if (($state -band 2) -ne 0) { return 'ARGB:' + (Format-Inv '{0:X8}' (ConvertTo-UInt32Argb $val)) }
            if ($known -ne 0) {
                $a = Get-KnownColorArgb $known
                if ($null -ne $a) { return 'ARGB:' + (Format-Inv '{0:X8}' (ConvertTo-UInt32Argb $a)) }
                return "KnownColor:$known"
            }
            return $s
        }
        '^Font$' {
            $s = [string]$Value
            $m = [regex]::Match($s, '<FontName>k__BackingField"\s*:\s*"((?:[^"\\]|\\.)*)".*<FontSize>k__BackingField"\s*:\s*([0-9.Ee+-]+).*<FontStyle>k__BackingField"\s*:\s*(\d+)')
            if (-not $m.Success) { return $s }
            $name = [regex]::Unescape($m.Groups[1].Value)
            $size = [single]::Parse($m.Groups[2].Value, $script:Inv).ToString('R', $script:Inv)
            return 'Font:' + $name + '|' + $size + '|' + $m.Groups[3].Value
        }
        '^Padding$' {
            $s = [string]$Value
            $vals = @{}
            foreach ($k in 'left', 'top', 'right', 'bottom') {
                $m = [regex]::Match($s, '"_' + $k + '"\s*:\s*(-?\d+)')
                if (-not $m.Success) { return $s }
                $vals[$k] = $m.Groups[1].Value
            }
            return 'Pad:' + $vals['left'] + ',' + $vals['top'] + ',' + $vals['right'] + ',' + $vals['bottom']
        }
        '^CommandBarItem\[\]$' { return (ConvertTo-CmdItemsCanonical ([string]$Value)) }
        '^Dictionary<MouseChord,BindAction>$' { return (ConvertTo-MouseDictCanonical ([string]$Value)) }
        '\[\]$' { return (([string]$Value) -replace '\s', '') }
        default { return [string]$Value }
    }
}

# Command bar items as comparable text: the fork writes every member (nulls, zeros), this script
# only the non-default ones.
function ConvertTo-CmdItemsCanonical([string]$Json) {
    try { $parsed = ConvertFrom-Json $Json } catch { return $Json }
    $items = @($parsed | ForEach-Object { $_ })
    $out = foreach ($i in $items) { Get-CmdItemCanon $i }
    return (@($out) -join "`n")
}

function Get-CmdItemCanon($Item) {
    $f = foreach ($n in 'Type', 'Split', 'Text', 'Path', 'Args', 'WorkingDir', 'Groups', 'FileAction', 'GroupAction', 'Verb', 'WindowSize', 'Icon', 'Children') {
        $v = $null
        if ($null -ne $Item.PSObject.Properties[$n]) { $v = $Item.$n }
        if ($n -eq 'Children') {
            $kids = @(@($v) | Where-Object { $null -ne $_ } | ForEach-Object { Get-CmdItemCanon $_ })
            $v = $(if ($kids.Count -gt 0) { '[' + ($kids -join '|') + ']' } else { '' })
        }
        elseif ($v -is [array]) { $v = ($v -join '|') }
        if ($null -eq $v -or [string]$v -eq '' -or [string]$v -eq '0' -or [string]$v -eq 'False') { $v = '' }
        "$n=$v"
    }
    return ($f -join ';')
}

function Get-RegistryKind([string]$Type) {
    if ($Type -eq 'bool' -or $Type -eq 'int') { return 'DWord' }
    return 'String'
}

function Get-B2Text($Node, [string]$Name) {
    if ($null -eq $Node) { return $null }
    $n = $Node.SelectSingleNode($Name)
    if ($null -eq $n) { return $null }
    return $n.InnerText
}

# ---------------------------------------------------------------------------------------------
# 2048 export reader
# ---------------------------------------------------------------------------------------------

function Read-B2XmlDocument([string]$Path) {
    $full = (Resolve-Path -LiteralPath $Path).ProviderPath
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($full, $settings)
    try {
        $doc = New-Object System.Xml.XmlDocument
        $doc.XmlResolver = $null
        $doc.Load($reader)
    }
    finally { $reader.Close() }
    return $doc
}

function Read-B2Export([System.Xml.XmlDocument]$Doc, [string]$SourceName) {
    $root = $Doc.DocumentElement
    if ($null -eq $root -or $root.Name -ne 'QTTabBar') { throw 'Not a QTTabBar 2048 settings export (root element is not <QTTabBar>).' }
    $cfg = $root.SelectSingleNode('Config')
    if ($null -eq $cfg) { throw 'The export has no <Config> element.' }
    $layout = New-B2Layout
    $blobHex = Get-B2Text $cfg 'Config'
    if ([string]::IsNullOrEmpty($blobHex)) { throw 'The export has no <Config><Config> bit-vector.' }
    $blob = ConvertFrom-Hex $blobHex
    $sections = Read-B2Sections $blob $layout
    $defaults = Read-B2Sections (ConvertFrom-Hex ($script:Data.B2DefaultConfigHex -join '')) $layout

    $keysHex = Get-B2Text $cfg 'KeyboardShortcuts'
    $defKeys = ConvertTo-Int32Array (ConvertFrom-Hex ($script:Data.B2DefaultKeysHex -join ''))
    if ([string]::IsNullOrEmpty($keysHex)) { $keys = $null } else { $keys = ConvertTo-Int32Array (ConvertFrom-Hex $keysHex) }

    $scalars = [ordered]@{}
    foreach ($c in $cfg.ChildNodes) {
        if ($c.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
        if ($c.Name -eq 'Config' -or $c.Name -eq 'KeyboardShortcuts') { continue }
        $scalars[$c.Name] = $c.InnerText
    }

    $bars = [ordered]@{}
    $cb = $root.SelectSingleNode('CommandBar')
    if ($null -ne $cb) {
        foreach ($bar in $cb.ChildNodes) {
            if ($bar.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
            $buttons = New-Object System.Collections.Generic.List[object]
            foreach ($b in $bar.ChildNodes) {
                if ($b.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
                $idText = Get-B2Text $b 'CommandID'
                $id = $null
                if (-not [string]::IsNullOrEmpty($idText)) { $id = [int]::Parse($idText, $script:Inv) }
                $buttons.Add([pscustomobject]@{ Type = $b.GetAttribute('Type'); SubType = $b.GetAttribute('SubType'); CommandID = $id; Text = (Get-B2Text $b 'DisplayText'); Node = $b })
            }
            $bars[$bar.Name] = [pscustomobject]@{ IconSize = $bar.GetAttribute('IconSize'); Buttons = $buttons }
        }
    }

    $mouse = [ordered]@{}
    $inter = $root.SelectSingleNode('Events/Interactive')
    foreach ($src in $script:Data.B2MouseSources) {
        $t = Get-B2Text $inter $src.Name
        if ([string]::IsNullOrEmpty($t)) { continue }
        $arr = ConvertTo-Int32Array (ConvertFrom-Hex $t)
        if ($arr.Length -eq 8) { $mouse[$src.Name] = $arr }
    }

    $groups = @()
    $g = $root.SelectSingleNode('Groups')
    if ($null -ne $g) {
        foreach ($c in $g.ChildNodes) {
            if ($c.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
            $entries = @($c.SelectNodes('Item') | ForEach-Object { [pscustomobject]@{ Type = $_.GetAttribute('Type'); Text = $_.InnerText } })
            $groups += [pscustomobject]@{ Name = $c.GetAttribute('Name'); Items = $entries.Count; Entries = $entries }
        }
    }
    $launchers = 0
    $al = $root.SelectSingleNode('ApplicationLaunchers')
    if ($null -ne $al) { $launchers = @($al.SelectNodes('*')).Count }
    $pluginNodes = @()
    $pl = $root.SelectSingleNode('Plugins')
    if ($null -ne $pl) { foreach ($c in $pl.ChildNodes) { if ($c.NodeType -eq [System.Xml.XmlNodeType]::Element) { $pluginNodes += [pscustomobject]@{ Name = $c.Name; Length = $c.InnerText.Length } } } }

    return [pscustomobject]@{
        Source = $SourceName; SerializedOptions = (Get-B2Text $root 'SerializedOptions')
        Layout = $layout; Sections = $sections; SectionDefaults = $defaults
        Keys = $keys; KeyDefaults = $defKeys; Scalars = $scalars; Bars = $bars; Mouse = $mouse
        Groups = $groups; Launchers = $launchers; Plugins = $pluginNodes
    }
}

# ---------------------------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------------------------

function New-Plan($B2) {
    return [pscustomobject]@{
        B2 = $B2
        Writes = New-Object System.Collections.Generic.List[object]
        UsedSections = @{}
        UsedScalars = @{}
        LostOptions = New-Object System.Collections.Generic.List[object]
        Notes = New-Object System.Collections.Generic.List[string]
        KeyRows = New-Object System.Collections.Generic.List[object]
        KeyLost = New-Object System.Collections.Generic.List[object]
        KeyConflicts = New-Object System.Collections.Generic.List[object]
        KeyWarnings = New-Object System.Collections.Generic.List[string]
        KeyStats = $null
        Buttons = $null
        CmdBars = $null
        GroupPlan = New-Object System.Collections.Generic.List[object]
        Mouse = $null
        Skipped = New-Object System.Collections.Generic.List[object]
    }
}

function Assert-ForkSetting([string]$Category, [string]$Name) {
    if (-not $script:Schema.ContainsKey($Category)) { throw "Refusing to use unknown fork settings category '$Category'." }
    if (-not $script:Schema[$Category].ContainsKey($Name)) { throw "Refusing to use '$Category\$Name': not a property of the fork's Config._$Category." }
    return $script:Schema[$Category][$Name]
}

function Add-Write($Plan, [string]$Category, [string]$Name, $Value, [string]$From, [string]$Note = '') {
    $type = Assert-ForkSetting $Category $Name
    $kind = Get-RegistryKind $type
    $key = "$Category.$Name"
    foreach ($w in $Plan.Writes) { if ($w.Key -eq $key) { throw "Internal error: $key planned twice." } }
    $notes = @()
    if ($Note) { $notes += $Note }
    if ($kind -eq 'DWord') {
        $v = [int]$Value
        if ($type -eq 'bool' -and $v -ne 0 -and $v -ne 1) { throw "Internal error: $key bool value $v." }
        if ($script:Clamps.ContainsKey($key)) {
            $lo = $script:Clamps[$key][0]; $hi = $script:Clamps[$key][1]
            if ($v -lt $lo -or $v -gt $hi) {
                $c = [Math]::Min([Math]::Max($v, $lo), $hi)
                $notes += (Format-Inv 'clamped from {0} to the fork range {1}..{2}' $v $lo $hi)
                $v = $c
            }
        }
        $Value = $v
    }
    else {
        $Value = [string]$Value
        if ($script:Data.ForkEnums.ContainsKey($type)) {
            if ($script:Data.ForkEnums[$type] -notcontains $Value) { throw "Internal error: '$Value' is not a $type member." }
        }
    }
    $Plan.Writes.Add([pscustomobject]@{
        Category = $Category; Name = $Name; Key = $key; Type = $type; Kind = $kind; Value = $Value
        From = $From; Note = ($notes -join '; '); Canonical = (ConvertTo-Canonical $type $Value)
        Current = $null; CurrentKind = $null; CurrentStatus = $null; DefaultStatus = $null; Selected = $true
    })
}

function Get-Sec($Plan, [string]$Name) {
    if (-not $Plan.B2.Sections.ContainsKey($Name)) { throw "Internal error: unknown 2048 section $Name." }
    $Plan.UsedSections[$Name] = $true
    return $Plan.B2.Sections[$Name]
}

# Combo-box sections: Config.SetComboBoxIndex stores the last item (index == MaxValue) as all-ones.
function Get-Combo($Plan, [string]$Name) {
    $raw = Get-Sec $Plan $Name
    $e = $Plan.B2.Layout.Map[$Name]
    if ($raw -eq $e.Mask) { return $e.Max }
    return $raw
}

function Get-Scalar($Plan, [string]$Name) {
    $Plan.UsedScalars[$Name] = $true
    if ($Plan.B2.Scalars.Contains($Name)) { return [string]$Plan.B2.Scalars[$Name] }
    return $null
}

function Get-ScalarInt($Plan, [string]$Name) {
    $s = Get-Scalar $Plan $Name
    if ([string]::IsNullOrEmpty($s)) { return $null }
    $v = 0L
    if ([long]::TryParse($s.Trim(), [System.Globalization.NumberStyles]::Integer, $script:Inv, [ref]$v)) { return $v }
    $Plan.Notes.Add("2048 <$Name> value '$s' is not an integer; ignored.")
    return $null
}

function Get-ScalarBytes($Plan, [string]$Name) {
    $s = Get-Scalar $Plan $Name
    if ([string]::IsNullOrEmpty($s)) { return $null }
    try { return ,(ConvertFrom-Hex $s) } catch { $Plan.Notes.Add("2048 <$Name> is not hex data; ignored."); return $null }
}

function Add-OptionWrites($Plan) {
    foreach ($m in $script:BoolMap) {
        $v = Get-Sec $Plan $m[2]
        Add-Write $Plan $m[0] $m[1] ([int]($v -ne 0)) ("{0}={1}" -f $m[2], $v)
    }

    # Tabs: new tab position / next tab after close (combo: Most right, Most left, Right, Left[, Last activated])
    $pos = @('Rightmost', 'Leftmost', 'Right', 'Left', 'LastActive')
    $v = Get-Combo $Plan 'NewTabLocation'
    if ($v -le 3) { Add-Write $Plan 'Tabs' 'NewTabPosition' $pos[$v] "NewTabLocation=$v" }
    else { $Plan.Notes.Add("NewTabLocation has unexpected value $v; not imported.") }
    $v = Get-Combo $Plan 'NextActiveTab'
    if ($v -le 4) { Add-Write $Plan 'Tabs' 'NextAfterClosed' $pos[$v] "NextActiveTab=$v" }
    else { $Plan.Notes.Add("NextActiveTab has unexpected value $v; not imported.") }

    # Drag hover over a tab (combo: Show Subfolder menu, Activate, none)
    $v = Get-Combo $Plan 'TabDragHoverAction'
    switch ($v) {
        0 { Add-Write $Plan 'Tabs' 'DragOverTabOpensSDT' 1 'TabDragHoverAction=0 (show subfolder menu)' }
        1 { Add-Write $Plan 'Tabs' 'DragOverTabOpensSDT' 0 'TabDragHoverAction=1 (activate tab)' 'approximate: the fork then switches to the tab' }
        default { $Plan.LostOptions.Add([pscustomobject]@{ Item = 'TabDragHoverAction'; Value = "$v (none)"; Reason = 'fork has no "do nothing" choice; fork default kept' }) }
    }

    # Navigation buttons on the tab bar (combo: Right, Left, none)
    $v = Get-Combo $Plan 'ShowNavigationButtons'
    switch ($v) {
        0 { Add-Write $Plan 'Tabs' 'ShowNavButtons' 1 'ShowNavigationButtons=0 (right)'; Add-Write $Plan 'Tabs' 'NavButtonsOnRight' 1 'ShowNavigationButtons=0 (right)' }
        1 { Add-Write $Plan 'Tabs' 'ShowNavButtons' 1 'ShowNavigationButtons=1 (left)'; Add-Write $Plan 'Tabs' 'NavButtonsOnRight' 0 'ShowNavigationButtons=1 (left)' }
        default { Add-Write $Plan 'Tabs' 'ShowNavButtons' 0 'ShowNavigationButtons=none' }
    }

    # Tab rows (combo: multi-row with active row at bottom, multi-row, single)
    $v = Get-Combo $Plan 'MultiRow'
    switch ($v) {
        0 { Add-Write $Plan 'Tabs' 'MultipleTabRows' 1 'MultiRow=0 (multi, active at bottom)'; Add-Write $Plan 'Tabs' 'ActiveTabOnBottomRow' 1 'MultiRow=0 (multi, active at bottom)' }
        1 { Add-Write $Plan 'Tabs' 'MultipleTabRows' 1 'MultiRow=1 (multi-rows)'; Add-Write $Plan 'Tabs' 'ActiveTabOnBottomRow' 0 'MultiRow=1 (multi-rows)' }
        default { Add-Write $Plan 'Tabs' 'MultipleTabRows' 0 'MultiRow=single' }
    }

    # Tweaks: "No full-row-select" only applied to 2048's compatible list view style
    $vista = Get-Sec $Plan 'ViewVistaLayout'
    $nofull = Get-Sec $Plan 'ViewNoFullRowSelect'
    $tf = [int](($vista -ne 0) -and ($nofull -ne 0))
    Add-Write $Plan 'Tweaks' 'ToggleFullRowSelect' $tf ("ViewVistaLayout={0}, ViewNoFullRowSelect={1}" -f $vista, $nofull) 'approximate: 2048 option belongs to its compatible list view (only taken when that was on)'

    # Tips
    $v = Get-Sec $Plan 'Preview'
    Add-Write $Plan 'Tips' 'ShowTooltipPreviews' ([int]($v -gt 0)) "Preview=$v"
    $v = Get-Sec $Plan 'SubDirTip'
    Add-Write $Plan 'Tips' 'ShowSubDirTips' ([int]($v -gt 0)) "SubDirTip=$v"
    if ($v -gt 0) { Add-Write $Plan 'Tips' 'SubDirTipsWithShift' ([int]($v -ge 2)) "SubDirTip=$v (2 = only with Shift)" }
    $w = Get-ScalarInt $Plan 'PreviewMaxWidth'
    if ($null -ne $w) { Add-Write $Plan 'Tips' 'PreviewMaxWidth' $w "PreviewMaxWidth=$w" 'picture preview size' }
    $h = Get-ScalarInt $Plan 'PreviewMaxHeight'
    if ($null -ne $h) { Add-Write $Plan 'Tips' 'PreviewMaxHeight' $h "PreviewMaxHeight=$h" 'picture preview size' }
    Add-FontWrite $Plan 'Tips' 'PreviewFont' 'PreviewFont' 'PreviewFontSize' 'PreviewFontStyle'

    # Misc
    $v = Get-Sec $Plan 'SaveRecentFile'
    Add-Write $Plan 'Misc' 'KeepRecentFiles' ([int]($v -gt 0)) "SaveRecentFile=$v"
    $n = Get-ScalarInt $Plan 'RecentTabMax'
    if ($null -ne $n) { Add-Write $Plan 'Misc' 'TabHistoryCount' $n "RecentTabMax=$n" }
    $n = Get-ScalarInt $Plan 'RecentFileMax'
    if ($null -ne $n) { Add-Write $Plan 'Misc' 'FileHistoryCount' $n "RecentFileMax=$n" }

    Add-SkinWrites $Plan
    Add-ButtonBarWrites $Plan
    Add-DesktopOrderWrites $Plan
}

function Add-FontWrite($Plan, [string]$Category, [string]$Name, [string]$NameEl, [string]$SizeEl, [string]$StyleEl) {
    $fname = Get-Scalar $Plan $NameEl
    $fsize = Get-Scalar $Plan $SizeEl
    $fstyle = Get-ScalarInt $Plan $StyleEl
    $notes = @()
    if ([string]::IsNullOrEmpty($fname)) {
        $fname = $script:EffectiveDefaultFont
        $notes += "2048 <$NameEl> empty: 2048 default font assumed ($fname)"
    }
    $size = [single]9
    if (-not [string]::IsNullOrEmpty($fsize)) {
        $tmp = [single]0
        if ([single]::TryParse($fsize.Trim(), [System.Globalization.NumberStyles]::Float, $script:Inv, [ref]$tmp) -and $tmp -gt 0) { $size = $tmp }
    }
    else { $notes += '2048 size empty: 9pt' }
    $style = 0
    if ($null -ne $fstyle) { $style = [int]($fstyle -band 15) }
    $json = New-FontJson $fname $size $style
    Add-Write $Plan $Category $Name $json ("{0}='{1}' {2}pt style {3}" -f $NameEl, $fname, $size.ToString('R', $script:Inv), $style) ($notes -join '; ')
}

function Add-ColorWrite($Plan, [string]$Category, [string]$Name, [string]$Element, [string]$Note = '') {
    $v = Get-ScalarInt $Plan $Element
    if ($null -eq $v) { return $null }
    $u = ConvertTo-UInt32Argb $v
    $n = $Note
    if (($u -shr 24) -eq 0) { $n = (@($Note, 'alpha is 0 (transparent) in the export') | Where-Object { $_ }) -join '; ' }
    Add-Write $Plan $Category $Name (New-ColorJson $v) ("{0}={1} ({2})" -f $Element, $v, (Format-Argb $v)) $n
    return $u
}

function Add-SkinWrites($Plan) {
    # Tab rendering (combo: Visual Style/GDI, Visual Style/GDI+, Skin, Classic -> stored 0,3,1,2)
    $mode = Get-Sec $Plan 'TabRenderingMode'
    $modeName = @{ 0 = 'visual style (GDI)'; 1 = 'skin'; 2 = 'classic'; 3 = 'visual style (GDI+)' }[$mode]
    Add-Write $Plan 'Skin' 'UseTabSkin' ([int]($mode -eq 1)) "TabRenderingMode=$mode ($modeName)"
    $img = Get-Scalar $Plan 'TabImage'
    if (-not [string]::IsNullOrEmpty($img)) {
        $note = 'same 3-slice layout as 2048 (top to bottom: active, normal, hot)'
        if (-not (Test-Path -LiteralPath $img -PathType Leaf)) { $note = 'FILE NOT FOUND on this machine (the fork resets a missing path to empty); ' + $note }
        Add-Write $Plan 'Skin' 'TabImageFile' $img 'TabImage' $note
    }
    elseif ($mode -eq 1) { $Plan.Notes.Add('2048 tab skin mode is on but <TabImage> is empty; the fork needs Skin\TabImageFile for its skin.') }
    $m = Get-ScalarBytes $Plan 'TabImageSizingMargin'
    if ($null -ne $m -and $m.Length -eq 4) {
        $p = @($m | ForEach-Object { [Math]::Min([int]$_, 99) })
        Add-Write $Plan 'Skin' 'TabSizeMargin' (New-PaddingJson $p[0] $p[1] $p[2] $p[3]) ("TabImageSizingMargin={0},{1},{2},{3}" -f $m[0], $m[1], $m[2], $m[3]) 'bytes = left,top,right,bottom (as 2048 reads them)'
    }
    $padOn = Get-Sec $Plan 'TabPaddingEnabled'
    $tp = Get-ScalarBytes $Plan 'TabPadding'
    if ($padOn -ne 0 -and $null -ne $tp -and $tp.Length -eq 16) {
        $ints = ConvertTo-Int32Array $tp
        $l = [Math]::Min([Math]::Max($ints[0], 0), 99); $r = [Math]::Min([Math]::Max($ints[2], 0), 99)
        Add-Write $Plan 'Skin' 'TabContentMargin' (New-PaddingJson $l 0 $r 0) ("TabPadding left={0} right={1} (enabled)" -f $ints[0], $ints[2]) 'approximate'
    }

    # Tab size (combo: Auto, Fixed, Limit tab width)
    $sz = Get-Combo $Plan 'TabSizeAuto'
    $height = Get-ScalarInt $Plan 'TabHeight'
    if ($null -ne $height) { Add-Write $Plan 'Skin' 'TabHeight' $height "TabHeight=$height" }
    $wFixed = Get-ScalarInt $Plan 'TabWidth'
    $wMax = Get-ScalarInt $Plan 'TabWidthMax'
    $wMin = Get-ScalarInt $Plan 'TabWidthMin'
    if ($sz -eq 1) {
        Add-Write $Plan 'Skin' 'FixedWidthTabs' 1 'TabSizeAuto=1 (fixed)'
        if ($null -ne $wFixed) { Add-Write $Plan 'Skin' 'TabMaxWidth' $wFixed "TabWidth=$wFixed (fixed width)" 'the fork uses TabMaxWidth as the fixed tab width' }
        if ($null -ne $wMin) { Add-Write $Plan 'Skin' 'TabMinWidth' $wMin "TabWidthMin=$wMin" }
    }
    else {
        $label = @{ 0 = 'auto'; 2 = 'limited' }[$sz]
        $note = ''
        if ($sz -eq 0) { $note = 'approximate: the fork always limits tab width to TabMinWidth..TabMaxWidth' }
        Add-Write $Plan 'Skin' 'FixedWidthTabs' 0 "TabSizeAuto=$sz ($label)" $note
        if ($null -ne $wMin) { Add-Write $Plan 'Skin' 'TabMinWidth' $wMin "TabWidthMin=$wMin" }
        if ($null -ne $wMax) { Add-Write $Plan 'Skin' 'TabMaxWidth' $wMax "TabWidthMax=$wMax" }
    }
    $minW = $null; $maxW = $null
    foreach ($w in $Plan.Writes) { if ($w.Key -eq 'Skin.TabMinWidth') { $minW = $w.Value }; if ($w.Key -eq 'Skin.TabMaxWidth') { $maxW = $w.Value } }
    if ($null -ne $minW -and $null -ne $maxW -and $maxW -lt $minW) { $Plan.Notes.Add("Tab width: TabMaxWidth ($maxW) < TabMinWidth ($minW) after clamping; the fork then ignores both values.") }

    Add-FontWrite $Plan 'Skin' 'TabTextFont' 'TabFont' 'TabFontSize' 'TabFontStyle'
    $act = Get-ScalarInt $Plan 'TabFontStyleActive'
    [void](Get-Sec $Plan 'TabTextBoldActive')   # legacy 2048 section, not used by 2048 itself
    if ($null -ne $act) {
        $note = ''
        if (($act -band 14) -ne 0) { $note = 'italic/underline/strikeout for the active tab are not supported by the fork' }
        Add-Write $Plan 'Skin' 'ActiveTabInBold' ([int](($act -band 1) -ne 0)) "TabFontStyleActive=$act" $note
    }
    $v = Get-Sec $Plan 'TabTextAlign'
    Add-Write $Plan 'Skin' 'TabTextCentered' ([int]($v -ne 0)) ("TabTextAlign={0} ({1})" -f $v, $(if ($v -ne 0) { 'centered' } else { 'left' }))

    # Colours
    $colorCount = 0
    if ($null -ne (Add-ColorWrite $Plan 'Skin' 'TabTextActiveColor' 'ColorActive')) { $colorCount++ }
    if ($null -ne (Add-ColorWrite $Plan 'Skin' 'TabTextInactiveColor' 'ColorInactive')) { $colorCount++ }
    if ($null -ne (Add-ColorWrite $Plan 'Skin' 'TabTextHotColor' 'ColorHighlightClassic' 'the fork uses this colour only for the classic-mode underline of the active tab')) { $colorCount++ }
    if ($null -ne (Add-ColorWrite $Plan 'Skin' 'TabShadActiveColor' 'ColorShadowActive' 'the fork also fills non-skinned active tabs with it in dark mode')) { $colorCount++ }
    if ($null -ne (Add-ColorWrite $Plan 'Skin' 'TabShadInactiveColor' 'ColorShadowInacitve')) { $colorCount++ }
    $rebar = Add-ColorWrite $Plan 'Skin' 'RebarColor' 'ColorToolbarBackground'
    if ($null -ne $rebar) { $colorCount++ }
    if ($colorCount -gt 0) {
        Add-Write $Plan 'Skin' 'SkinAutoColorChangeClose' 1 '(derived)' 'otherwise the fork replaces the imported colours with its light/dark preset whenever an Explorer window opens ("Close Auto Color")'
        $useBg = $Plan.B2.Sections['RebarBackgroundColor'] -ne 0
        if ($useBg -and $null -ne $rebar) { $dark = (Get-Luminance $rebar) -lt 0.5; $why = 'toolbar background ' + (Format-Argb $rebar) }
        else { $dark = Test-SystemDarkMode; $why = 'Windows app theme on this machine' }
        $txt = $(if ($dark) { 4294967295 } else { 4278190080 })
        Add-Write $Plan 'Skin' 'ToolBarTextColor' (New-ColorJson $txt) ("(derived from {0})" -f $why) '2048 has no button-bar text colour; chosen for contrast because auto colouring is switched off'
    }

    # Toolbar background image (combo: Tile, Real size, Stretch, Stretch on each band)
    $bg = Get-Scalar $Plan 'ToolbarBGImage'
    if (-not [string]::IsNullOrEmpty($bg)) {
        $note = ''
        if (-not (Test-Path -LiteralPath $bg -PathType Leaf)) { $note = 'FILE NOT FOUND on this machine' }
        Add-Write $Plan 'Skin' 'RebarImageFile' $bg 'ToolbarBGImage' $note
    }
    $v = Get-Combo $Plan 'RebarBackgroundImageMode'
    $stretch = @('Tile', 'Real', 'Full', 'Full')[[Math]::Min($v, 3)]
    Add-Write $Plan 'Skin' 'RebarStretchMode' $stretch "RebarBackgroundImageMode=$v"
    Add-Write $Plan 'Skin' 'RebarImageSeperateBars' ([int]($v -eq 3)) "RebarBackgroundImageMode=$v (3 = stretch on each band)"

    # Explorer bar backgrounds: 2048 paints a custom colour; the fork's flag forces SystemColors.Window.
    foreach ($pair in @(@('DrawVerticalExplorerBarBgColor', 'ColorVerticalBarBackground'), @('DrawHorizontalExplorerBarBgColor', 'ColorHorizontalBarBackground'))) {
        $flag = Get-Sec $Plan $pair[0]
        $c = Get-ScalarInt $Plan $pair[1]
        $val = 0; $from = "{0}={1}" -f $pair[0], $flag
        if ($null -ne $c) { $from += (' ' + $pair[1] + '=' + (Format-Argb $c)) }
        if ($flag -ne 0 -and $null -ne $c -and (Get-Luminance $c) -ge 0.5) { $val = 1 }
        Add-Write $Plan 'Skin' $pair[0] $val $from 'fork flag paints the system window colour (light); set only when the 2048 colour was light; custom colour not supported'
    }
}

function Test-SystemDarkMode {
    try {
        $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', $false)
        if ($null -eq $k) { return $false }
        try { $v = $k.GetValue('AppsUseLightTheme', 1) } finally { $k.Close() }
        return ([int]$v -eq 0)
    }
    catch { return $false }
}

function Add-ButtonBarWrites($Plan) {
    # 2048 (CommandControl.MakeItemDisplayStyle): a button shows its label only when the bar allows
    # labels (section = 0) AND the button's own LabelVisibility is set; otherwise icon only.
    $label = Get-Sec $Plan 'CommandBar_ShowTextLabel'
    if ($Plan.B2.Bars.Contains('CommandBar1st')) {
        $withLabel = @($Plan.B2.Bars['CommandBar1st'].Buttons | Where-Object { $null -ne $_.Node -and (Get-B2Text $_.Node 'LabelVisibility') -eq 'true' }).Count
        Add-Write $Plan 'BBar' 'ShowButtonLabels' ([int]($label -eq 0 -and $withLabel -gt 0)) ("CommandBar_ShowTextLabel={0}; {1} buttons with a label" -f $label, $withLabel) 'fork: one setting for the whole bar'
    }
    else {
        Add-Write $Plan 'BBar' 'ShowButtonLabels' ([int]($label -eq 0)) ("CommandBar_ShowTextLabel={0} (0 = labels shown)" -f $label)
    }
    Add-ImageStripWrite $Plan
    $info = [pscustomobject]@{ Mapped = New-Object System.Collections.Generic.List[object]; Lost = New-Object System.Collections.Generic.List[object]; OtherBars = New-Object System.Collections.Generic.List[object]; IconSize = $null }
    $Plan.Buttons = $info
    if (-not $Plan.B2.Bars.Contains('CommandBar1st')) {
        $Plan.Notes.Add('The export has no CommandBar1st; button bar layout not imported.')
        return
    }
    $bar = $Plan.B2.Bars['CommandBar1st']
    $idx = New-Object System.Collections.Generic.List[int]
    $pos = 0
    foreach ($b in $bar.Buttons) {
        $pos++
        if ($b.Type -eq 'BuiltIn' -and $null -ne $b.CommandID -and $script:ButtonMap.ContainsKey([int]$b.CommandID)) {
            $id = [int]$b.CommandID
            $f = $script:ButtonMap[$id]
            $name = $script:Data.B2CommandIds[$id]
            if ($f -ge 0) { $idx.Add($f); $info.Mapped.Add([pscustomobject]@{ Pos = $pos; B2 = "$name ($id)"; Fork = "$($script:ForkButtonNames[$f]) ($f)" }) }
            else { $info.Lost.Add([pscustomobject]@{ Pos = $pos; B2 = "$name ($id)"; Reason = 'no fork button' }) }
        }
        else {
            $what = $b.Type
            if ($null -ne $b.CommandID) { $what += " $($b.CommandID)" }
            $info.Lost.Add([pscustomobject]@{ Pos = $pos; B2 = $what; Reason = 'only 2048 built-in buttons have fork equivalents' })
        }
    }
    $json = '[' + (($idx | ForEach-Object { $_.ToString($script:Inv) }) -join ',') + ']'
    Add-Write $Plan 'BBar' 'ButtonIndexes' $json ("CommandBar1st ({0} buttons)" -f $bar.Buttons.Count) ("{0} of {1} buttons mapped" -f $idx.Count, $bar.Buttons.Count)
    $size = 0
    $info.IconSize = $bar.IconSize
    if ([int]::TryParse([string]$bar.IconSize, [ref]$size) -and $size -gt 0) {
        Add-Write $Plan 'BBar' 'LargeButtons' ([int]($size -ge 24)) "CommandBarIconSize1st/IconSize=$size" 'fork: small = 16 px, large = 24 px'
    }
    [void](Get-Scalar $Plan 'CommandBarIconSize1st')
    foreach ($k in @($Plan.B2.Bars.get_Keys())) {
        if ($script:ImportedBars -contains $k -or $Plan.B2.Bars[$k].Buttons.Count -eq 0) { continue }
        $types = @($Plan.B2.Bars[$k].Buttons | Group-Object Type | Sort-Object Name | ForEach-Object { "$($_.Count) x $($_.Name)" })
        $info.OtherBars.Add([pscustomobject]@{ Bar = $k; Count = $Plan.B2.Bars[$k].Buttons.Count; Types = ($types -join ', ') })
    }
}

# Size of an image file (header only), $null when it can't be read.
function Get-ImageSize([string]$Path) {
    if ($null -eq $script:DrawingLoaded) {
        try { Add-Type -AssemblyName System.Drawing; $script:DrawingLoaded = $true } catch { $script:DrawingLoaded = $false }
    }
    if (-not $script:DrawingLoaded) { return $null }
    $fs = $null
    try {
        $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $img = [System.Drawing.Image]::FromStream($fs, $false, $false)
        try { return [pscustomobject]@{ Width = $img.Width; Height = $img.Height } } finally { $img.Dispose() }
    }
    catch { return $null }
    finally { if ($null -ne $fs) { $fs.Dispose() } }
}

# <CommandBarImagePath> ("Image file for Basic commands") -> BBar.ImageStripPath. The fork reads
# 2048's legacy strips (40 px high, 432..528 px wide) and its own (>= 504 x 24); 2048's single-row
# strips (21/22 square cells of 32..256 px) are not supported.
function Add-ImageStripWrite($Plan) {
    $path = Get-Scalar $Plan 'CommandBarImagePath'
    if ([string]::IsNullOrEmpty($path)) { return }
    $full = [Environment]::ExpandEnvironmentVariables($path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $Plan.LostOptions.Add([pscustomobject]@{ Item = 'CommandBarImagePath'; Value = $path; Reason = 'file not found on this machine (copy it here and run the import again, or pick it in Options > Button bar)' })
        return
    }
    $size = Get-ImageSize $full
    if ($null -eq $size) {
        $Plan.LostOptions.Add([pscustomobject]@{ Item = 'CommandBarImagePath'; Value = $path; Reason = 'not a readable image' })
        return
    }
    $legacy = ($size.Height -eq 40 -and $size.Width -ge 432)
    $fork = ($size.Width -ge 504 -and $size.Height -ge 24 -and -not $legacy)
    if (-not ($legacy -or $fork)) {
        $Plan.LostOptions.Add([pscustomobject]@{ Item = 'CommandBarImagePath'; Value = $path; Reason = (Format-Inv '{0}x{1} image: the fork reads 2048 legacy strips (40 px high, 432-528 px wide) and its own (504x24)' $size.Width $size.Height) })
        return
    }
    $kind = $(if ($legacy) { (Format-Inv '2048 legacy strip {0}x{1}, {2} icons' $size.Width $size.Height ([int][Math]::Floor($size.Width / 24))) } else { (Format-Inv 'fork-format strip {0}x{1}' $size.Width $size.Height) })
    Add-Write $Plan 'BBar' 'ImageStripPath' $path 'CommandBarImagePath' $kind
}

# ---------------------------------------------------------------------------------------------
# Second / vertical command bars, command button clicks, groups
# ---------------------------------------------------------------------------------------------

$script:ImportedBars = @('CommandBar1st', 'CommandBar2nd', 'CommandBarVertical')
# Events/Interactive sources imported into CmdBars (the other mouse sources are report-only).
$script:ImportedMouseSources = @('CommandButtonClick', 'CommandButtonMiddleClick')

# 2048 FileAction names -> fork CommandBarFileAction. 2048's view-targeted actions (6..14) have no
# fork counterpart and fall back to Default.
$script:B2FileActions = @{ 'Default' = 0; 'NewTab' = 1; 'NewTabBackground' = 2; 'InPlace' = 3; 'NewWindow' = 4; 'ShellExecute' = 5 }
# 2048 GroupAction names -> fork CommandBarGroupAction. 2048's export writes GroupAction with the
# FileAction enum's names, so Background/NewWindow/Replace arrive as NewTab/NewTabBackground/InPlace.
$script:B2GroupActions = @{ 'Default' = 0; 'Background' = 1; 'NewWindow' = 2; 'Replace' = 3; 'NewTab' = 1; 'NewTabBackground' = 2; 'InPlace' = 3 }

$script:PidlHelperSource = @'
using System;
using System.Runtime.InteropServices;
namespace QT2048Import {
    public static class Pidl {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern int SHGetNameFromIDList(IntPtr pidl, uint sigdnName, out IntPtr ppszName);
        // SIGDN_DESKTOPABSOLUTEPARSING: "C:\x", "::{CLSID}\...", the form the fork stores.
        public static string ParsingName(byte[] idl) {
            IntPtr p = Marshal.AllocCoTaskMem(idl.Length);
            try {
                Marshal.Copy(idl, 0, p, idl.Length);
                IntPtr name;
                if (SHGetNameFromIDList(p, 0x80028000, out name) != 0 || name == IntPtr.Zero) return null;
                try { return Marshal.PtrToStringUni(name); }
                finally { Marshal.FreeCoTaskMem(name); }
            }
            finally { Marshal.FreeCoTaskMem(p); }
        }
    }
}
'@
$script:PidlHelperLoaded = $null

# An absolute ITEMIDLIST: SHITEMIDs (2-byte size + data) ending with a zero size, all inside the data.
function Test-B2Pidl([byte[]]$Bytes) {
    $pos = 0
    while ($true) {
        if ($pos + 2 -gt $Bytes.Length) { return $false }
        $cb = [int]$Bytes[$pos] + 256 * [int]$Bytes[$pos + 1]
        if ($cb -eq 0) { return $true }
        if ($cb -lt 2 -or $pos + $cb -gt $Bytes.Length) { return $false }
        $pos += $cb
    }
}

# 2048 <IDL> / group <Item Type="IDL"> hex -> shell parsing name, $null when malformed or unresolvable.
# The PIDL is only handed to SHGetNameFromIDList on this machine (read-only).
function ConvertFrom-B2Pidl([string]$Hex) {
    if ([string]::IsNullOrEmpty($Hex)) { return $null }
    try { $bytes = ConvertFrom-Hex $Hex } catch { return $null }
    if (-not (Test-B2Pidl $bytes)) { return $null }
    if ($null -eq $script:PidlHelperLoaded) {
        try { Add-Type -TypeDefinition $script:PidlHelperSource -ErrorAction Stop; $script:PidlHelperLoaded = $true } catch { $script:PidlHelperLoaded = $false }
    }
    if (-not $script:PidlHelperLoaded) { return $null }
    try { return [QT2048Import.Pidl]::ParsingName($bytes) } catch { return $null }
}

# One CommandBarItem as DataContractJsonSerializer reads it (members left out keep their defaults).
function New-CmdItemJson($Item) {
    $p = New-Object System.Collections.Generic.List[string]
    # Indexing (not .Name): Set-StrictMode refuses missing hashtable keys as properties.
    $p.Add('"Type":' + ([int]$Item['Type']).ToString($script:Inv))
    $p.Add('"Split":' + $(if ($Item['Split']) { 'true' } else { 'false' }))
    foreach ($n in 'Text', 'Path', 'Args', 'WorkingDir') { if ($Item[$n]) { $p.Add('"' + $n + '":' + (ConvertTo-JsonText $Item[$n])) } }
    if ($Item['Groups']) { $p.Add('"Groups":[' + ((@($Item['Groups']) | ForEach-Object { ConvertTo-JsonText $_ }) -join ',') + ']') }
    foreach ($n in 'FileAction', 'GroupAction') { if ([int]$Item[$n] -ne 0) { $p.Add('"' + $n + '":' + ([int]$Item[$n]).ToString($script:Inv)) } }
    if ($Item['Verb']) { $p.Add('"Verb":' + (ConvertTo-JsonText $Item['Verb'])) }
    if ([int]$Item['WindowSize'] -ne 0) { $p.Add('"WindowSize":' + ([int]$Item['WindowSize']).ToString($script:Inv)) }
    if ($Item['Icon']) { $p.Add('"Icon":' + (ConvertTo-JsonText $Item['Icon'])) }
    if ($Item['ChildrenJson']) { $p.Add('"Children":' + $Item['ChildrenJson']) }
    return '{' + ($p -join ',') + '}'
}

# A 2048 <CommandButton> -> fork command bar item. Returns Ok/Json/Label/Summary/Notes, or Ok=$false
# with a Reason.
function ConvertFrom-B2CommandButton($Node) {
    $type = $Node.GetAttribute('Type')
    $sub = $Node.GetAttribute('SubType')
    $text = Get-B2Text $Node 'DisplayText'
    $notes = New-Object System.Collections.Generic.List[string]
    $item = @{ Type = 0; Split = ($sub -eq 'Split' -or $sub -eq 'DropDown'); Text = $text; Path = $null; Args = $null; WorkingDir = $null; Groups = $null; FileAction = 0; GroupAction = 0; Verb = $null; WindowSize = 0; Icon = $null; ChildrenJson = $null }
    if ($sub -eq 'DropDown') { $notes.Add('drop-down button: imported as a split button') }
    $childNodes = @($Node.SelectNodes('SubItems/CommandButton'))
    # IconResource: '"file", index' (an icon resource) or the path of an image file.
    $iconRes = Get-B2Text $Node 'IconResource'
    if ($iconRes) {
        $m = [regex]::Match($iconRes, '^\s*"?([^",]+?)"?\s*,\s*(-?\d+)\s*$')
        $item.Icon = $(if ($m.Success) { $m.Groups[1].Value + ',' + $m.Groups[2].Value } else { $iconRes.Trim().Trim('"') })
    }
    if ((Get-B2Text $Node 'KeyboardShortcut') -match '^-?[1-9]') { $notes.Add('button hotkey not imported') }
    if ((Get-B2Text $Node 'NoImage') -eq 'true') { $notes.Add('text-only in 2048; the fork shows the icon') }
    $label = ((Get-B2Text $Node 'LabelVisibility') -eq 'true')
    $fail = { param($r) [pscustomobject]@{ Ok = $false; Reason = $r; Notes = $notes } }
    switch ($type) {
        'BuiltIn' {
            $id = Get-B2Text $Node 'CommandID'
            if ([string]::IsNullOrEmpty($id) -or $id -eq '0') {
                return [pscustomobject]@{ Ok = $true; Json = (New-CmdItemJson @{ Type = 2; Split = $false }); Label = $false; Summary = 'separator'; Notes = $notes }
            }
            $name = $id
            $n = 0
            if ([int]::TryParse($id, [ref]$n) -and $n -ge 0 -and $n -lt $script:Data.B2CommandIds.Count) { $name = "$($script:Data.B2CommandIds[$n]) ($n)" }
            return (& $fail "2048 basic command $name - use the first button bar for built-in buttons")
        }
        'File' {
            $path = Get-B2Text $Node 'Path'
            if ([string]::IsNullOrEmpty($path)) {
                $path = ConvertFrom-B2Pidl (Get-B2Text $Node 'IDL')
                if ($path) { $notes.Add('target taken from the PIDL') }
            }
            if ([string]::IsNullOrEmpty($path)) { return (& $fail 'target cannot be resolved (no Path, PIDL unreadable on this machine)') }
            $item.Path = $path
            $argItems = @($Node.SelectNodes('Args/Item') | ForEach-Object { $_.InnerText })
            if ($argItems.Count -gt 0) { $item.Args = $argItems[0] }
            if ($argItems.Count -gt 1) { $item.WorkingDir = $argItems[1] }
            $fa = Get-B2Text $Node 'FileAction'
            if ($fa) {
                if ($script:B2FileActions.ContainsKey($fa)) { $item.FileAction = $script:B2FileActions[$fa] }
                else { $notes.Add("FileAction $fa has no fork equivalent (Default used)") }
            }
            $verb = Get-B2Text $Node 'Verb'
            if ($verb) { $item.Verb = $verb }
            $opt = Get-B2Text $Node 'Options'
            if ($opt) {
                try {
                    $ob = ConvertFrom-Hex $opt
                    if ($ob.Length -gt 12 -and $ob[12] -le 3) { $item.WindowSize = [int]$ob[12] }
                    if ($ob.Length -gt 11 -and $ob[11] -gt 1) { $notes.Add('associated Extra View not imported (opens in the current view)') }
                }
                catch { $notes.Add('Options not readable') }
            }
            $summary = "File '$text' -> $path"
            if ($item.Args) { $summary += " args '$($item.Args)'" }
            if ($item.WorkingDir) { $summary += " dir '$($item.WorkingDir)'" }
            if ($item.Verb) { $summary += " verb $($item.Verb)" }
        }
        'Group' {
            $groups = @($Node.SelectNodes('Groups/Group') | ForEach-Object { $_.InnerText } | Where-Object { $_ })
            if ($groups.Count -eq 0) {
                $legacy = Get-B2Text $Node 'GroupName'
                if ($legacy) { $groups = @($legacy) }
            }
            if ($groups.Count -eq 0) { return (& $fail 'group button without group names') }
            $item.Type = 1
            $item.Groups = $groups
            $ga = Get-B2Text $Node 'GroupAction'
            if ($ga) {
                if ($script:B2GroupActions.ContainsKey($ga)) { $item.GroupAction = $script:B2GroupActions[$ga] }
                else { $notes.Add("GroupAction $ga unknown (Default used)") }
            }
            $summary = "Group '" + ($groups -join ', ') + "'"
        }
        'ScriptingCommand' {
            # 104 = NoOp: 2048's "virtual folder", a container for child items.
            if ((Get-B2Text $Node 'CommandID') -ne '104') { return (& $fail "2048 advanced (script) command $(Get-B2Text $Node 'CommandID') has no fork equivalent") }
            $item.Type = 3
            $item.Split = $false
            if (-not $item.Text) { $item.Text = 'Virtual folder' }
            $summary = "Menu '$($item.Text)'"
        }
        default { return (& $fail "$type commands have no fork equivalent") }
    }
    if ($item.Split) { $summary += ' [split]' }
    if ($childNodes.Count -gt 0) {
        $kids = New-Object System.Collections.Generic.List[string]
        foreach ($c in $childNodes) {
            $r = ConvertFrom-B2CommandButton $c
            if ($r.Ok) { $kids.Add($r.Json) } else { $notes.Add("child item not imported: $($r.Reason)") }
        }
        if ($kids.Count -gt 0) { $item.ChildrenJson = '[' + ($kids -join ',') + ']'; $summary += " + $($kids.Count) child items" }
    }
    return [pscustomobject]@{ Ok = $true; Json = (New-CmdItemJson $item); Label = $label; Summary = $summary; Notes = $notes }
}

function Add-CommandBarWrites($Plan) {
    $info = [pscustomobject]@{ Bars = New-Object System.Collections.Generic.List[object] }
    $Plan.CmdBars = $info
    foreach ($def in @(@('CommandBar2nd', 'SecondBar', 'CommandBar_ShowTextLabel2nd', 'CommandBarIconSize2nd'),
                       @('CommandBarVertical', 'VerticalBar', 'CommandBar_ShowTextLabelVrt', 'CommandBarIconSizeVrt'))) {
        $b2Name = $def[0]; $fork = $def[1]
        $labelSec = Get-Sec $Plan $def[2]
        [void](Get-Scalar $Plan $def[3])
        if (-not $Plan.B2.Bars.Contains($b2Name)) { continue }
        $bar = $Plan.B2.Bars[$b2Name]
        $rows = New-Object System.Collections.Generic.List[object]
        $jsons = New-Object System.Collections.Generic.List[string]
        $anyLabel = $false
        $pos = 0
        foreach ($b in $bar.Buttons) {
            $pos++
            $r = ConvertFrom-B2CommandButton $b.Node
            $rows.Add([pscustomobject]@{ Pos = $pos; Result = $r })
            if ($r.Ok) { $jsons.Add($r.Json); if ($r.Label) { $anyLabel = $true } }
        }
        Add-Write $Plan 'CmdBars' "${fork}Items" ('[' + ($jsons -join ',') + ']') ("{0} ({1} buttons)" -f $b2Name, $bar.Buttons.Count) ("{0} of {1} buttons imported" -f $jsons.Count, $bar.Buttons.Count)
        $size = 0
        if ([int]::TryParse([string]$bar.IconSize, [ref]$size) -and $size -gt 0) {
            Add-Write $Plan 'CmdBars' "${fork}IconSize" $size "$b2Name IconSize=$size"
        }
        # 2048: a button shows its label when its LabelVisibility is set, unless the bar hides labels.
        Add-Write $Plan 'CmdBars' "${fork}ShowLabels" ([int]($anyLabel -and $labelSec -eq 0)) (Format-Inv '{0}: button labels {1}; {2}={3}' $b2Name $(if ($anyLabel) { 'on' } else { 'off' }) $def[2] $labelSec) 'fork: one setting per bar'
        $info.Bars.Add([pscustomobject]@{ Bar = $b2Name; Fork = $fork; IconSize = $bar.IconSize; Rows = $rows; Imported = $jsons.Count })
    }
    $v = Get-Sec $Plan 'CommandBar_VerticalEnabled'
    Add-Write $Plan 'CmdBars' 'VerticalBarVisible' ([int]($v -ne 0)) "CommandBar_VerticalEnabled=$v"
    foreach ($pair in @(@('CommandButtonClick', 'ClickActions'), @('CommandButtonMiddleClick', 'MiddleClickActions'))) {
        if (-not $Plan.B2.Mouse.Contains($pair[0])) { continue }
        $vals = @($Plan.B2.Mouse[$pair[0]])
        $note = 'index = Ctrl 1 | Shift 2 | Alt 4; 2048''s Extra View actions act on the current view'
        $bad = @($vals | Where-Object { $_ -lt -1 -or $_ -gt 15 })
        if ($bad.Count -gt 0) {
            $vals = @($vals | ForEach-Object { if ($_ -lt -1 -or $_ -gt 15) { -1 } else { $_ } })
            $note += '; unknown values set to -1 (nothing)'
        }
        Add-Write $Plan 'CmdBars' $pair[1] ('[' + (($vals | ForEach-Object { ([int]$_).ToString($script:Inv) }) -join ',') + ']') "Events/Interactive/$($pair[0])" $note
    }
}

# Names of the fork's groups (HKCU\Software\QTTabBar\Groups\<n>, read-only).
function Get-ForkGroupNames {
    $names = New-Object System.Collections.Generic.List[string]
    $k = $null
    try { $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("$script:RegRoot\Groups", $false) } catch { $k = $null }
    if ($null -eq $k) { return ,$names }
    try {
        $i = 0
        while ($true) {
            $gk = $k.OpenSubKey($i.ToString($script:Inv), $false)
            if ($null -eq $gk) { break }
            try { $n = $gk.GetValue(''); if ($n -is [string]) { $names.Add($n) } } finally { $gk.Close() }
            $i++
        }
    }
    finally { $k.Close() }
    return ,$names
}

# 2048 groups (folder PIDLs) -> fork groups (parsing names). Groups whose name already exists in
# the fork are left alone; the others are appended.
function Add-GroupWrites($Plan) {
    $existing = Get-ForkGroupNames
    foreach ($g in @($Plan.B2.Groups)) {
        $paths = New-Object System.Collections.Generic.List[string]
        $lost = 0
        foreach ($e in @($g.Entries)) {
            $p = $null
            if ($e.Type -eq 'IDL') { $p = ConvertFrom-B2Pidl $e.Text } elseif ($e.Text) { $p = $e.Text }
            if ($p) { $paths.Add($p) } else { $lost++ }
        }
        if ([string]::IsNullOrEmpty($g.Name)) { $status = 'skipped: no name' }
        elseif ($existing -contains $g.Name) { $status = 'exists: kept as is' }
        elseif ($paths.Count -eq 0) { $status = 'skipped: no folder could be resolved' }
        else { $status = 'add' }
        $Plan.GroupPlan.Add([pscustomobject]@{ Name = $g.Name; Paths = $paths; Lost = $lost; Status = $status; Selected = $true })
    }
}

function Add-DesktopOrderWrites($Plan) {
    # 2048 desktop tool item types: 0 group, 1 recent tab, 2 application, 3 recent file, 4 desktop.
    $order = @()
    foreach ($n in 'Desktop_FirstItem', 'Desktop_SecondItem', 'Desktop_ThirdItem', 'Desktop_FourthItem', 'Desktop_FifthItem') {
        $v = Get-Sec $Plan $n
        if ($v -ge 0 -and $v -le 3 -and $order -notcontains $v) { $order += $v }
    }
    foreach ($i in 0..3) { if ($order -notcontains $i) { $order += $i } }
    $raw = @('Desktop_FirstItem', 'Desktop_SecondItem', 'Desktop_ThirdItem', 'Desktop_FourthItem', 'Desktop_FifthItem' | ForEach-Object { $Plan.B2.Sections[$_] }) -join ','
    $names = @('FirstItem', 'SecondItem', 'ThirdItem', 'FourthItem')
    for ($i = 0; $i -lt 4; $i++) { Add-Write $Plan 'Desktop' $names[$i] $order[$i] "Desktop item order $raw" 'item 4 (Desktop) has no fork equivalent and is dropped' }
}

# ---------------------------------------------------------------------------------------------
# Keyboard shortcuts
# ---------------------------------------------------------------------------------------------

function Add-KeyboardWrites($Plan) {
    $user = $Plan.B2.Keys
    $def = $Plan.B2.KeyDefaults
    if ($null -eq $user) { $Plan.Notes.Add('The export has no <KeyboardShortcuts>; shortcuts not imported.'); return }
    $count = $script:ForkActions.Count
    $base = New-Object int[] $count
    for ($i = 0; $i -lt $count; $i++) {
        $a = $script:ForkActions[$i]
        if ($script:ForkDefaultKeys.Contains($a)) { $base[$i] = $script:ForkDefaultKeys[$a] -bor $script:FlagEnabled }
    }
    $final = [int[]]$base.Clone()
    $origin = New-Object string[] $count       # 'b2' (from 2048), 'cleared', 'base'
    $fromText = New-Object string[] $count
    $noteText = New-Object string[] $count
    for ($i = 0; $i -lt $count; $i++) { $origin[$i] = 'base'; $fromText[$i] = ''; $noteText[$i] = '' }
    $mapped = @{}
    foreach ($m in $script:KeyMap) { $mapped[[int]$m[0]] = $m }

    $stats = [ordered]@{ Enabled2048 = 0; Transferred = 0; Approximate = 0; NotTransferred = 0; Lost = 0; Cleared = 0; PassThroughStripped = 0; Native = 0 }
    $userChords = @{}     # chord -> fork slot it was transferred to
    for ($i = 0; $i -lt $user.Length; $i++) {
        $u = $user[$i]
        $enabled = ($u -band $script:FlagEnabled) -ne 0
        $b2name = $(if ($i -lt $script:Data.B2KeyNames.Count) { $script:Data.B2KeyNames[$i] } else { "#$i" })
        if ($enabled) { $stats.Enabled2048++ }
        if (-not $mapped.ContainsKey($i) -and $enabled -and $script:ExplorerNativeKeys.ContainsKey($i) -and (Format-Chord $u) -eq $script:ExplorerNativeKeys[$i]) {
            $stats.Native++
            continue
        }
        if (-not $mapped.ContainsKey($i)) {
            if ($enabled) { $stats.Lost++; $Plan.KeyLost.Add([pscustomobject]@{ B2 = $b2name; Index = $i; Chord = (Format-Chord $u); Reason = 'no fork action'; Value = $u }) }
            continue
        }
        $target = $mapped[$i][1]
        $note = $mapped[$i][2]
        $slot = [array]::IndexOf($script:ForkActions, $target)
        if ($slot -lt 0) { throw "Internal error: unknown fork action $target." }
        $d = $(if ($i -lt $def.Length) { $def[$i] } else { 0 })
        if ($script:ForkNoopActions -contains $target) {
            if ($enabled) {
                $stats.NotTransferred++
                $Plan.KeyLost.Add([pscustomobject]@{ B2 = $b2name; Index = $i; Chord = (Format-Chord $u); Reason = "fork action $target has an empty handler in this fork build (key would be swallowed)"; Value = $u })
                $fromText[$slot] = "$b2name ($i) $(Format-Chord $u) not transferred"
                $noteText[$slot] = 'empty handler in this fork build'
                if ($base[$slot] -ne 0) { $noteText[$slot] += '; fork default kept' }
            }
            continue
        }
        if ($enabled) {
            $v = ($u -band 0xFFFFF) -bor $script:FlagEnabled
            if (($u -band $script:FlagPassThrough) -ne 0) { $stats.PassThroughStripped++; $note = (@($note, '2048 pass-through flag dropped (the fork cannot pass keys through)') | Where-Object { $_ }) -join '; ' }
            $final[$slot] = $v; $origin[$slot] = 'b2'; $fromText[$slot] = "$b2name ($i)"; $noteText[$slot] = $note
            $stats.Transferred++
            if ($note -like 'approximate*') { $stats.Approximate++ }
            $userChords[$v] = $slot
        }
        elseif ($u -ne 0) {
            $final[$slot] = $u -band 0xFFFFF; $origin[$slot] = 'b2'; $fromText[$slot] = "$b2name ($i) disabled"; $noteText[$slot] = 'disabled in 2048'
        }
        elseif ($d -ne 0) {
            $final[$slot] = 0; $origin[$slot] = 'cleared'; $fromText[$slot] = "$b2name ($i) cleared"
            $noteText[$slot] = 'you removed the 2048 default ' + (Format-Chord $d)
            $stats.Cleared++
        }
        else {
            $fromText[$slot] = "$b2name ($i) empty"
            if ($base[$slot] -ne 0) { $noteText[$slot] = '2048 slot empty by default; fork default kept' }
        }
    }

    # Conflicts: a fork default (kept) that uses one of your transferred chords for another action.
    for ($s = 0; $s -lt $count; $s++) {
        if ($origin[$s] -ne 'base' -or $final[$s] -eq 0) { continue }
        if ($userChords.ContainsKey($final[$s])) {
            $winner = $userChords[$final[$s]]
            $Plan.KeyConflicts.Add([pscustomobject]@{
                Chord = (Format-Chord $final[$s]); Winner = $script:ForkActions[$winner]; WinnerFrom = $fromText[$winner]
                Displaced = $script:ForkActions[$s]; Resolution = 'fork default unbound (your 2048 binding wins)' })
            $noteText[$s] = 'fork default ' + (Format-Chord $final[$s]) + ' unbound: conflicts with your ' + $script:ForkActions[$winner]
            $final[$s] = 0; $origin[$s] = 'displaced'
        }
    }
    # Chords of 2048 bindings that are not transferred but are bound to a different fork action.
    foreach ($l in $Plan.KeyLost) {
        $chord = ($l.Value -band 0xFFFFF) -bor $script:FlagEnabled
        $hit = [array]::IndexOf($final, $chord)
        if ($hit -ge 0) {
            $same = $false
            foreach ($m in $script:KeyMap) { if ($m[0] -eq $l.Index -and $m[1] -eq $script:ForkActions[$hit]) { $same = $true } }
            if (-not $same) {
                $Plan.KeyConflicts.Add([pscustomobject]@{ Chord = (Format-Chord $chord); Winner = $script:ForkActions[$hit]; WinnerFrom = $fromText[$hit]; Displaced = "(2048 $($l.B2), not transferred)"; Resolution = 'informational: the fork binding stays' })
            }
            else { $Plan.KeyWarnings.Add("$(Format-Chord $chord) stays bound by the fork default to $($script:ForkActions[$hit]), whose handler is empty in this fork build.") }
        }
    }
    # Duplicate chords and chords the fork handles before shortcuts (Ctrl+0..9 / Ctrl+NumPad0..9).
    $seen = @{}
    for ($s = 0; $s -lt $count; $s++) {
        $v = $final[$s]
        if (($v -band $script:FlagEnabled) -eq 0) { continue }
        if ($seen.ContainsKey($v)) { $Plan.KeyWarnings.Add("$(Format-Chord $v) is bound twice ($($script:ForkActions[$seen[$v]]), $($script:ForkActions[$s])); only the first fires.") }
        else { $seen[$v] = $s }
        $code = $v -band 0xFFFF; $mods = $v -band 0x70000
        if ($mods -eq $script:KCtrl -and (($code -ge 48 -and $code -le 57) -or ($code -ge 96 -and $code -le 105))) {
            $Plan.KeyWarnings.Add("$(Format-Chord $v) ($($script:ForkActions[$s])) never fires: the fork uses Ctrl+digit for tab switching before it checks shortcuts.")
        }
    }

    for ($s = 0; $s -lt $count; $s++) {
        $Plan.KeyRows.Add([pscustomobject]@{
            Slot = $s; Action = $script:ForkActions[$s]; New = $final[$s]; ForkDefault = $base[$s]; Origin = $origin[$s]
            From = $fromText[$s]; Note = $noteText[$s] })
    }
    $Plan.KeyStats = $stats
    $json = '[' + (($final | ForEach-Object { $_.ToString($script:Inv) }) -join ',') + ']'
    $bound = @($final | Where-Object { ($_ -band $script:FlagEnabled) -ne 0 }).Count
    Add-Write $Plan 'Keys' 'Shortcuts' $json ("KeyboardShortcuts ({0} enabled in 2048)" -f $stats.Enabled2048) ("{0} of {1} fork actions bound" -f $bound, $count)
    if ($stats.Native -gt 0) { $Plan.Notes.Add("$($stats.Native) 2048 view-mode shortcuts (Ctrl+Shift+1..8) are built into Explorer itself; nothing to import.") }
}

# ---------------------------------------------------------------------------------------------
# Unmapped items, mouse report
# ---------------------------------------------------------------------------------------------

function Add-UnmappedOptions($Plan) {
    $changed = New-Object System.Collections.Generic.List[object]
    $atDefault = 0
    foreach ($e in $Plan.B2.Layout.List) {
        if ($Plan.UsedSections.ContainsKey($e.Name)) { continue }
        if ($script:DeadSections -contains $e.Name -or $e.Name -like 'Deprecated_*') { $atDefault++; continue }
        $u = $Plan.B2.Sections[$e.Name]; $d = $Plan.B2.SectionDefaults[$e.Name]
        if ($u -ne $d) { $changed.Add([pscustomobject]@{ Section = $e.Name; Value = $u; Default2048 = $d; Max = $e.Max }) }
        else { $atDefault++ }
    }
    $mouseSections = @($changed | Where-Object { $_.Section -match '(Clicked|Click|KeyDown|Executed)(WithCtrlKey|WithShftKey|WithAltKey|Ctrl|Shft|Alt|Sft|Ctl)?$' -or $_.Section -match '^(TreeItem|VersatileBarItem|Breadcrumbs|GroupMenuItemOn|WindowCloseButton|JumpListClose)' })
    $unusedXml = New-Object System.Collections.Generic.List[object]
    $emptyXml = 0
    foreach ($k in @($Plan.B2.Scalars.get_Keys())) {
        if ($Plan.UsedScalars.ContainsKey($k) -or $script:ImportedScalars -contains $k) { continue }
        $val = [string]$Plan.B2.Scalars[$k]
        if ([string]::IsNullOrEmpty($val)) { $emptyXml++; continue }
        $unusedXml.Add([pscustomobject]@{ Element = $k; Value = $val })
    }
    $Plan | Add-Member -NotePropertyName UnmappedChanged -NotePropertyValue $changed
    $Plan | Add-Member -NotePropertyName UnmappedAtDefault -NotePropertyValue $atDefault
    $Plan | Add-Member -NotePropertyName UnusedXml -NotePropertyValue $unusedXml
    $Plan | Add-Member -NotePropertyName EmptyXml -NotePropertyValue $emptyXml
    $Plan | Add-Member -NotePropertyName LegacyEventSections -NotePropertyValue $mouseSections.Count
}

$script:SlotNames = @('', 'Ctrl', 'Shift', 'Ctrl+Shift', 'Alt', 'Ctrl+Alt', 'Shift+Alt', 'Ctrl+Shift+Alt')

function Get-MouseLabel([string]$List, [int]$Value) {
    if ($Value -eq -1) { return '(no QTTabBar action)' }
    $l = $script:Data.B2MouseLists[$List]
    if ($Value -ge 0 -and $Value -lt $l.Count) { return $l[$Value] }
    return (Format-Inv 'user command / id {0}' $Value)
}

function Add-MouseReport($Plan) {
    $rep = [pscustomobject]@{ UserChanges = New-Object System.Collections.Generic.List[object]; Compare = New-Object System.Collections.Generic.List[object]; Missing = 0 }
    $Plan.Mouse = $rep
    foreach ($src in $script:Data.B2MouseSources) {
        $name = $src.Name
        if ($script:ImportedMouseSources -contains $name) { continue }   # imported into CmdBars
        if (-not $Plan.B2.Mouse.Contains($name)) { $rep.Missing++; $vals = [int[]]$src.Default }
        else { $vals = $Plan.B2.Mouse[$name] }
        for ($slot = 0; $slot -lt 8; $slot++) {
            if ($vals[$slot] -ne $src.Default[$slot]) {
                $rep.UserChanges.Add([pscustomobject]@{ Source = $name; Modifiers = $(if ($slot -eq 0) { '(none)' } else { $script:SlotNames[$slot] })
                    Yours = (Get-MouseLabel $src.List $vals[$slot]); Default2048 = (Get-MouseLabel $src.List $src.Default[$slot]) })
            }
        }
        if (-not $script:MouseTargets.Contains($name)) { continue }
        $target = $script:MouseTargets[$name][0]; $button = $script:MouseTargets[$name][1]
        $forkMap = $script:ForkMouseDefaults[$target]
        for ($slot = 0; $slot -lt 8; $slot++) {
            $mods = $script:SlotNames[$slot]
            $chord = $(if ($mods) { "$mods+$button" } else { $button })
            $forkAct = $null
            if ($forkMap.ContainsKey($chord)) { $forkAct = $forkMap[$chord] }
            $v = $vals[$slot]
            if ($v -eq -1 -and $null -eq $forkAct) { continue }
            $label = Get-MouseLabel $src.List $v
            $equiv = $null
            if ($script:MouseEquiv.ContainsKey($src.List) -and $script:MouseEquiv[$src.List].ContainsKey($v)) { $equiv = $script:MouseEquiv[$src.List][$v] }
            $lastIdx = $script:Data.B2MouseLists[$src.List].Count - 1
            if ($null -ne $forkAct -and $null -ne $equiv -and $forkAct -eq $equiv) { $state = 'same' }
            elseif ($null -eq $forkAct -and ($v -eq -1 -or $v -eq $lastIdx)) { $state = 'same (nothing bound)' }
            else { $state = 'DIFFERENT' }
            $rep.Compare.Add([pscustomobject]@{ Source = $name; Chord = ("{0} {1}" -f $target, $chord); Yours = $label; ForkDefault = $(if ($forkAct) { $forkAct } else { '(nothing)' }); State = $state })
        }
    }
}

# Fork mouse-only BindAction members from QTUtility.FIRST_MOUSE_ONLY_ACTION (1000) on (Config.cs,
# persisted ordinals).
$script:ForkMouseActions = @(
    'Nothing', 'UpOneLevel', 'Refresh', 'Paste', 'Maximize', 'Minimize', 'ItemOpenInNewTab', 'ItemOpenInNewTabNoSel',
    'ItemOpenInNewWindow', 'ItemCut', 'ItemCopy', 'ItemDelete', 'ItemProperties', 'CopyItemPath', 'CopyItemName',
    'ChecksumItem', 'CloseTab', 'CloseLeftTab', 'CloseRightTab', 'UpOneLevelTab', 'LockTab', 'ShowTabMenu', 'TearOffTab',
    'CloneTab', 'CopyTabPath', 'TabProperties', 'ShowTabSubfolderMenu', 'CloseAllButThis', 'OpenCmd',
    'ItemsOpenInNewTabNoSel', 'SortTab', 'TurnOffRepeat', 'SelectAll'
)
$script:FirstMouseOnlyAction = 1000

function Get-ForkActionValue([string]$Name) {
    $i = [array]::IndexOf($script:ForkActions, $Name)
    if ($i -ge 0) { return $i }
    $i = [array]::IndexOf($script:ForkMouseActions, $Name)
    if ($i -ge 0) { return $script:FirstMouseOnlyAction + $i }
    throw "Internal error: unknown fork action $Name."
}

function Get-ForkActionName([int]$Value) {
    if ($Value -ge 0 -and $Value -lt $script:ForkActions.Count) { return $script:ForkActions[$Value] }
    $i = $Value - $script:FirstMouseOnlyAction
    if ($i -ge 0 -and $i -lt $script:ForkMouseActions.Count) { return $script:ForkMouseActions[$i] }
    return "#$Value"
}

# 'Ctrl+Shift+Middle' -> fork MouseChord flags (Shift 1, Ctrl 2, Alt 4, Left 8, Middle 32, Double 64).
function ConvertTo-ForkChord([string]$Chord) {
    $v = 0
    foreach ($p in $Chord -split '\+') {
        switch ($p) { 'Shift' { $v += 1 } 'Ctrl' { $v += 2 } 'Alt' { $v += 4 } 'Left' { $v += 8 } 'Middle' { $v += 32 } 'Double' { $v += 64 } default { throw "Internal error: chord part $p." } }
    }
    return $v
}

# Dictionary<MouseChord, BindAction> as DataContractJsonSerializer writes it.
function New-MouseDictJson($Dict) {
    $pairs = @($Dict.get_Keys() | Sort-Object | ForEach-Object { '{"Key":' + ([int]$_).ToString($script:Inv) + ',"Value":' + ([int]$Dict[$_]).ToString($script:Inv) + '}' })
    return '[' + ($pairs -join ',') + ']'
}

function ConvertTo-MouseDictCanonical([string]$Json) {
    $pairs = @([regex]::Matches($Json, '"Key"\s*:\s*(-?\d+)\s*,\s*"Value"\s*:\s*(-?\d+)') | ForEach-Object { [pscustomobject]@{ K = [int]$_.Groups[1].Value; V = [int]$_.Groups[2].Value } } | Sort-Object K)
    return (($pairs | ForEach-Object { "$($_.K)=$($_.V)" }) -join ';')
}

# 2048 Events/Interactive bindings -> fork Mouse\TabActions, BarActions, ItemActions, MarginActions.
# Each target starts from the fork defaults; a 2048 slot with an equivalent fork action replaces the
# fork binding for that chord, a slot set to nothing removes it, anything else keeps the fork default
# and is listed. Plain left click on tabs / the tab bar and plain double click on items stay with
# Explorer and QTTabBar (never bound). 2048's file-icon middle click has no separate fork target.
function Add-MouseWrites($Plan) {
    $lost = New-Object System.Collections.Generic.List[object]
    $Plan | Add-Member -NotePropertyName MouseLost -NotePropertyValue $lost -Force
    $targets = [ordered]@{}
    foreach ($t in 'TabActions', 'BarActions', 'ItemActions', 'MarginActions') {
        $d = @{}
        foreach ($chord in @($script:ForkMouseDefaults[$t].get_Keys())) { $d[(ConvertTo-ForkChord $chord)] = (Get-ForkActionValue $script:ForkMouseDefaults[$t][$chord]) }
        $script:ForkDefaults["Mouse.$t"] = ConvertTo-MouseDictCanonical (New-MouseDictJson $d)
        $targets[$t] = [pscustomobject]@{ Dict = $d; Sources = New-Object System.Collections.Generic.List[string] }
    }
    $any = $false
    foreach ($src in $script:Data.B2MouseSources) {
        $name = $src.Name
        if (-not $script:MouseTargets.Contains($name)) { continue }
        if (-not $Plan.B2.Mouse.Contains($name)) { continue }
        $target = $script:MouseTargets[$name][0]; $button = $script:MouseTargets[$name][1]
        $vals = $Plan.B2.Mouse[$name]
        if ($name -eq 'ViewFileIconMiddleClick') {
            for ($slot = 0; $slot -lt 8; $slot++) {
                $v = $vals[$slot]
                if ($v -ne -1 -and $v -ne $script:Data.B2MouseLists[$src.List].Count - 1) {
                    $lost.Add([pscustomobject]@{ Source = $name; Chord = (@($script:SlotNames[$slot], $button) | Where-Object { $_ }) -join '+'; Yours = (Get-MouseLabel $src.List $v); Reason = 'the fork has one middle-click binding for files and folders' })
                }
            }
            continue
        }
        $any = $true
        $entry = $targets[$target]
        $entry.Sources.Add($name)
        $lastIdx = $script:Data.B2MouseLists[$src.List].Count - 1
        for ($slot = 0; $slot -lt 8; $slot++) {
            $mods = $script:SlotNames[$slot]
            $chordText = $(if ($mods) { "$mods+$button" } else { $button })
            $chord = ConvertTo-ForkChord $chordText
            $v = $vals[$slot]
            $nothing = ($v -eq -1 -or $v -eq $lastIdx)
            $plain = (-not $mods) -and (($button -eq 'Left' -and ($target -eq 'TabActions' -or $target -eq 'BarActions')) -or ($button -eq 'Double' -and $target -eq 'ItemActions'))
            if ($plain) {
                if (-not $nothing) { $lost.Add([pscustomobject]@{ Source = $name; Chord = $chordText; Yours = (Get-MouseLabel $src.List $v); Reason = 'plain clicks stay with Explorer / QTTabBar' }) }
                continue
            }
            if ($nothing) { [void]$entry.Dict.Remove($chord); continue }
            $equiv = $null
            if ($script:MouseEquiv.ContainsKey($src.List) -and $script:MouseEquiv[$src.List].ContainsKey($v)) { $equiv = $script:MouseEquiv[$src.List][$v] }
            if ($null -eq $equiv) {
                $lost.Add([pscustomobject]@{ Source = $name; Chord = $chordText; Yours = (Get-MouseLabel $src.List $v); Reason = 'no fork equivalent (fork default kept)' })
                continue
            }
            $entry.Dict[$chord] = Get-ForkActionValue $equiv
        }
    }
    if (-not $any) { return }
    foreach ($t in @($targets.get_Keys())) {
        $e = $targets[$t]
        if ($e.Sources.Count -eq 0) { continue }
        Add-Write $Plan 'Mouse' $t (New-MouseDictJson $e.Dict) ('Events/Interactive: ' + ($e.Sources -join ', ')) ((@($e.Dict.get_Keys() | Sort-Object | ForEach-Object { (Format-ForkChord $_) + '=' + (Get-ForkActionName $e.Dict[$_]) })) -join ', ')
    }
}

function Format-ForkChord([int]$Chord) {
    $p = @()
    if ($Chord -band 2) { $p += 'Ctrl' }
    if ($Chord -band 1) { $p += 'Shift' }
    if ($Chord -band 4) { $p += 'Alt' }
    if ($Chord -band 8) { $p += 'Left' }
    if ($Chord -band 32) { $p += 'Middle' }
    if ($Chord -band 64) { $p += 'Double' }
    if ($Chord -band 128) { $p += 'X1' }
    if ($Chord -band 256) { $p += 'X2' }
    return ($p -join '+')
}

# ---------------------------------------------------------------------------------------------
# HKCU comparison, output
# ---------------------------------------------------------------------------------------------

# Read-only registry access (OpenSubKey with writable = false; never creates keys).
function Get-ForkRegistryValue([string]$Category, [string]$Name) {
    $k = $null
    try { $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("$script:RegConfig\$Category", $false) } catch { $k = $null }
    if ($null -eq $k) { return $null }
    try {
        $v = $k.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $v) { return $null }
        return [pscustomobject]@{ Value = $v; Kind = [string]$k.GetValueKind($Name) }
    }
    finally { $k.Close() }
}

function Test-ForkRootKey {
    $k = $null
    try { $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:RegRoot, $false) } catch { $k = $null }
    if ($null -eq $k) { return $false }
    $k.Close()
    return $true
}

# Existing fork values of the wrong kind make the fork's ReadConfig throw, and its single try/catch
# then skips every later setting and the post-load clamps. Report those that this import won't replace.
function Get-ExistingKindIssues($Plan) {
    $issues = New-Object System.Collections.Generic.List[string]
    foreach ($cat in @($script:Schema.get_Keys()) | Sort-Object) {
        $k = $null
        try { $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("$script:RegConfig\$cat", $false) } catch { $k = $null }
        if ($null -eq $k) { continue }
        try {
            foreach ($n in @($k.GetValueNames()) | Sort-Object) {
                if (-not $script:Schema[$cat].ContainsKey($n)) { continue }
                $replaced = @($Plan.Writes | Where-Object { $_.Category -eq $cat -and $_.Name -eq $n -and $_.Selected }).Count -gt 0
                if ($replaced) { continue }
                $want = Get-RegistryKind $script:Schema[$cat][$n]
                $have = [string]$k.GetValueKind($n)
                if ($have -ne $want) { $issues.Add("$cat\$n is $have, the fork expects $want") }
            }
        }
        finally { $k.Close() }
    }
    return ,$issues
}

function Read-CurrentValues($Plan) {
    $Plan | Add-Member -NotePropertyName ExistingIssues -NotePropertyValue (Get-ExistingKindIssues $Plan) -Force
    foreach ($w in $Plan.Writes) {
        $w.CurrentStatus = 'absent'
        $cur = Get-ForkRegistryValue $w.Category $w.Name
        if ($null -ne $cur) {
            $w.Current = $cur.Value; $w.CurrentKind = $cur.Kind
            if ($cur.Kind -ne $w.Kind) { $w.CurrentStatus = "WRONG KIND ($($cur.Kind))" }
            elseif ((ConvertTo-Canonical $w.Type $cur.Value) -eq $w.Canonical) { $w.CurrentStatus = 'same' }
            else { $w.CurrentStatus = 'DIFFERS' }
        }
        if ($script:ForkDefaults.ContainsKey($w.Key)) {
            if ($script:ForkDefaults[$w.Key] -eq $w.Canonical) { $w.DefaultStatus = 'same' } else { $w.DefaultStatus = 'changed' }
        }
        elseif ($w.Key -eq 'Keys.Shortcuts') {
            $changedSlots = @($Plan.KeyRows | Where-Object { $_.New -ne $_.ForkDefault }).Count
            if ($changedSlots -eq 0) { $w.DefaultStatus = 'same' } else { $w.DefaultStatus = "changed ($changedSlots slots)" }
        }
        else { $w.DefaultStatus = 'n/a' }
    }
}

function Get-DisplayValue($W) {
    if ($W.Kind -eq 'DWord') { return $W.Value.ToString($script:Inv) }
    switch ($W.Type) {
        'Color' { return $W.Canonical -replace '^ARGB:', '#' }
        'Font' { $p = ($W.Canonical -replace '^Font:', '') -split '\|'; if ($p.Count -eq 3) { return "$($p[0]), $($p[1])pt, style $($p[2])" } }
        'Padding' { return $W.Canonical -replace '^Pad:', 'l,t,r,b=' }
    }
    if ($W.Key -eq 'Keys.Shortcuts') { return "$($script:ForkActions.Count) slots (see keyboard table)" }
    return [string]$W.Value
}

function Format-Cell([string]$Text, [int]$Width) {
    if ($null -eq $Text) { $Text = '' }
    if ($Text.Length -gt $Width) { return $Text.Substring(0, $Width - 3) + '...' }
    return $Text.PadRight($Width)
}

function Get-ConsoleLines($Plan, [bool]$IsApply) {
    $o = New-Object System.Collections.Generic.List[string]
    $mode = $(if ($IsApply) { 'APPLY' } else { 'DRY RUN - nothing is written' })
    $o.Add("QTTabBar 2048 Beta2 settings import ($mode)")
    $o.Add("Source : $($Plan.B2.Source)")
    $o.Add("Target : HKCU\$script:RegConfig\<Category>")
    if ($script:OnlySet) { $o.Add('Only   : ' + (($script:OnlySet | Sort-Object) -join ', ')) }
    $o.Add('')
    foreach ($cat in $script:CategoryOrder) {
        $ws = @($Plan.Writes | Where-Object { $_.Category -eq $cat })
        if ($ws.Count -eq 0) { continue }
        $sel = $(if ($ws[0].Selected) { '' } else { '   [SKIPPED by -Only]' })
        $o.Add("[$cat] HKCU\$script:RegConfig\$cat$sel")
        $o.Add('  ' + (Format-Cell 'Name' 32) + ' ' + (Format-Cell 'Kind' 6) + ' ' + (Format-Cell 'Value' 34) + ' ' + (Format-Cell 'HKCU now' 10) + ' ' + (Format-Cell 'vs fork default' 16) + ' From 2048')
        foreach ($w in $ws) {
            $dv = Get-DisplayValue $w
            $o.Add('  ' + (Format-Cell $w.Name 32) + ' ' + (Format-Cell $w.Kind 6) + ' ' + (Format-Cell $dv 34) + ' ' + (Format-Cell $w.CurrentStatus 10) + ' ' + (Format-Cell $w.DefaultStatus 16) + ' ' + $w.From)
            if ($dv.Length -gt 34 -or ($w.Kind -eq 'String' -and $w.Type -ne 'string' -and $w.Type -notmatch '^(TabPos|StretchMode)$')) { $o.Add('      data: ' + $w.Value) }
            if ($w.Note) { $o.Add('      note: ' + $w.Note) }
        }
        $o.Add('')
    }

    if ($Plan.KeyRows.Count -gt 0) {
        $s = $Plan.KeyStats
        $o.Add('Keyboard shortcuts (Keys\Shortcuts, fork BindAction slots)')
        $o.Add((Format-Inv '  2048 enabled: {0}; transferred: {1} (approximate: {2}); not transferred (empty fork handler): {3}; lost (no fork action): {4}; cleared fork defaults: {5}' $s.Enabled2048 $s.Transferred $s.Approximate $s.NotTransferred $s.Lost $s.Cleared))
        $o.Add('  ' + (Format-Cell 'Slot' 4) + ' ' + (Format-Cell 'Fork action' 22) + ' ' + (Format-Cell 'New' 18) + ' ' + (Format-Cell 'Fork default' 18) + ' From 2048 / note')
        foreach ($r in $Plan.KeyRows) {
            if ($r.New -eq 0 -and $r.ForkDefault -eq 0 -and -not $r.From) { continue }
            $extra = (@($r.From, $r.Note) | Where-Object { $_ }) -join ' - '
            $o.Add('  ' + (Format-Cell ([string]$r.Slot) 4) + ' ' + (Format-Cell $r.Action 22) + ' ' + (Format-Cell (Format-Shortcut $r.New) 18) + ' ' + (Format-Cell (Format-Shortcut $r.ForkDefault) 18) + ' ' + $extra)
        }
        $o.Add('')
        $o.Add("Shortcut conflicts ($($Plan.KeyConflicts.Count))")
        if ($Plan.KeyConflicts.Count -eq 0) { $o.Add('  none') }
        foreach ($c in $Plan.KeyConflicts) { $o.Add("  $($c.Chord): yours = $($c.Winner) [$($c.WinnerFrom)], fork default = $($c.Displaced) -> $($c.Resolution)") }
        foreach ($wn in $Plan.KeyWarnings) { $o.Add("  warning: $wn") }
        $o.Add('')
        $o.Add("2048 shortcuts that are NOT imported ($($Plan.KeyLost.Count))")
        foreach ($l in $Plan.KeyLost) { $o.Add('  ' + (Format-Cell $l.B2 22) + ' ' + (Format-Cell $l.Chord 18) + ' ' + $l.Reason) }
        $o.Add('')
    }

    if ($null -ne $Plan.Buttons) {
        $b = $Plan.Buttons
        $o.Add("Button bar (CommandBar1st -> BBar\ButtonIndexes): $($b.Mapped.Count) mapped, $($b.Lost.Count) not imported")
        foreach ($m in $b.Mapped) { $o.Add("  #$($m.Pos) $($m.B2) -> $($m.Fork)") }
        foreach ($l in $b.Lost) { $o.Add("  #$($l.Pos) $($l.B2): NOT imported ($($l.Reason))") }
        foreach ($x in $b.OtherBars) { $o.Add("  $($x.Bar): $($x.Count) items ($($x.Types)) - no fork equivalent, not imported") }
        $o.Add('')
    }

    if ($null -ne $Plan.CmdBars) {
        foreach ($bar in $Plan.CmdBars.Bars) {
            $o.Add("Command bar $($bar.Bar) -> CmdBars\$($bar.Fork)Items (icon size $($bar.IconSize)): $($bar.Imported) of $($bar.Rows.Count) imported")
            foreach ($r in $bar.Rows) {
                $res = $r.Result
                if ($res.Ok) { $line = "  #$($r.Pos) $($res.Summary)" } else { $line = "  #$($r.Pos) NOT imported: $($res.Reason)" }
                if ($res.Notes.Count -gt 0) { $line += ' (' + ($res.Notes -join '; ') + ')' }
                $o.Add($line)
            }
            $o.Add('')
        }
    }
    if ($Plan.GroupPlan.Count -gt 0) {
        $gsel = $(if ($Plan.GroupPlan[0].Selected) { '' } else { '   [SKIPPED by -Only]' })
        $o.Add("Groups -> HKCU\$script:RegRoot\Groups (new groups are appended; existing ones are not changed)$gsel")
        foreach ($g in $Plan.GroupPlan) {
            $line = "  $($g.Name): $($g.Status), $($g.Paths.Count) folders"
            if ($g.Lost -gt 0) { $line += ", $($g.Lost) not resolvable" }
            $o.Add($line)
            if ($g.Status -eq 'add') { foreach ($p in $g.Paths) { $o.Add("      $p") } }
        }
        $o.Add('')
    }

    $o.Add("2048 options you changed that have no fork equivalent ($($Plan.UnmappedChanged.Count); $($Plan.UnmappedAtDefault) more unmapped sections are at 2048 defaults)")
    foreach ($u in $Plan.UnmappedChanged) { $o.Add('  ' + (Format-Cell $u.Section 36) + (Format-Inv ' yours={0} 2048 default={1}' $u.Value $u.Default2048)) }
    foreach ($l in $Plan.LostOptions) { $o.Add('  ' + (Format-Cell $l.Item 36) + " $($l.Value): $($l.Reason)") }
    $o.Add('')
    $o.Add("2048 <Config> elements not imported ($($Plan.UnusedXml.Count) with a value, $($Plan.EmptyXml) empty)")
    $o.Add('  ' + (($Plan.UnusedXml | ForEach-Object { $_.Element }) -join ', '))
    $o.Add('')

    if ($null -ne $Plan.Mouse) {
        $m = $Plan.Mouse
        $diff = @($m.Compare | Where-Object { $_.State -eq 'DIFFERENT' })
        $o.Add("Mouse bindings -> Mouse\TabActions, BarActions, ItemActions, MarginActions ($($m.UserChanges.Count) of your bindings differ from 2048 defaults; $($diff.Count) differ from the fork defaults; $($Plan.MouseLost.Count) not importable)")
        foreach ($c in $m.UserChanges) { $o.Add("  yours vs 2048 default: $($c.Source) [$($c.Modifiers)]: $($c.Yours) (2048 default: $($c.Default2048))") }
        foreach ($c in $diff) { $o.Add("  changed from the fork default: $($c.Source) -> $($c.Chord): yours = $($c.Yours); fork default = $($c.ForkDefault)") }
        $o.Add('')
    }

    $o.Add('Skipped by design')
    $o.Add("  Application launchers: $($Plan.B2.Launchers) entries")
    $o.Add('  Plugins: ' + ((@($Plan.B2.Plugins) | ForEach-Object { "$($_.Name) ($($_.Length / 2) bytes BinaryFormatter, not deserialized)" }) -join ', '))
    $o.Add('')
    if ($Plan.Notes.Count -gt 0) {
        $o.Add('Notes')
        foreach ($n in $Plan.Notes) { $o.Add("  - $n") }
        $o.Add('')
    }
    if ($Plan.ExistingIssues.Count -gt 0) {
        $o.Add("WARNING: existing HKCU values of the wrong kind ($($Plan.ExistingIssues.Count)); the fork's ReadConfig aborts at the first one. Fix or delete them:")
        foreach ($n in $Plan.ExistingIssues) { $o.Add("  - $n") }
        $o.Add('')
    }
    $sel = @($Plan.Writes | Where-Object { $_.Selected })
    $o.Add((Format-Inv 'Summary: {0} values planned ({1} selected), {2} differ from fork defaults, {3} differ from HKCU now ({4} absent); 2048 option sections used: {5} of {6}.' $Plan.Writes.Count $sel.Count @($Plan.Writes | Where-Object { $_.DefaultStatus -like 'changed*' }).Count @($Plan.Writes | Where-Object { $_.CurrentStatus -ne 'same' }).Count @($Plan.Writes | Where-Object { $_.CurrentStatus -eq 'absent' }).Count $Plan.UsedSections.Count $Plan.B2.Layout.List.Count))
    return $o
}

function ConvertTo-MdCell([string]$Text) {
    if ($null -eq $Text) { return '' }
    return ($Text -replace '\|', '\|' -replace "`r?`n", ' ')
}

function Get-MarkdownReport($Plan) {
    $o = New-Object System.Collections.Generic.List[string]
    $o.Add('# QTTabBar 2048 Beta2 -> fork settings mapping')
    $o.Add('')
    $o.Add('Generated by `Tools\Import2048Settings\Import-QTTabBar2048Settings.ps1` (dry-run analysis). This file contains the user''s settings; keep it out of the repository.')
    $o.Add('')
    $o.Add("- Source: ``$($Plan.B2.Source)`` (SerializedOptions=$($Plan.B2.SerializedOptions))")
    $o.Add("- Target: ``HKCU\$script:RegConfig\<Category>``")
    $s = $Plan.KeyStats
    $o.Add((Format-Inv '- Values planned: {0}; differ from fork defaults: {1}; 2048 option sections used: {2} of {3}' $Plan.Writes.Count @($Plan.Writes | Where-Object { $_.DefaultStatus -like 'changed*' }).Count $Plan.UsedSections.Count $Plan.B2.Layout.List.Count))
    if ($null -ne $s) { $o.Add((Format-Inv '- Shortcuts: {0} enabled in 2048; {1} transferred ({2} approximate); {3} not transferred (empty fork handler); {4} lost; {5} conflicts' $s.Enabled2048 $s.Transferred $s.Approximate $s.NotTransferred $s.Lost $Plan.KeyConflicts.Count)) }
    if ($null -ne $Plan.Buttons) { $o.Add("- Button bar: $($Plan.Buttons.Mapped.Count) of $($Plan.Buttons.Mapped.Count + $Plan.Buttons.Lost.Count) first-bar buttons mapped") }
    $o.Add("- 2048-only options you changed: $($Plan.UnmappedChanged.Count) (another $($Plan.UnmappedAtDefault) unmapped sections are at 2048 defaults)")
    if ($null -ne $Plan.Mouse) { $o.Add("- Mouse: imported; $($Plan.Mouse.UserChanges.Count) of your bindings differ from 2048 defaults, $(@($Plan.Mouse.Compare | Where-Object { $_.State -eq 'DIFFERENT' }).Count) differ from the fork defaults, $($Plan.MouseLost.Count) not importable") }
    $o.Add('')
    $o.Add('## Values to write')
    foreach ($cat in $script:CategoryOrder) {
        $ws = @($Plan.Writes | Where-Object { $_.Category -eq $cat })
        if ($ws.Count -eq 0) { continue }
        $o.Add('')
        $o.Add("### $cat (``HKCU\$script:RegConfig\$cat``)")
        $o.Add('')
        $o.Add('| Name | Kind | Value | HKCU now | vs fork default | From 2048 | Note |')
        $o.Add('|---|---|---|---|---|---|---|')
        foreach ($w in $ws) {
            $val = Get-DisplayValue $w
            if ($w.Kind -eq 'String' -and $w.Type -notmatch '^(string|TabPos|StretchMode)$' -and $w.Key -ne 'Keys.Shortcuts' -and $val -ne [string]$w.Value) { $val = $val + ' `' + $w.Value + '`' }
            $o.Add('| ' + (ConvertTo-MdCell $w.Name) + ' | ' + $w.Kind + ' | ' + (ConvertTo-MdCell $val) + ' | ' + (ConvertTo-MdCell $w.CurrentStatus) + ' | ' + (ConvertTo-MdCell $w.DefaultStatus) + ' | ' + (ConvertTo-MdCell $w.From) + ' | ' + (ConvertTo-MdCell $w.Note) + ' |')
        }
    }
    if ($Plan.KeyRows.Count -gt 0) {
        $o.Add('')
        $o.Add('## Keyboard shortcuts')
        $o.Add('')
        $sw = @($Plan.Writes | Where-Object { $_.Key -eq 'Keys.Shortcuts' })
        if ($sw.Count -eq 1) { $o.Add('Value written to `Keys\Shortcuts` (REG_SZ, index = fork BindAction, Keys | 0x100000 = enabled): `' + $sw[0].Value + '`'); $o.Add('') }
        $o.Add('| Slot | Fork action | New | Fork default | From 2048 | Note |')
        $o.Add('|---|---|---|---|---|---|')
        foreach ($r in $Plan.KeyRows) {
            if ($r.New -eq 0 -and $r.ForkDefault -eq 0 -and -not $r.From) { continue }
            $o.Add('| ' + $r.Slot + ' | ' + $r.Action + ' | ' + (ConvertTo-MdCell (Format-Shortcut $r.New)) + ' | ' + (ConvertTo-MdCell (Format-Shortcut $r.ForkDefault)) + ' | ' + (ConvertTo-MdCell $r.From) + ' | ' + (ConvertTo-MdCell $r.Note) + ' |')
        }
        $o.Add('')
        $o.Add('### Conflicts')
        $o.Add('')
        if ($Plan.KeyConflicts.Count -eq 0) { $o.Add('None.') }
        else {
            $o.Add('| Chord | Your binding | Fork default | Resolution |')
            $o.Add('|---|---|---|---|')
            foreach ($c in $Plan.KeyConflicts) { $o.Add('| ' + (ConvertTo-MdCell $c.Chord) + ' | ' + (ConvertTo-MdCell "$($c.Winner) ($($c.WinnerFrom))") + ' | ' + (ConvertTo-MdCell $c.Displaced) + ' | ' + (ConvertTo-MdCell $c.Resolution) + ' |') }
        }
        foreach ($wn in $Plan.KeyWarnings) { $o.Add(''); $o.Add("Warning: $wn") }
        $o.Add('')
        $o.Add('### 2048 shortcuts not imported')
        $o.Add('')
        $o.Add('| 2048 action | Chord | Reason |')
        $o.Add('|---|---|---|')
        foreach ($l in $Plan.KeyLost) { $o.Add('| ' + $l.B2 + ' | ' + (ConvertTo-MdCell $l.Chord) + ' | ' + (ConvertTo-MdCell $l.Reason) + ' |') }
    }
    if ($null -ne $Plan.Buttons) {
        $o.Add('')
        $o.Add('## Button bar')
        $o.Add('')
        $o.Add("First command bar, icon size $($Plan.Buttons.IconSize):")
        $o.Add('')
        $o.Add('| # | 2048 button | Fork button |')
        $o.Add('|---|---|---|')
        foreach ($m in $Plan.Buttons.Mapped) { $o.Add("| $($m.Pos) | $($m.B2) | $($m.Fork) |") }
        foreach ($l in $Plan.Buttons.Lost) { $o.Add("| $($l.Pos) | $(ConvertTo-MdCell $l.B2) | not imported: $(ConvertTo-MdCell $l.Reason) |") }
        foreach ($x in $Plan.Buttons.OtherBars) { $o.Add(''); $o.Add("- $($x.Bar): $($x.Count) items ($($x.Types)) - no fork equivalent, not imported") }
    }
    if ($null -ne $Plan.CmdBars) {
        foreach ($bar in $Plan.CmdBars.Bars) {
            $o.Add('')
            $o.Add("## Command bar $($bar.Bar)")
            $o.Add('')
            $o.Add("Imported into ``CmdBars\$($bar.Fork)Items`` (icon size $($bar.IconSize)): $($bar.Imported) of $($bar.Rows.Count) buttons.")
            $o.Add('')
            $o.Add('| # | Button | Notes |')
            $o.Add('|---|---|---|')
            foreach ($r in $bar.Rows) {
                $res = $r.Result
                $what = $(if ($res.Ok) { $res.Summary } else { 'not imported: ' + $res.Reason })
                $o.Add("| $($r.Pos) | $(ConvertTo-MdCell $what) | $(ConvertTo-MdCell ($res.Notes -join '; ')) |")
            }
        }
    }
    if ($Plan.GroupPlan.Count -gt 0) {
        $o.Add('')
        $o.Add('## Groups')
        $o.Add('')
        $o.Add("New groups are appended to ``HKCU\$script:RegRoot\Groups``; groups that already exist in the fork are not changed.")
        $o.Add('')
        $o.Add('| Group | Status | Folders | Not resolvable |')
        $o.Add('|---|---|---|---|')
        foreach ($g in $Plan.GroupPlan) { $o.Add("| $(ConvertTo-MdCell $g.Name) | $($g.Status) | $(ConvertTo-MdCell ($g.Paths -join ', ')) | $($g.Lost) |") }
    }
    $o.Add('')
    $o.Add('## 2048-only options you changed (not imported)')
    $o.Add('')
    $o.Add('| 2048 section | Yours | 2048 default | Max |')
    $o.Add('|---|---|---|---|')
    foreach ($u in $Plan.UnmappedChanged) { $o.Add("| $($u.Section) | $($u.Value) | $($u.Default2048) | $($u.Max) |") }
    foreach ($l in $Plan.LostOptions) { $o.Add("| $($l.Item) | $(ConvertTo-MdCell $l.Value) | | $(ConvertTo-MdCell $l.Reason) |") }
    $o.Add('')
    $legacy = ''
    if ($Plan.LegacyEventSections -gt 0) { $legacy = " $($Plan.LegacyEventSections) of the changed ones are legacy event sections (superseded by Events/Interactive)." }
    $o.Add("$($Plan.UnmappedAtDefault) further 2048 sections without a fork equivalent (or never read by 2048) are at their 2048 defaults.$legacy")
    $o.Add('')
    $o.Add('## 2048 `<Config>` elements not imported')
    $o.Add('')
    $o.Add('| Element | Value |')
    $o.Add('|---|---|')
    foreach ($x in $Plan.UnusedXml) {
        $v = $x.Value
        if ($v.Length -gt 80) { $v = $v.Substring(0, 77) + '...' }
        $o.Add('| ' + $x.Element + ' | ' + (ConvertTo-MdCell $v) + ' |')
    }
    $o.Add('')
    $o.Add("$($Plan.EmptyXml) further elements are empty.")
    if ($null -ne $Plan.Mouse) {
        $o.Add('')
        $o.Add('## Mouse bindings (imported into Mouse\*Actions)')
        if ($Plan.MouseLost.Count -gt 0) {
            $o.Add('')
            $o.Add('Not importable:')
            $o.Add('')
            foreach ($c in $Plan.MouseLost) { $o.Add('- ' + $c.Source + ' ' + $c.Chord + ' = ' + (ConvertTo-MdCell $c.Yours) + ' (' + $c.Reason + ')') }
        }
        $o.Add('')
        $o.Add('Your bindings that differ from the 2048 defaults:')
        $o.Add('')
        $o.Add('| 2048 event source | Modifiers | Yours | 2048 default |')
        $o.Add('|---|---|---|---|')
        foreach ($c in $Plan.Mouse.UserChanges) { $o.Add('| ' + $c.Source + ' | ' + $c.Modifiers + ' | ' + (ConvertTo-MdCell $c.Yours) + ' | ' + (ConvertTo-MdCell $c.Default2048) + ' |') }
        $o.Add('')
        $o.Add('Your 2048 behaviour vs the fork defaults (sources with a fork counterpart):')
        $o.Add('')
        $o.Add('| 2048 event source | Fork target / chord | Yours (2048) | Fork default | |')
        $o.Add('|---|---|---|---|---|')
        foreach ($c in $Plan.Mouse.Compare) { $o.Add('| ' + $c.Source + ' | ' + $c.Chord + ' | ' + (ConvertTo-MdCell $c.Yours) + ' | ' + $c.ForkDefault + ' | ' + $c.State + ' |') }
    }
    $o.Add('')
    $o.Add('## Skipped by design')
    $o.Add('')
    $o.Add("- Application launchers: $($Plan.B2.Launchers) entries")
    $o.Add('- Plugins: ' + ((@($Plan.B2.Plugins) | ForEach-Object { "$($_.Name) ($($_.Length / 2) bytes, BinaryFormatter - never deserialized)" }) -join '; '))
    if ($Plan.Notes.Count -gt 0) {
        $o.Add('')
        $o.Add('## Notes')
        $o.Add('')
        foreach ($n in $Plan.Notes) { $o.Add("- $n") }
    }
    if ($Plan.ExistingIssues.Count -gt 0) {
        $o.Add('')
        $o.Add('## Existing HKCU values of the wrong kind')
        $o.Add('')
        $o.Add('The fork''s ReadConfig aborts at the first of these (single try/catch), skipping all later settings:')
        $o.Add('')
        foreach ($n in $Plan.ExistingIssues) { $o.Add("- $n") }
    }
    $o.Add('')
    $o.Add('## After applying')
    $o.Add('')
    $o.Add('Restart Explorer (or sign out) before opening QTTabBar Options: an Explorer with QTTabBar loaded writes its in-memory settings back when OK is pressed in Options.')
    return $o
}

function Get-ExplorerReminder {
    return @(
        'IMPORTANT: restart Explorer (or sign out and back in) BEFORE opening QTTabBar Options.',
        'An Explorer process that already has QTTabBar loaded keeps its old settings in memory and writes',
        'all of them back to the registry when OK/Apply is pressed in Options, which would undo this import',
        '(a running QT Desktop Tool likewise rewrites Config\Desktop when its menu settings change).'
    )
}

# ---------------------------------------------------------------------------------------------
# Build plan from a 2048 export
# ---------------------------------------------------------------------------------------------

function Get-ImportPlan($B2) {
    $plan = New-Plan $B2
    Add-OptionWrites $plan
    Add-KeyboardWrites $plan
    Add-CommandBarWrites $plan
    Add-GroupWrites $plan
    Add-MouseWrites $plan
    Add-UnmappedOptions $plan
    Add-MouseReport $plan
    # sort writes by category order, then name (deterministic output)
    $sorted = @($plan.Writes | Sort-Object @{ Expression = { [array]::IndexOf($script:CategoryOrder, $_.Category) } }, @{ Expression = { $_.Name } })
    $plan.Writes.Clear()
    foreach ($w in $sorted) { $plan.Writes.Add($w) }
    foreach ($w in $plan.Writes) { Assert-ForkSetting $w.Category $w.Name | Out-Null }
    return $plan
}

function Set-EffectiveDefaultFont([string]$Override) {
    if ($Override) { $script:EffectiveDefaultFont = $Override; return }
    if ([System.Globalization.CultureInfo]::CurrentUICulture.Name -eq 'ja-JP') { $script:EffectiveDefaultFont = 'Yu Gothic UI' }
    else { $script:EffectiveDefaultFont = 'Segoe UI' }
}

# ---------------------------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------------------------

function Invoke-Apply($Plan, [string]$Backup, $Cmdlet) {
    $sel = @($Plan.Writes | Where-Object { $_.Selected })
    $newGroups = @($Plan.GroupPlan | Where-Object { $_.Selected -and $_.Status -eq 'add' })
    if ($sel.Count -eq 0 -and $newGroups.Count -eq 0) { Write-Output 'Nothing selected to write.'; return }
    if (Test-ForkRootKey) {
        $dir = Split-Path -Parent $Backup
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Output "Backup : reg export HKCU\$script:RegRoot `"$Backup`" /y"
        if ($Cmdlet.ShouldProcess("HKCU\$script:RegRoot", "reg export to $Backup")) {
            $p = Start-Process -FilePath "$env:SystemRoot\System32\reg.exe" -ArgumentList @('export', "HKCU\$script:RegRoot", "`"$Backup`"", '/y') -NoNewWindow -Wait -PassThru
            if ($p.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $Backup)) { throw "reg export failed (exit code $($p.ExitCode)); nothing was written." }
            Write-Output "Backup written: $Backup"
        }
    }
    else {
        Write-Output "Backup : HKCU\$script:RegRoot does not exist yet - nothing to back up (to undo, delete that key)."
    }
    $written = 0
    foreach ($w in $sel) {
        Assert-ForkSetting $w.Category $w.Name | Out-Null
        $path = "HKCU:\$script:RegConfig\$($w.Category)"
        if (-not $Cmdlet.ShouldProcess("$path\$($w.Name)", "set $($w.Kind)")) { continue }
        if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
        if ($w.Kind -eq 'DWord') { New-ItemProperty -LiteralPath $path -Name $w.Name -PropertyType DWord -Value ([int]$w.Value) -Force | Out-Null }
        else { New-ItemProperty -LiteralPath $path -Name $w.Name -PropertyType String -Value ([string]$w.Value) -Force | Out-Null }
        $back = Get-ForkRegistryValue $w.Category $w.Name
        if ($null -eq $back -or $back.Kind -ne $w.Kind -or [string]$back.Value -ne [string]$w.Value) {
            $bk = $(if ($null -eq $back) { 'absent' } else { $back.Kind })
            throw "Verification failed for $($w.Key) (read back: $bk). Restore the backup before starting Explorer."
        }
        $written++
    }
    Write-Output "Written and verified: $written values under HKCU\$script:RegConfig."
    if ($newGroups.Count -gt 0) { Add-ForkGroups $newGroups $Cmdlet }
}

# Appends groups as the fork's GroupsManager stores them: Groups\<n> (default) = name, "0".."k" = paths.
function Add-ForkGroups($Groups, $Cmdlet) {
    $existing = Get-ForkGroupNames
    $root = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$script:RegRoot\Groups")
    $added = 0
    try {
        $i = 0
        while ($true) {
            $t = $root.OpenSubKey($i.ToString($script:Inv), $false)
            if ($null -eq $t) { break }
            $t.Close()
            $i++
        }
        foreach ($g in $Groups) {
            if ($existing -contains $g.Name) { continue }
            $name = $i.ToString($script:Inv)
            if (-not $Cmdlet.ShouldProcess("HKCU\$script:RegRoot\Groups\$name", "add group '$($g.Name)'")) { continue }
            $gk = $root.CreateSubKey($name)
            try {
                $gk.SetValue('', [string]$g.Name, [Microsoft.Win32.RegistryValueKind]::String)
                for ($j = 0; $j -lt $g.Paths.Count; $j++) { $gk.SetValue($j.ToString($script:Inv), [string]$g.Paths[$j], [Microsoft.Win32.RegistryValueKind]::String) }
            }
            finally { $gk.Close() }
            $i++
            $added++
        }
    }
    finally { $root.Close() }
    Write-Output "Groups added: $added under HKCU\$script:RegRoot\Groups."
}

# ---------------------------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------------------------

function Invoke-SelfTest {
    $results = New-Object System.Collections.Generic.List[object]
    function Check([string]$Name, [bool]$Ok, [string]$Detail = '') { $results.Add([pscustomobject]@{ Name = $Name; Ok = $Ok; Detail = $Detail }) }

    Set-EffectiveDefaultFont 'Segoe UI'
    $layout = New-B2Layout
    $bits = ($layout.List | Measure-Object -Property Bits -Sum).Sum
    Check 'layout: 399 sections' ($layout.List.Count -eq 399) "$($layout.List.Count)"
    Check 'layout: 20 vectors = 80 bytes' ($layout.VectorCount -eq 20) "$($layout.VectorCount)"
    Check 'layout: 634 bits used' ($bits -eq 634) "$bits"
    $defBlob = ConvertFrom-Hex ($script:Data.B2DefaultConfigHex -join '')
    Check 'default config blob is 80 bytes' ($defBlob.Length -eq 80) "$($defBlob.Length)"
    $d = Read-B2Sections $defBlob $layout
    $expect = [ordered]@{
        NewTabLocation = 0; NextActiveTab = 4; MultiRow = 0; ShowNavigationButtons = 3; TabRenderingMode = 3; TabSizeAuto = 0
        CheckUpdate = 0; ShowTabSwitcher = 0; PlusButtonOnTabBar = 0; RestoreTabs = 0; ViewNoFullRowSelect = 1; ViewVistaLayout = 0
        AlwaysColumnHeader = 1; Preview = 1; SubDirTip = 1; SaveRecentFile = 1; CommandBar_ShowTextLabel = 0; RebarBackgroundImageMode = 3
        Desktop_FirstItem = 0; Desktop_SecondItem = 1; Desktop_ThirdItem = 3; Desktop_FourthItem = 2; Desktop_FifthItem = 4
        Desktop_IncludeGroup = 1; Desktop_DesktopDoubleClickEnabled = 1; ViewNoFocusedBorder = 1; MenuRendererEx = 0; TabDragHoverAction = 0
    }
    foreach ($k in $expect.get_Keys()) { Check "2048 default $k = $($expect[$k])" ($d[$k] -eq $expect[$k]) "decoded $($d[$k])" }

    $keys = ConvertTo-Int32Array (ConvertFrom-Hex ($script:Data.B2DefaultKeysHex -join ''))
    Check 'default keys: int32[183]' ($keys.Length -eq 183 -and $script:Data.B2KeyNames.Count -eq 183) "$($keys.Length)/$($script:Data.B2KeyNames.Count)"
    $enabled = @($keys | Where-Object { ($_ -band $script:FlagEnabled) -ne 0 }).Count
    Check 'default keys: 51 enabled' ($enabled -eq 51) "$enabled"
    Check 'default key CloseCurrent = Ctrl+W' ((Format-Shortcut $keys[8]) -eq 'Ctrl+W') (Format-Shortcut $keys[8])
    Check 'default key ToggleMenuBar = Alt+M' ((Format-Shortcut $keys[26]) -eq 'Alt+M') (Format-Shortcut $keys[26])
    Check 'default key CreateNewTxtFile = Ctrl+Shift+T' ((Format-Shortcut $keys[52]) -eq 'Ctrl+Shift+T') (Format-Shortcut $keys[52])
    Check 'default key GoBack slot empty (Alt+Left is built in)' ($keys[0] -eq 0) "$($keys[0])"
    Check 'B2CommandIds: 24 (FilterBox = 23)' ($script:Data.B2CommandIds.Count -eq 24 -and $script:Data.B2CommandIds[23] -eq 'FilterBox') "$($script:Data.B2CommandIds.Count)"
    $badMouse = @()
    foreach ($src in $script:Data.B2MouseSources) {
        if (-not $script:Data.B2MouseLists.ContainsKey($src.List)) { $badMouse += "$($src.Name): no list"; continue }
        foreach ($v in $src.Default) { if ($v -lt -1 -or $v -ge $script:Data.B2MouseLists[$src.List].Count) { $badMouse += "$($src.Name)=$v" } }
    }
    Check 'mouse: 27 sources, defaults within their lists' ($script:Data.B2MouseSources.Count -eq 27 -and $badMouse.Count -eq 0) ($badMouse -join ', ')

    Check 'JSON Color(-4144960)' ((New-ColorJson -4144960) -eq '{"knownColor":0,"name":null,"state":2,"value":4290822336}') (New-ColorJson -4144960)
    Check 'JSON Font(Segoe UI, 9, 0)' ((New-FontJson 'Segoe UI' 9 0) -eq '{"<FontName>k__BackingField":"Segoe UI","<FontSize>k__BackingField":9,"<FontStyle>k__BackingField":0}') (New-FontJson 'Segoe UI' 9 0)
    Check 'JSON Font size 10.5' ((New-FontJson 'A"b' 10.5 1) -eq '{"<FontName>k__BackingField":"A\"b","<FontSize>k__BackingField":10.5,"<FontStyle>k__BackingField":1}') (New-FontJson 'A"b' 10.5 1)
    Check 'JSON Padding(3,3,3,3)' ((New-PaddingJson 3 3 3 3) -eq '{"_all":true,"_bottom":3,"_left":3,"_right":3,"_top":3}') (New-PaddingJson 3 3 3 3)
    Check 'JSON Padding(1,2,3,4)' ((New-PaddingJson 1 2 3 4) -eq '{"_all":false,"_bottom":4,"_left":1,"_right":3,"_top":2}') (New-PaddingJson 1 2 3 4)
    Check 'canonical fork-written known colour (Black)' (((ConvertTo-Canonical 'Color' '{"knownColor":35,"name":null,"state":1,"value":0}') -eq 'ARGB:FF000000') -or ((ConvertTo-Canonical 'Color' '{"knownColor":35,"name":null,"state":1,"value":0}') -eq 'KnownColor:35')) (ConvertTo-Canonical 'Color' '{"knownColor":35,"name":null,"state":1,"value":0}')

    # End-to-end on a synthetic export holding the 2048 defaults.
    $xmlText = '<?xml version="1.0" encoding="utf-8"?><QTTabBar><SerializedOptions>All</SerializedOptions><Config>' +
        '<Config>' + ($script:Data.B2DefaultConfigHex -join '') + '</Config><KeyboardShortcuts>' + ($script:Data.B2DefaultKeysHex -join '') + '</KeyboardShortcuts>' +
        '<RecentTabMax>128</RecentTabMax><TabFont></TabFont><TabFontSize></TabFontSize><TabFontStyle>0</TabFontStyle><TabFontStyleActive>1</TabFontStyleActive>' +
        '<TabImageSizingMargin>01020304</TabImageSizingMargin><TabWidth>80</TabWidth><TabHeight>18</TabHeight><TabWidthMax>90</TabWidthMax><TabWidthMin>16</TabWidthMin>' +
        '<CommandBarImagePath>C:\qt2048-selftest\no-such-strip.png</CommandBarImagePath><ColorActive>-1</ColorActive><ColorToolbarBackground>-16777216</ColorToolbarBackground><PreviewMaxWidth>5000</PreviewMaxWidth>' +
        '</Config><CommandBar><CommandBar1st IconSize="16">' +
        '<CommandButton Type="BuiltIn"><CommandID>3</CommandID></CommandButton><CommandButton Type="BuiltIn"><CommandID>20</CommandID></CommandButton>' +
        '<CommandButton Type="ScriptingCommand"><CommandID>121</CommandID></CommandButton><CommandButton Type="BuiltIn"><CommandID>23</CommandID></CommandButton>' +
        '<CommandButton Type="BuiltIn"><CommandID>19</CommandID></CommandButton></CommandBar1st>' +
        '<CommandBar2nd IconSize="24">' +
        '<CommandButton Type="File" SubType="Split"><DisplayText>PC</DisplayText><IDL>14001F50E04FD020EA3A6910A2D808002B30309D0000</IDL></CommandButton>' +
        '<CommandButton Type="File" SubType="Normal"><DisplayText>c"md</DisplayText><Path>%windir%\system32\cmd.exe</Path><Args><Item>/k</Item><Item>%cd%</Item></Args>' +
        '<Verb>runas</Verb><IconResource>"%SystemRoot%\system32\SHELL32.dll", 133</IconResource><Options>0100000000000000000000000101</Options></CommandButton>' +
        '<CommandButton Type="BuiltIn"><CommandID>0</CommandID></CommandButton>' +
        '<CommandButton Type="Group" SubType="DropDown"><GroupAction>NewTabBackground</GroupAction><LabelVisibility>true</LabelVisibility><Groups><Group>G1</Group><Group>G2</Group></Groups></CommandButton>' +
        '<CommandButton Type="ScriptingCommand"><CommandID>121</CommandID></CommandButton></CommandBar2nd>' +
        '<CommandBarVertical IconSize="300"><CommandButton Type="File"><Path>C:\Windows</Path><FileAction>InPlace</FileAction></CommandButton>' +
        '<CommandButton Type="ScriptingCommand" SubType="DropDown"><CommandID>104</CommandID><DisplayText>VF</DisplayText><SubItems><CommandButton Type="File"><Path>C:\Temp</Path></CommandButton>' +
        '<CommandButton Type="BuiltIn"><CommandID>0</CommandID></CommandButton><CommandButton Type="ScriptingCommand"><CommandID>121</CommandID></CommandButton></SubItems></CommandButton></CommandBarVertical></CommandBar>' +
        '<Groups><Group Name="QT2048 selftest group"><Item Type="IDL">14001F50E04FD020EA3A6910A2D808002B30309D0000</Item><Item Type="IDL">0500AABB</Item></Group></Groups>' +
        '<Events><Interactive><CommandButtonClick>020000000C00000001000000FFFFFFFF05000000FFFFFFFFFFFFFFFF63000000</CommandButtonClick>' +
        '<TabBarDoubleClick>05000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF</TabBarDoubleClick><ViewIconDoubleClick>FFFFFFFF0000000001000000FFFFFFFF10000000FFFFFFFFFFFFFFFFFFFFFFFF</ViewIconDoubleClick>' +
        '<ViewBackgroundMiddleClick>09000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF</ViewBackgroundMiddleClick></Interactive></Events></QTTabBar>'
    $doc = New-Object System.Xml.XmlDocument
    $doc.XmlResolver = $null
    $doc.LoadXml($xmlText)
    $plan = Get-ImportPlan (Read-B2Export $doc '(synthetic 2048 defaults)')
    $pv = @{}
    foreach ($w in $plan.Writes) { $pv[$w.Key] = $w.Value }
    $exp = [ordered]@{
        'Tabs.NewTabPosition' = 'Rightmost'; 'Tabs.NextAfterClosed' = 'LastActive'; 'Tabs.MultipleTabRows' = 1; 'Tabs.ActiveTabOnBottomRow' = 1
        'Tabs.ShowNavButtons' = 0; 'Tabs.NeedPlusButton' = 0; 'Tabs.DragOverTabOpensSDT' = 1; 'Skin.UseTabSkin' = 0; 'Skin.FixedWidthTabs' = 0
        'Skin.TabTextCentered' = 0; 'Skin.ActiveTabInBold' = 1; 'Skin.TabMinWidth' = 16; 'Skin.TabMaxWidth' = 90; 'Skin.TabHeight' = 18
        'Skin.RebarStretchMode' = 'Full'; 'Skin.RebarImageSeperateBars' = 1; 'Skin.SkinAutoColorChangeClose' = 1
        'Skin.TabTextActiveColor' = (New-ColorJson -1)
        'Skin.TabTextFont' = (New-FontJson 'Segoe UI' 9 0); 'Skin.TabSizeMargin' = (New-PaddingJson 1 2 3 4)
        'Keys.UseTabSwitcher' = 0; 'Misc.AutoUpdate' = 0; 'Misc.TabHistoryCount' = 128; 'Tips.PreviewMaxWidth' = 1920
        'Tweaks.ToggleFullRowSelect' = 0; 'BBar.ShowButtonLabels' = 0; 'BBar.LargeButtons' = 0; 'BBar.ButtonIndexes' = '[3,20,21]'
        'Desktop.FirstItem' = 0; 'Desktop.SecondItem' = 1; 'Desktop.ThirdItem' = 3; 'Desktop.FourthItem' = 2; 'Desktop.IncludeGroup' = 1
    }
    foreach ($k in $exp.get_Keys()) {
        $ok = $pv.ContainsKey($k) -and ([string]$pv[$k] -eq [string]$exp[$k])
        Check "mapping $k = $($exp[$k])" $ok $(if ($pv.ContainsKey($k)) { [string]$pv[$k] } else { '(not planned)' })
    }
    # 2048 default has no toolbar colour enabled, so the text colour follows this machine's app theme.
    $tb = $(if ($pv.ContainsKey('Skin.ToolBarTextColor')) { [string]$pv['Skin.ToolBarTextColor'] } else { '(not planned)' })
    Check 'mapping Skin.ToolBarTextColor is black or white' (($tb -eq (New-ColorJson 4294967295)) -or ($tb -eq (New-ColorJson 4278190080))) $tb
    $rows = @{}
    foreach ($r in $plan.KeyRows) { $rows[$r.Action] = $r.New }
    $kexp = [ordered]@{
        CloseCurrent = 'Ctrl+W'; ShowUserAppsMenu = 'Alt+A'; ShowRecentTabsMenu = 'Alt+H'; NewFile = 'Ctrl+Shift+T'; NewWindow = '(none)'
        NewTab = 'Ctrl+T'; GoBack = 'Alt+Left'; CreateNewGroup = 'Ctrl+Shift+G'; NewFolder = 'Ctrl+Shift+F'; ShowRecentFilesMenu = 'Alt+F'
        FocusSearchBarBBar = 'Alt+W'; ChecksumSelected = 'Ctrl+Shift+H'
    }
    foreach ($k in $kexp.get_Keys()) { Check "shortcut $k = $($kexp[$k])" ((Format-Shortcut $rows[$k]) -eq $kexp[$k]) (Format-Shortcut $rows[$k]) }
    $st = $plan.KeyStats
    Check 'shortcuts: 51 enabled, 40 transferred, 0 not transferred, 8 Explorer view modes, 3 lost' ($st.Enabled2048 -eq 51 -and $st.Transferred -eq 40 -and $st.NotTransferred -eq 0 -and $st.Native -eq 8 -and $st.Lost -eq 3) (Format-Inv '{0}/{1}/{2}/{3}/{4}' $st.Enabled2048 $st.Transferred $st.NotTransferred $st.Native $st.Lost)
    Check 'shortcuts: Keys\Shortcuts has one slot per fork keyboard action' ((($pv['Keys.Shortcuts'] -split ',').Count) -eq $script:ForkActions.Count) "$($script:ForkActions.Count)"
    $conf = @($plan.KeyConflicts | Where-Object { $_.Displaced -eq 'NewWindow' })
    Check 'conflict: Ctrl+Shift+T displaces fork NewWindow' ($conf.Count -eq 1) "$($plan.KeyConflicts.Count) conflicts"
    Check 'button bar: 3 mapped, 2 lost' ($plan.Buttons.Mapped.Count -eq 3 -and $plan.Buttons.Lost.Count -eq 2) "$($plan.Buttons.Mapped.Count)/$($plan.Buttons.Lost.Count)"
    Check 'mouse: no user changes on defaults' ($plan.Mouse.UserChanges.Count -eq 0) "$($plan.Mouse.UserChanges.Count)"
    $mexp = [ordered]@{
        'Mouse.BarActions' = '[{"Key":32,"Value":17},{"Key":34,"Value":19},{"Key":64,"Value":17}]'
        'Mouse.ItemActions' = '[{"Key":32,"Value":1006},{"Key":34,"Value":1007},{"Key":65,"Value":1007},{"Key":66,"Value":1006},{"Key":68,"Value":1012}]'
        'Mouse.MarginActions' = '[{"Key":32,"Value":1032},{"Key":64,"Value":1001},{"Key":66,"Value":1028}]'
    }
    foreach ($k in $mexp.get_Keys()) {
        Check "mapping $k" ($pv.ContainsKey($k) -and [string]$pv[$k] -eq $mexp[$k]) $(if ($pv.ContainsKey($k)) { [string]$pv[$k] } else { '(not planned)' })
    }
    Check 'no TabActions without tab events' (-not $pv.ContainsKey('Mouse.TabActions')) ''
    Check 'mouse dictionary canonical form ignores order' ((ConvertTo-MouseDictCanonical '[{"Key":64,"Value":1},{"Key":32,"Value":2}]') -eq (ConvertTo-MouseDictCanonical '[{"Key":32,"Value":2},{"Key":64,"Value":1}]')) ''
    $unknown = @($plan.Writes | Where-Object { -not ($script:Schema.ContainsKey($_.Category) -and $script:Schema[$_.Category].ContainsKey($_.Name)) })
    Check 'all planned names exist in the fork schema' ($unknown.Count -eq 0) (($unknown | ForEach-Object { $_.Key }) -join ', ')
    $threw = $false
    try { Assert-ForkSetting 'Skin' 'NoSuchSetting' | Out-Null } catch { $threw = $true }
    Check 'unknown setting names are refused' $threw ''
    $kindBad = @($plan.Writes | Where-Object { ($_.Kind -eq 'DWord') -ne ($_.Type -eq 'bool' -or $_.Type -eq 'int') })
    Check 'registry kinds follow the schema types' ($kindBad.Count -eq 0) (($kindBad | ForEach-Object { $_.Key }) -join ', ')

    # Button image strip: a missing file is reported, not written; strip sizes the fork reads.
    Check 'missing CommandBarImagePath is not planned' (-not $pv.ContainsKey('BBar.ImageStripPath') -and @($plan.LostOptions | Where-Object { $_.Item -eq 'CommandBarImagePath' }).Count -eq 1) ''
    $tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('qt2048-selftest-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    try {
        Add-Type -AssemblyName System.Drawing
        $stripResults = @()
        foreach ($sz in @(@(528, 40, $true), @(504, 24, $true), @(352, 16, $false))) {
            $p = Join-Path $tmpDir ("strip{0}x{1}.png" -f $sz[0], $sz[1])
            $bmp = New-Object System.Drawing.Bitmap $sz[0], $sz[1]
            try { $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png) } finally { $bmp.Dispose() }
            $tp = New-Plan ([pscustomobject]@{ Scalars = [ordered]@{ CommandBarImagePath = $p } })
            Add-ImageStripWrite $tp
            $stripResults += (@($tp.Writes | Where-Object { $_.Key -eq 'BBar.ImageStripPath' }).Count -eq 1) -eq $sz[2]
        }
        Check 'strip sizes: 528x40 and 504x24 imported, 352x16 refused' (@($stripResults | Where-Object { -not $_ }).Count -eq 0) ($stripResults -join ',')
    }
    finally { Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }

    # Second / vertical command bars, click events, groups.
    $pcName = '::{20D04FE0-3AEA-1069-A2D8-08002B30309D}'
    Check 'PIDL of This PC resolves to its parsing name' ((ConvertFrom-B2Pidl '14001F50E04FD020EA3A6910A2D808002B30309D0000') -eq $pcName) ([string](ConvertFrom-B2Pidl '14001F50E04FD020EA3A6910A2D808002B30309D0000'))
    Check 'malformed PIDLs are refused' ($null -eq (ConvertFrom-B2Pidl '0500AABB') -and $null -eq (ConvertFrom-B2Pidl 'ZZ') -and $null -eq (ConvertFrom-B2Pidl '0200')) ''
    $cexp = [ordered]@{
        'CmdBars.SecondBarItems' = '[{"Type":0,"Split":true,"Text":"PC","Path":"' + $pcName + '"},' +
            '{"Type":0,"Split":false,"Text":"c\"md","Path":"%windir%\\system32\\cmd.exe","Args":"/k","WorkingDir":"%cd%","Verb":"runas","WindowSize":1,"Icon":"%SystemRoot%\\system32\\SHELL32.dll,133"},' +
            '{"Type":2,"Split":false},{"Type":1,"Split":true,"Groups":["G1","G2"],"GroupAction":2}]'
        'CmdBars.VerticalBarItems' = '[{"Type":0,"Split":false,"Path":"C:\\Windows","FileAction":3},{"Type":3,"Split":false,"Text":"VF","Children":[{"Type":0,"Split":false,"Path":"C:\\Temp"},{"Type":2,"Split":false}]}]'
        'CmdBars.SecondBarIconSize' = 24; 'CmdBars.VerticalBarIconSize' = 256
        'CmdBars.SecondBarShowLabels' = [int]($plan.B2.Sections['CommandBar_ShowTextLabel2nd'] -eq 0); 'CmdBars.VerticalBarShowLabels' = 0
        'CmdBars.VerticalBarVisible' = [int]($plan.B2.Sections['CommandBar_VerticalEnabled'] -ne 0)
        'CmdBars.ClickActions' = '[2,12,1,-1,5,-1,-1,-1]'
    }
    foreach ($k in $cexp.get_Keys()) {
        $ok = $pv.ContainsKey($k) -and ([string]$pv[$k] -eq [string]$cexp[$k])
        Check "mapping $k" $ok $(if ($pv.ContainsKey($k)) { [string]$pv[$k] } else { '(not planned)' })
    }
    Check 'no MiddleClickActions without the event' (-not $pv.ContainsKey('CmdBars.MiddleClickActions')) ''
    $bar2 = @($plan.CmdBars.Bars | Where-Object { $_.Bar -eq 'CommandBar2nd' })
    Check 'command bar 2: 4 of 5 imported' ($bar2.Count -eq 1 -and $bar2[0].Imported -eq 4 -and $bar2[0].Rows.Count -eq 5) ''
    Check 'command bar items JSON is canonical-stable' ((ConvertTo-CmdItemsCanonical $cexp['CmdBars.VerticalBarItems']) -eq (ConvertTo-CmdItemsCanonical ('[{"Args":null,"FileAction":3,"GroupAction":0,"Groups":null,"Path":"C:\\Windows","Split":false,"Text":null,"Type":0,"Verb":null,"WindowSize":0,"WorkingDir":null},' +
            '{"Args":null,"Children":[{"Args":null,"Children":null,"FileAction":0,"Icon":null,"Path":"C:\\Temp","Split":false,"Text":null,"Type":0},{"Children":[],"Split":false,"Type":2}],"FileAction":0,"Icon":null,"Split":false,"Text":"VF","Type":3}]'))) ''
    $gp = $plan.GroupPlan.ToArray()   # (@() around this List throws in Windows PowerShell 5.1)
    Check 'groups: PIDL items resolved, malformed one counted' ($gp.Count -eq 1 -and $gp[0].Paths.Count -eq 1 -and $gp[0].Paths[0] -eq $pcName -and $gp[0].Lost -eq 1) $(if ($gp.Count -gt 0) { "$($gp[0].Paths -join ',') lost=$($gp[0].Lost)" } else { 'none' })

    # Cross-check against the repository's Config.cs when available.
    $cs = Join-Path $PSScriptRoot '..\..\QTTabBar\Config.cs'
    if (Test-Path -LiteralPath $cs) {
        $src = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $cs).ProviderPath, [Text.Encoding]::UTF8)
        $parsed = @{}
        $cur = $null
        foreach ($line in ($src -split "`r?`n")) {
            $m = [regex]::Match($line, '^\s*public\s+class\s+_(\w+)\b')
            if ($m.Success) { $cur = $m.Groups[1].Value; $parsed[$cur] = @{}; continue }
            if ($null -eq $cur) { continue }
            $m = [regex]::Match($line, '^\s*public\s+(?!static)([\w<>\[\], ]+?)\s+(\w+)\s*\{\s*get;\s*set;\s*\}')
            if ($m.Success) { $parsed[$cur][$m.Groups[2].Value] = ($m.Groups[1].Value -replace '\s', '') }
        }
        $diffs = @()
        foreach ($cat in @($script:Schema.get_Keys()) + @($parsed.get_Keys()) | Sort-Object -Unique) {
            if (-not $parsed.ContainsKey($cat)) { $diffs += "missing class _$cat"; continue }
            if (-not $script:Schema.ContainsKey($cat)) { $diffs += "new class _$cat"; continue }
            foreach ($n in @($parsed[$cat].get_Keys()) + @($script:Schema[$cat].get_Keys()) | Sort-Object -Unique) {
                $a = $(if ($script:Schema[$cat].ContainsKey($n)) { $script:Schema[$cat][$n] } else { '(none)' })
                $b = $(if ($parsed[$cat].ContainsKey($n)) { $parsed[$cat][$n] } else { '(none)' })
                if ($a -ne $b) { $diffs += "$cat.$n embedded=$a Config.cs=$b" }
            }
        }
        Check 'fork schema matches Config.cs' ($diffs.Count -eq 0) ($diffs -join '; ')
        $m = [regex]::Match($src, 'public\s+enum\s+BindAction\s*\{(?<b>.*?)KEYBOARD_ACTION_COUNT', 'Singleline')
        if ($m.Success) {
            $body = [regex]::Replace($m.Groups['b'].Value, '/\*.*?\*/', '', 'Singleline')
            $body = [regex]::Replace($body, '//[^\r\n]*', '')
            $names = @($body -split ',' | ForEach-Object { ($_ -replace '=.*$', '').Trim() } | Where-Object { $_ })
            Check 'BindAction order matches Config.cs' (($names -join ',') -eq ($script:ForkActions -join ',')) "$($names.Count) members"
        }
        else { Check 'BindAction order matches Config.cs' $false 'enum not found' }
        $m = [regex]::Match($src, 'Nothing\s*=\s*QTUtility\.FIRST_MOUSE_ONLY_ACTION\s*,(?<b>.*?)KEYBOARD_ACTION_COUNT2', 'Singleline')
        if ($m.Success) {
            $body = [regex]::Replace($m.Groups['b'].Value, '/\*.*?\*/', '', 'Singleline')
            $body = [regex]::Replace($body, '//[^\r\n]*', '')
            $names = @('Nothing') + @($body -split ',' | ForEach-Object { ($_ -replace '=.*$', '').Trim() } | Where-Object { $_ })
            Check 'mouse BindAction order matches Config.cs' (($names -join ',') -eq ($script:ForkMouseActions -join ',')) "$($names -join ',')"
        }
        else { Check 'mouse BindAction order matches Config.cs' $false 'mouse section not found' }
        $m = [regex]::Match($src, 'new\s+Dictionary<BindAction,\s*Keys>\s*\{(?<b>.*?)\};', 'Singleline')
        if ($m.Success) {
            $keyVal = @{ Left = 37; Right = 39; Tab = 9; T = 84; W = 87; Z = 90; O = 79; Oemcomma = 188; OemPeriod = 190; G = 71; H = 72; U = 85; F = 70; N = 78; D = 68; L = 76; Control = $script:KCtrl; Shift = $script:KShift; Alt = $script:KAlt }
            $found = [ordered]@{}
            $bad = @()
            foreach ($line in ($m.Groups['b'].Value -split "`r?`n")) {
                $t = $line.Trim()
                if ($t.StartsWith('//')) { continue }
                $mm = [regex]::Match($t, '^\{\s*BindAction\.(\w+)\s*,\s*([^}]+)\}')
                if (-not $mm.Success) { continue }
                $sum = 0
                foreach ($part in ($mm.Groups[2].Value -split '\|')) {
                    $p = ($part.Trim() -replace '^Key\.', '')
                    if ($keyVal.ContainsKey($p)) { $sum += $keyVal[$p] } else { $bad += $p }
                }
                $found[$mm.Groups[1].Value] = $sum
            }
            $kd = @()
            foreach ($n in @($found.get_Keys()) + @($script:ForkDefaultKeys.get_Keys()) | Sort-Object -Unique) {
                $a = $(if ($script:ForkDefaultKeys.Contains($n)) { $script:ForkDefaultKeys[$n] } else { $null })
                $b = $(if ($found.Contains($n)) { $found[$n] } else { $null })
                if ($a -ne $b) { $kd += "$n embedded=$a Config.cs=$b" }
            }
            if ($bad.Count -gt 0) { $kd += ('unknown key tokens: ' + ($bad -join ',')) }
            Check 'fork default shortcuts match Config.cs' ($kd.Count -eq 0) ($kd -join '; ')
        }
        else { Check 'fork default shortcuts match Config.cs' $false 'dictionary not found' }
    }
    else { $results.Add([pscustomobject]@{ Name = 'Config.cs cross-check'; Ok = $true; Detail = 'SKIPPED (QTTabBar\Config.cs not found next to the script)' }) }

    return ,$results
}

# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

if ($PSCmdlet.ParameterSetName -eq 'SelfTest') {
    $results = Invoke-SelfTest
    $fail = 0
    foreach ($r in $results) {
        if ($r.Ok) { $tag = 'PASS' } else { $tag = 'FAIL'; $fail++ }
        $line = "[$tag] $($r.Name)"
        if ($r.Detail -and (-not $r.Ok -or $r.Detail -like 'SKIPPED*')) { $line += " -- $($r.Detail)" }
        Write-Output $line
    }
    Write-Output (Format-Inv 'Self-test: {0} checks, {1} failed.' $results.Count $fail)
    if ($fail -gt 0) { exit 1 }
    exit 0
}

$script:OnlySet = $null
if ($Only) {
    # also accept "Keys,Tabs" as one argument (powershell.exe -File passes it unsplit)
    $parts = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $script:OnlySet = @()
    $valid = @($script:CategoryOrder) + $script:GroupsCategory
    foreach ($p in $parts) {
        $match = @($valid | Where-Object { $_ -eq $p })
        if ($match.Count -eq 0) { throw "-Only: unknown category '$p'. Valid: $($valid -join ', ')." }
        if ($script:OnlySet -notcontains $match[0]) { $script:OnlySet += $match[0] }
    }
}
Set-EffectiveDefaultFont $DefaultFontName

$doc = Read-B2XmlDocument $XmlPath
$b2 = Read-B2Export $doc ((Resolve-Path -LiteralPath $XmlPath).ProviderPath)
$plan = Get-ImportPlan $b2
if ($script:OnlySet) {
    foreach ($w in $plan.Writes) { $w.Selected = ($script:OnlySet -contains $w.Category) }
    foreach ($g in $plan.GroupPlan) { $g.Selected = ($script:OnlySet -contains $script:GroupsCategory) }
}
Read-CurrentValues $plan

foreach ($line in (Get-ConsoleLines $plan $Apply.IsPresent)) { Write-Output $line }

if ($ReportPath) {
    $md = (Get-MarkdownReport $plan) -join "`r`n"
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportPath)
    $dir = Split-Path -Parent $full
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($full, $md + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "Report written: $full"
}

Write-Output ''
if ($Apply) {
    if (-not $BackupPath) { $BackupPath = Join-Path $env:LOCALAPPDATA ('QTTabBar\backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.reg') }
    $BackupPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BackupPath)
    Invoke-Apply $plan $BackupPath $PSCmdlet
    Write-Output ''
    foreach ($l in (Get-ExplorerReminder)) { Write-Output $l }
}
else {
    Write-Output 'Dry run only. Re-run with -Apply to back up HKCU\Software\QTTabBar and write the values above.'
    foreach ($l in (Get-ExplorerReminder)) { Write-Output $l }
}
