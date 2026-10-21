# Data for Import-QTTabBar2048Settings.ps1 (ASCII only, loaded with Import-PowerShellDataFile).
#
# 2048 tables: interoperability data derived by reading the QTTabBar 2048 Beta2 (2048.0.0.0) metadata,
# IL text and static data with read-only tools - section names, max values (bit widths follow from
# them), default value blobs, index/enum tables and option-dialog combo/action list labels.
# No 2048 code is contained or executed.
# Fork tables: derived from QTTabBar\Config.cs of this repository (category classes, property types).
@{
    FormatVersion = 1

    # 2048 Config bit-vector (<Config><Config>, 20 x int32 LE = 80 bytes): 399 sections in creation
    # order as Name:MaxValue. A section uses bitlen(MaxValue) bits right after the previous one; a new
    # 32-bit vector starts when offset + bits > 32. A combo-box value equal to MaxValue may be stored
    # as all-ones (Config.SetComboBoxIndex).
    B2Sections = @(
        'ShowTooltip:1', 'ShowMenuBar:1', 'ShowTabSwitcher:1', 'ShowNavigationButtons:2', 'MultiRow:2',
        'MenuRenderer:3', 'CheckUpdate:1', 'SaveSettingsAuto:1', 'PlaySoundForError:1', 'AllowShortcutsWithoutModKeys:1',
        'ActivateNewTab:1', 'NoSameTab:1', 'NewTabLocation:3', 'NextActiveTab:4', 'RestoreTabs:1',
        'RestoreLockedTabs:1', 'LockedTabLocksWindow:1', 'CloseTabOnSeparated:1', 'TabIsDropTarget:1', 'Deprecated_03:1',
        'TabAutoSuffix:1', 'TabDoubleClicked:12', 'TabSwitcherAero:1', 'TabMiddleClicked:12', 'TabClickedWithCtrlKey:12',
        'TabBarDoubleClicked:12', 'Deprecated_06:3', 'Deprecated_07:3', 'WindowCloseButtonClicked_Deprecated:2', 'JumpListCloseExecuted_Deprecated:2',
        'CaptureWindow:1', 'LockWindowSize:1', 'SaveWindowTransparency:1', 'SendWindowToTrayOnMinimize:1', 'ResizeWindowOnRowCountChange:1',
        'Deprecated_01:2', 'ViewHorizontalScroll:1', 'ViewF2ChangeTextSelection:1', 'ViewCursorLoop:1', 'Deprecated_02:1',
        'ViewBSKeyGoUp:1', 'MouseXButtonsNavigation:1', 'GroupCloseAllOnOpening:1', 'GroupMenuManagementItems:1', 'GroupContextMenuManagementItems:1',
        'GroupStartUpIndicator:4', 'GroupStartUpTabLocation:3', 'SaveRecentTab:1', 'SaveRecentFile:2', 'SaveRecentFileFromAppLauncher:2',
        'Preview:2', 'PreviewShowImageDetails:1', 'PreviewForFileInNetwork:1', 'PreviewTryExifThumbnail:1', 'PreviewForCompressed:1',
        'SubDirTip:2', 'SubDirTipMenuIncludeHiddens:1', 'SubDirTipMenuIncludeSystems:1', 'SubDirTipMenuIncludeFiles:1', 'SubDirTipMenuShowPreview:1',
        'SubDirTipAndMenuForCompressed:1', 'SubDirMenuForDropHilited:1', 'SubDirMenuForDropHilitedTab:1', 'HashWindowHashType:4', 'HashWindowShowResult:1',
        'HashWindowTopmost:1', 'HashWindowFullPath:1', 'HashWindowClearOnClose:1', 'GroupFileEnabled:3', 'GroupFileIconOverlay:1',
        'TabSizeAuto:2', 'TabTextBoldActive:1', 'TabTextShadow:1', 'TabTextAlign:1', 'TabRenderingMode:3',
        'TabFolderIcon:1', 'TabFolderIconDriveLetter:1', 'TabFolderIconShowMenu:1', 'TabCloseButton:1', 'TabCloseButtonWithAlt:1',
        'TabCloseButtonOnHover:1', 'RebarBackgroundColor:1', 'RebarBackgroundImage:1', 'RebarBackgroundImageMode:3', 'Desktop_FirstItem:4',
        'Desktop_SecondItem:4', 'Desktop_ThirdItem:4', 'Desktop_FourthItem:4', 'Desktop_GroupExpanded:1', 'Desktop_RecentTabExpanded:1',
        'Desktop_ApplicationExpanded:1', 'Desktop_RecentFileExpanded:1', 'Desktop_TaskBarDoubleClickEnabled:1', 'Desktop_DesktopDoubleClickEnabled:1', 'Desktop_LockMenu:1',
        'Desktop_TitleBackground:1', 'Desktop_IncludeGroup:1', 'Desktop_IncludeRecentTab:1', 'Desktop_IncludeApplication:1', 'Desktop_IncludeRecentFile:1',
        'Desktop_1ClickMenu:1', 'Desktop_EnbleApplicationShortcuts:1', 'Deprecated_04:1', 'ButtonBar_LargeButton:1', 'CommandBar_LockMenu:1',
        'CommandBar_ShowTextLabel:2', 'VersatileBar_IconSizeH:3', 'VersatileBar_IconSizeV:3', 'CommandBar_TextImageRelation2nd:4', 'CommandBar_TextImageRelationVert:4',
        'CommandBar_VerticalEnabled:1', 'DrawVerticalExplorerBarBgColor:1', 'VersatileBar_HideCloseButton:1', 'CommandBar_Frozen2nd:1', 'CommandBar_FrozenVrt:1',
        'UseDefaultTab:1', 'NoCloseDefaultTab:1', 'AllowSameTabIfDropped:1', 'PreviewForInactiveWindow:1', 'SubDirTipForInactiveWindow:1',
        'TabSubDirMenuAreaExtended:1', 'SaveRecentFileExeFileSeparate:2', 'DisableManageBandLayout:1', 'SaveExplorerTopMost:1', 'ExplorerTopMost:1',
        'NoDialogForUnknownGroup:1', 'NoDialogForInvalidGroupMember:1', 'NoDialogForEmptyGroup:1', 'NoDialogForEmptyGroupFile:1', 'NoDialogForPluginException:1',
        'CommandBar_EnableSubDirTip2nd:1', 'CommandBar_EnableSubDirTipVrt:1', 'ViewBackgroundDoubleClicked:17', 'NoDialogForRemoveGroupItem:1', 'ViewBackgroundMiddleClicked:17',
        'NoDialogForRemoveItemFromVBar:1', 'PlaySoundOnCopy:1', 'PlaySoundOnCut:1', 'PlaySoundOnPaste:1', 'PlaySoundOnDelete:1',
        'NODialogForRemoveAppItem:1', 'Desktop_EnableTitleSkin:1', 'PlaySoundOnNavigation:2', 'DisableMenuShortcutKeyString:1', 'CommandBar_VerticalOnceEnabled:1',
        'TabClickedWithShftKey:12', 'TabClickedWithAltKey:12', 'TabMiddleClickedWithCtrlKey:12', 'TabMiddleClickedWithShftKey:12', 'TabMiddleClickedWithAltKey:12',
        'TabBarDoubleClickedWithCtrlKey:12', 'TabBarDoubleClickedWithShftKey:12', 'TabBarDoubleClickedWithAltKey:12', 'TabBarMiddleClicked:12', 'TabBarMiddleClickedWithCtrlKey:12',
        'TabBarMiddleClickedWithShftKey:12', 'TabBarMiddleClickedWithAltKey:12', 'RestoreAlways:1', 'TabNumber:1', 'ViewIconMiddleClicked:9',
        'SubDirTipNoGhost:1', 'ViewScrollWithoutFocus:1', 'TreeScrollWithoutFocus:1', 'PreviewNoSaveMediaPosition:1', 'PreviewOnScreenCorner:1',
        'PreviewStop:1', 'PreviewFullSizeMode:1', 'TabDragHoverAction:7', 'TabDefaultDropEffect:3', 'GroupExpandSubItems:1',
        'NoDialogForRemoveGroupSubItem:1', 'SaveRecentTabWhen:4', 'LockedTabPreventsSelectionChange:1', 'LockedTabCanNotNavigate:1', 'NoNameDisplayTipForDetailView:1',
        'OptionWndSeparatedTaskButton:1', 'DisableWindowHorizontalMaximize:1', 'HashWindowSeparatedTaskButton:1', 'RecentTabPerSession:1', 'RecentFilePerSession:1',
        'SubDirMenuNoSortLibraray:1', 'DetailTooltip:1', 'DetailsInStatusText:1', 'GroupFolderMenuForSubItems:1', 'PreviewWithShiftKeyDown:1',
        'AutoHideTabBar:1', 'AutoHideCommandBar1st:1', 'AutoHideCommandBar2nd:1', 'AutoHideCommandBarV:1', 'ExpandToolbarsMaximizedWnd:1',
        'NoExpandToolbarsOnTabChange:1', 'NoAutoShowToolbars:1', 'BottomTabBarEnabled:1', 'AutoHideBottomTabBar:1', 'NoWheelTabChange:1',
        'ExplorerBarPriority:1', 'TabAnimation:1', 'Deprecated_05:1', 'AlwaysColumnHeader:1', 'ViewVistaLayout:1',
        'ViewNoFullRowSelect:1', 'ViewWatermarking:1', 'Deprecated_08:1', 'Deprecated_09:1', 'SwapMouseXButtons:1',
        'DrawHorizontalExplorerBarBgColor:1', 'TabIsNotDragSourceToTab:1', 'TabIsNotDragSourceToBar:1', 'ViewFixWidthListColumn:1', 'Desktop_IncludeDesktop:1',
        'Desktop_FifthItem:4', 'Desktop_DesktopExpanded:1', 'Desktop_1ClickMenuOnDesktop:1', 'Desktop_1MiddelClickMenuOnDesktop:1', 'ReverseRTLTabBar:1',
        'FocusViewOnControlPanel:1', 'BreadcrumbsLeftClick:4', 'BreadcrumbsLeftClickCtrl:4', 'BreadcrumbsLeftClickShft:4', 'BreadcrumbsLeftClickAlt:4',
        'BreadcrumbsMiddleClick:4', 'BreadcrumbsMiddleClickCtrl:4', 'BreadcrumbsMiddleClickShft:4', 'BreadcrumbsMiddleClickAlt:4', 'TreeItemClicked:5',
        'TreeItemClickedCtrl:5', 'TreeItemClickedShft:5', 'TreeItemClickedAlt:5', 'TreeItemMiddleClicked:5', 'TreeItemMiddleClickedCtrl:5',
        'TreeItemMiddleClickedShft:5', 'TreeItemMiddleClickedAlt:5', 'TreeItemEnterKeyDown:5', 'TreeItemEnterKeyDownCtrl:5', 'TreeItemEnterKeyDownShft:5',
        'TreeItemEnterKeyDownAlt:5', 'VersatileBarItemClick:7', 'VersatileBarItemClickCtrl:7', 'VersatileBarItemClickShft:7', 'VersatileBarItemClickAlt:7',
        'VersatileBarItemMiddleClick:7', 'VersatileBarItemMiddleClickCtrl:7', 'VersatileBarItemMiddleClickShft:7', 'VersatileBarItemMiddleClickAlt:7', 'WindowCloseButtonClicked:4',
        'WindowCloseButtonClickedCtrl:4', 'WindowCloseButtonClickedShft:4', 'WindowCloseButtonClickedAlt:4', 'JumpListCloseExecuted:4', 'JumpListCloseExecutedCtrl:4',
        'JumpListCloseExecutedShft:4', 'JumpListCloseExecutedAlt:4', 'Desktop_NoDesktopMenuAtAll:1', 'CommandBar_NoStartDrag:1', 'TabDragDropCreateWindow:1',
        'TabIsNotDragSource:1', 'TabBarIsNotDropTatget:1', 'RecentTabAllowDuplication:1', 'Desktop_OpenFolderInCurrentMonitor:1', 'Desktop_MoveCaptorWindow:1',
        'PreviewFullscreenMonitor:4', 'PreviewStopText:1', 'PreviewStopMedia:1', 'PreviewStopPicture:1', 'OpenFolderInCurrentMonitor:1',
        'MoveCaptorWindow:1', 'PreviewAlwaysMaxSized:1', 'ViewDisableExtendedColor:1', 'ViewEnableColorShellExt:1', 'ViewExtClrOverwritesNTFSClr:1',
        'CaptureWindowByShellExeHook:1', 'NoCaptureWinKeyAndE:1', 'PreviewFullscreenInfo:2', 'PreviewPlayNextOnEnd:1', 'PreviewSoftwareRendering:1',
        'CloseFailedTab:1', 'Desktop_NoCaptureDesktop:1', 'SubDirMenuSort:7', 'TabPaddingEnabled:1', 'CheckUpdateNoBeta:1',
        'WaitForNetworkTimeout:1', 'RecentTabOrder:3', 'RecentFileOrder:3', 'DropHelperOnDesktop:1', 'DropHelperOnFolderView:1',
        'DropHelperFolders:1', 'DropHelperLinks:1', 'ShrinkTabBarOnlyWhenSoleTab:1', 'ShrinkBtmBarOnlyWhenSoleTab:1', 'FileRenamerCaseSensitive:1',
        'FileRenamerRegex:1', 'FileRenamerSubdirectory:1', 'FileRenamerCollision:2', 'FileRenamerTargets:2', 'CommandBar_NoDropSiblings:1',
        'FocusOnStartUp:4', 'ViewSelClmnClrOverExtClrs:1', 'TabGroupColor:7', 'SubDirMenuIgnoreCustomColors:1', 'FileRenamerConsecutive:1',
        'FileRenamerConsecutiveNoPerFolder:1', 'FileRenamerListViewExpanded:1', 'FileRenamerSelection:1', 'TabGroupColorNoApplyToMenu:1', 'CommandBar_ShowTextLabel2nd:2',
        'CommandBar_ShowTextLabelVrt:2', 'CommandBar_TextImageRelation1st:4', 'CommandBar_Frozen1st:1', 'CommandBar_EnableSubDirTip1st:1', 'CommandBar_DefautLabelInvisibile:1',
        'NoDialogForCommandButtonCreationTime:1', 'CommandBar_Option_NoPoolDropped:1', 'NoDialogForCommandButtonDelete:1', 'FolderTreeBackColorEnabled:1', 'FolderTreeForeColorEnabled:1',
        'ChooseTabDialogView:2', 'FileRenamerFollowNavigation:1', 'FileRenamerFollowSelectionChange:1', 'NoFolderVerbs:1', 'ViewExtClrIgnoreRename:1',
        'TabCloseButtonDisableSkin:1', 'TabLockIconDisableSkin:1', 'ExtraViewBarEnabled2nd:1', 'ExtraViewNavButtons2nd:2', 'ExtraViewBarEnabled3rd:1',
        'ExtraViewNavButtons3rd:2', 'ExtraViewVisibleMode2nd:2', 'ExtraViewVisibleMode3rd:2', 'ExtraViewPriority:1', 'ExtraViewNoTab2nd:1',
        'ExtraViewNoTab3rd:1', 'ExtraViewAlwaysAddStartups2nd:1', 'ExtraViewAlwaysAddStartups3rd:1', 'ExtraViewNoDetailsPane2nd:1', 'ExtraViewCommandBar2nd:1',
        'ExtraViewNoDetailsPane3rd:1', 'ExtraViewCommandBar3rd:1', 'GroupMenuItemOnClicked:12', 'GroupMenuItemOnClickedSft:12', 'GroupMenuItemOnClickedCtl:12',
        'GroupMenuItemOnClickedAlt:12', 'GroupMenuItemOnMiddledClicked:12', 'GroupMenuItemOnMiddledClickedSft:12', 'GroupMenuItemOnMiddledClickedCtl:12', 'GroupMenuItemOnMiddledClickedAlt:12',
        'ExtraViewAddressBar2nd:2', 'ExtraViewAddressBar3rd:2', 'ExtraViewUseStartupFolder2nd:1', 'ExtraViewUseStartupFolder3rd:1', 'FileRenamerTopMost:1',
        'FocusNextViewByTabIfFocused:1', 'CapturingView:4', 'PlaySoundsInAppVolume:1', 'TabBarPriority:1', 'ActivateTabBarOnRequired:1',
        'ExtraViewHideBarOnLastTabClosed2nd:1', 'ExtraViewHideBarOnLastTabClosed3rd:1', 'ExtraViewNoDefaultLocation2nd:1', 'ExtraViewNoDefaultLocation3rd:1', 'NoCaptureDesktop:1',
        'TabWheelWithRightBtn:1', 'ViewNoFocusedBorder:1', 'NoDialogForCommandButtonAddMany:1', 'ExtraViewNoKeepViewRatio:1', 'CopyCreationTime:1',
        'TopTabBarStayAboveDefaultView:1', 'ExtraViewTabBarPos2nd:2', 'ExtraViewTabBarPos3rd:2', 'MenuRendererEx:7', 'IncrementalSearch:1',
        'IncrementalSearchPartialMatch:1', 'IncrementalSearchLoop:1', 'IncrementalNoUseIFilterPlgin:1', 'FileRenamerListCaseSensitive:1', 'FileRenamerListPreserveExt:1',
        'FileRenamerListRegex:1', 'FileRenamerListSelection:1', 'ViewSelClmnClrBlendExtClrs:1', 'LogFileOperations:1', 'ExtraViewDefaultTabOnClose2nd:1',
        'ExtraViewDefaultTabOnClose3rd:1', 'ExtraViewNoCloseDefaultTab2nd:1', 'ExtraViewNoCloseDefaultTab3rd:1', 'PlusButtonOnTabBar:1', 'IncrementalSearchOnMenuDisabled:1',
        'NoOriginalFocusRectangle:1', 'SelectedColumnUseAccentColor:1', 'HowToCaptureVirtualDesktop:4', 'ExtraViewNotFilterButSearch:1', 'PreviewSoftwareRenderingH264OnSubMonitor:1',
        'RemoveOtherProcessLayer:1', 'PlaySoundOnShellOpComplete:1', 'ViewXBtnNoNavInAllViewShft:1', 'IconEnlargeDotByDot:1', 'ExtraViewTreeVisible2nd:1',
        'ExtraViewTreeVisible3rd:1', 'MonotoneBuiltinButtonBmp:1', 'CheckHashOnFileOperation:1', 'AllowThirdPartyPlugin:1'
    )

    # 2048 built-in defaults: Config bit-vector (80 bytes) and KeyboardShortcuts int32[183] (LE), hex.
    B2DefaultConfigHex = @(
        '1968880F202511781D56DB1F7A70C3C813EC3B22203E00001F10FFFFFFFFF1FF0100340007011A90',
        '00CAB31CD1B31C0A8B402B04CBB28C08080000000000000400048050000000000000100000010000'
    )
    B2DefaultKeysHex = @(
        '000000000000000025001600270016000900120009001300000000000000000057001200570013000000000000000000',
        '000000005A0013004E001200000000004C001200000000004F001200470013004F001400BC001400BE00140047001400',
        '48001400410014004D001400430013005800130043001400580014004800130000000000000000006B0013006D001300',
        '510014004600120045001400520014005600140027001300000000000000000000000000000000000000000000000000',
        '000000000000000000000000460013005400130000000000000000000000000045001300440013000000000000000000',
        '0000000000000000000000000000000000000000550013004A0013000000000000000000000000000000000000000000',
        '000000000000000000000000000000000000000053001400000000004C00130050001300460014000000000000000000',
        '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '000000000000000000000000710011005700140000000000000000000000000000000000000000000000000000000000',
        '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '000000000000000000000000000000000000000031001300320013003300130034001300350013003600130037001300',
        '380013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '000000000000000000000000'
    )

    # 2048 KeyboardShortcuts slot names in index order (KeyShortcuts constants 0..182).
    # Slot value = System.Windows.Forms.Keys | 0x100000 (enabled) [| 0x200000 (pass-through)].
    B2KeyNames = @(
        'GoBack', 'GoFwrd', 'BackToFirst', 'FwrdToLast', 'SelectNextTab', 'SelectPrevTab',
        'SelectFirstTab', 'SelectLastTab', 'CloseCurrent', 'CloseAllButCurrent', 'CloseLeft', 'CloseRight',
        'CloseWindow', 'UndoClosedTab', 'CloneCurrent', 'OpenNewWindow', 'ToggleLock', 'ToggleLockAll',
        'BrowseFolder', 'CreateNewGroup', 'Option', 'ShowBarMenu', 'ShowTabMenu', 'ShowBtnGroupMenu',
        'ShowBtnRcntTabMenu', 'ShowBtnAppMenu', 'ToggleMenuBar', 'CopyPath', 'CopyName', 'CopyCurrentPath',
        'CopyCurrentName', 'ShowHashWindow', 'CopyFileHash', 'AlwaysOnTop', 'TransparencyPlus', 'TransparencyMins',
        'FocusListView', 'FocusSearchBar', 'FocusTree', 'FocusTab', 'FocusVCommandBar', 'ShowSubFolderMenu',
        'ShowPreview', 'SendTaskTray', 'DeleteFile', 'DeleteFileNuke', 'InvertSelection', 'DeleteCurrentTab',
        'CopyCurrentTab', 'CutCurrentTab', 'PasteShortcut', 'CreateNewFolder', 'CreateNewTxtFile', 'CreateShortcut',
        'CopyToFolder', 'MoveToFolder', 'CopyToTab', 'MoveToTab', 'CreateLinkInTab', 'CopySelToPrevTab',
        'MoveSelToPrevTab', 'LinkSelInPrevTab', 'CopySelToNextTab', 'MoveSelToNextTab', 'LinkSelInNextTab', 'CopyFromFolder',
        'MoveFromFolder', 'LinkFromFolder', 'CopyFromPrevTab', 'MoveFromPrevTab', 'CreatLnkFrmPrevTab', 'CopyFromNextTab',
        'MoveFromNextTab', 'CreatLnkFrmNextTab', 'ToggleButtonBar', 'ToggleVBar', 'ToggleVVBar', 'ToggleStatusBar',
        'MergeAllWindows', 'CreateNewLibrary', 'ShowKeyFinder', 'ShowRcntFileMenu', 'ActivateLastTab', 'CreateFldrAndOpen',
        'PreviewVolumeUp', 'PreviewVolumeDown', 'PreviewMute', 'PreviewSlower', 'PreviewResetSpeed', 'PreviewFaster',
        'PreviewBack', 'PreviewPause', 'PreviewFwrd', 'PreviewShrink', 'PreviewFullSize', 'PreviewWiden',
        'PreviewFullSzMode', 'PreviewCornerMode', 'PreviewFullScreen', 'RenameCurrentFldr', 'FocusFilterBox', 'MaximizeHrzntly',
        'ButtonBarOption', 'ViewLeft', 'ViewUp', 'ViewRight', 'ViewDown', 'ShrinkToolbars',
        'ExpandToolbars', 'ToggleToolbars', 'ToggleTabBar', 'ToggleBottomTabBar', 'SwapCurrentToPrev', 'SwapCurrentToNext',
        'ToggleTabBarUpDown', 'MenuCurrentHistory', 'RestoreTabs', 'ClearTabHistory', 'ClearFileHistory', 'PreviewLock',
        'PreviewPrevTrack', 'PreviewNextTrack', 'PreviewPrevScreen', 'PreviewNextScreen', 'ShowRenameDialog', 'ViewModeExtraLarge',
        'ViewModeLarge', 'ViewModeMedium', 'ViewModeSmall', 'ViewModeList', 'ViewModeDetails', 'ViewModeTile',
        'ViewModeContents', 'ViewSortByName', 'ViewSortBySize', 'ViewSortByType', 'ViewSortByModified', 'ViewPasteInto',
        'Toggle2ndExtraView', 'Toggle3rdExtraView', 'Focus2ndView', 'Focus3rdView', 'CopySelTo2nd', 'CopySelTo3rd',
        'CopySelToDef', 'MoveSelTo2nd', 'MoveSelTo3rd', 'MoveSelToDef', 'LinkSelTo2nd', 'LinkSelTo3rd',
        'LinkSelToDef', 'SyncScroll', 'SyncNavigation', 'SyncOtherView', 'SyncFocusedView', 'CopySelToOtherView',
        'MoveSelToOtherView', 'LinkSelToOtherView', 'FocusNextView', 'FocusFilterBoxForFocusedView', 'MoveActiveTabToDefaultView', 'MoveActiveTabToSecondView',
        'MoveActiveTabToThirdView', 'MoveActiveTabToOtherView', 'SyncOtherViewAll', 'ActivateTab01', 'ActivateTab02', 'ActivateTab03',
        'ActivateTab04', 'ActivateTab05', 'ActivateTab06', 'ActivateTab07', 'ActivateTab08', 'ActivateTab09',
        'ActivateTab10', 'IncrementalSelectionPrev', 'IncrementalSelectionNext', 'IncrementalSelectionAll', 'AnalyzeFolder', 'EditAttributes',
        'ShowCreateLinkForm', 'CopyPathUNC', 'CopyCurrentPathUNC'
    )

    # 2048 BuiltinCommandID (CommandBar CommandButton Type=BuiltIn, <CommandID>).
    B2CommandIds = @(
        'Separator', 'NavigationBack', 'NavigationForward', 'Group', 'RecentTab', 'AppLauncher',
        'NewWindow', 'Clone', 'Lock', 'MiscTool', 'WindowTopMost', 'CloseCurrent',
        'CloseAllButCurrent', 'CloseWindow', 'CloseLeft', 'CloseRight', 'GoUpOne', 'RefreshBrowser',
        'ShellSearch', 'Option', 'RecentFile', 'WindowOpacity', 'StopPreview', 'FilterBox'
    )

    # 2048 Events/Interactive sources (InteractiveEventSource order): action list id and built-in
    # default int32[8]. Slot = (Ctrl ? 1 : 0) | (Shift ? 2 : 0) | (Alt ? 4 : 0); value = index into the
    # list, -1 = no QTTabBar action (normal behaviour).
    B2MouseSources = @(
        @{ Name = 'TabClick'; List = 'Tab'; Default = @(-1,2,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'TabDoubleClick'; List = 'TabDouble'; Default = @(1,2,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'TabMiddleClick'; List = 'Tab'; Default = @(0,-1,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'TabRightClick'; List = 'Tab'; Default = @(3,3,3,3,3,3,3,3) },
        @{ Name = 'TabBarDoubleClick'; List = 'TabBar'; Default = @(5,-1,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'TabBarMiddleClick'; List = 'TabBar'; Default = @(1,-1,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'TabBarRightClick'; List = 'TabBar'; Default = @(4,4,4,4,4,4,4,4) },
        @{ Name = 'NavPaneClick'; List = 'NavPane'; Default = @(2,0,1,-1,-1,-1,-1,-1) },
        @{ Name = 'NavPaneMiddleClick'; List = 'NavPane'; Default = @(0,12,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'NavPaneEnter'; List = 'NavPane'; Default = @(2,0,1,-1,3,-1,-1,-1) },
        @{ Name = 'BreadcrumbsClick'; List = 'Breadcrumbs'; Default = @(2,0,1,-1,-1,-1,-1,-1) },
        @{ Name = 'BreadcrumbsMiddleClick'; List = 'Breadcrumbs'; Default = @(0,12,1,-1,-1,-1,-1,-1) },
        @{ Name = 'CommandButtonClick'; List = 'CommandButton'; Default = @(0,12,1,-1,5,-1,-1,-1) },
        @{ Name = 'CommandButtonMiddleClick'; List = 'CommandButton'; Default = @(15,-1,-1,-1,13,-1,-1,-1) },
        @{ Name = 'WindowCloseButton'; List = 'WindowClose'; Default = @(1,-1,1,-1,-1,-1,-1,-1) },
        @{ Name = 'JumpListCommand'; List = 'WindowClose'; Default = @(1,-1,3,-1,-1,-1,-1,-1) },
        @{ Name = 'GroupMenuClick'; List = 'GroupMenu'; Default = @(0,12,1,-1,2,-1,-1,-1) },
        @{ Name = 'GroupMenuMiddleClick'; List = 'GroupMenu'; Default = @(2,-1,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'ViewIconDoubleClick'; List = 'ViewIcon'; Default = @(-1,0,1,-1,16,-1,-1,-1) },
        @{ Name = 'ViewIconMiddleClick'; List = 'ViewIconMiddle'; Default = @(0,12,-1,1,-1,-1,-1,-1) },
        @{ Name = 'ViewBackgroundDoubleClick'; List = 'ViewBackground'; Default = @(0,-1,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'ViewBackgroundMiddleClick'; List = 'ViewBackground'; Default = @(9,-1,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'SubFolderMenuClick'; List = 'SubFolderMenu'; Default = @(2,12,1,16,0,0,0,0) },
        @{ Name = 'SubFolderMenuMiddleClick'; List = 'SubFolderMenu'; Default = @(0,12,1,16,0,0,0,0) },
        @{ Name = 'ViewEnterKey'; List = 'ViewIcon'; Default = @(-1,0,1,12,16,-1,-1,-1) },
        @{ Name = 'PlusButtonClick'; List = 'PlusButton'; Default = @(0,-1,-1,-1,-1,-1,-1,-1) },
        @{ Name = 'ViewFileIconMiddleClick'; List = 'ViewFileIcon'; Default = @(-1,-1,-1,-1,-1,-1,-1,-1) }
    )

    # 2048 per-source action lists (option dialog combo order; last entry = none).
    B2MouseLists = @{
        Tab = @(
            'Close', 'Go up one level', 'Lock', 'Show menu',
            'New window', 'Duplicate', 'Copy path', 'Properties',
            'Show Subfolder menu', 'Copy selected files to the tab', 'Move selected files to the tab', 'Create links to selected files in the tab',
            'Move the tab to Extra View (bottom)', 'Move the tab to Extra View (left)', 'Move that tab to the other view', 'Send the folder to the clipboard as copied',
            'Send the folder to the clipboard as cut', 'Paste to the folder from the clipboard', 'Delete the folder', 'Delete the folder permanently',
            'User command', 'none'
        )
        TabDouble = @(
            'Close', 'Go up one level', 'Lock', 'Show menu',
            'New window', 'Duplicate', 'Copy path', 'Properties',
            'Show Subfolder menu', 'Move the tab to Extra View (bottom)', 'Move the tab to Extra View (left)', 'Move that tab to the other view',
            'Send the folder to the clipboard as copied', 'Send the folder to the clipboard as cut', 'Paste to the folder from the clipboard', 'Delete the folder',
            'Delete the folder permanently', 'User command', 'none'
        )
        TabBar = @(
            'Go up one level', 'Browse folder and open new tab', 'Close all but the active tab', 'Lock all',
            'Show menu', 'Restore last closed', 'Open QTTabBar Options', 'Close window',
            'Duplicate active tab', 'Activate the most recently activated tab', 'User command', 'none'
        )
        ViewIcon = @(
            'Open new tab', 'Open new background tab', 'Navigate in the active tab', 'Open new tab in Extra View (bottom)',
            'Open new background tab in Extra View (bottom)', 'Navigate in the active tab of Extra View (bottom)', 'Open new tab in Extra View (left)', 'Open new background tab in Extra View (left)',
            'Navigate in the active tab of Extra View (left)', 'Open new tab in the other view', 'Open new background tab in the other view', 'Navigate in the active tab of the other view',
            'New window', 'Copy', 'Cut', 'Paste Into',
            'Properties', 'Copy path', 'User command', 'none'
        )
        ViewIconMiddle = @(
            'Open new tab', 'Open new background tab', 'Navigate in the active tab', 'Open new tab in Extra View (bottom)',
            'Open new background tab in Extra View (bottom)', 'Navigate in the active tab of Extra View (bottom)', 'Open new tab in Extra View (left)', 'Open new background tab in Extra View (left)',
            'Navigate in the active tab of Extra View (left)', 'Open new tab in the other view', 'Open new background tab in the other view', 'Navigate in the active tab of the other view',
            'New window', 'Copy', 'Cut', 'Paste Into',
            'Properties', 'Copy path', 'Pass the click to the background', 'User command',
            'none'
        )
        ViewFileIcon = @(
            'Copy', 'Cut', 'Properties', 'Copy path',
            'Pass the click to the background', 'User command', 'none'
        )
        ViewBackground = @(
            'Go up one level', 'Browse folder and open in tab', 'New Window', 'Duplicate',
            'Copy current folder path', 'Copy current folder name', 'Properties', 'Close window',
            'Close active tab', 'Select All', 'Invert Selection', 'Create a new folder',
            'Create a new txt file', 'Open ''Copy from folder'' dialog', 'Open ''Move from folder'' dialog', 'Open ''Create shortcut from folder'' dialog',
            'Paste', 'User command', 'none'
        )
        NavPane = @(
            'Open new tab', 'Open new background tab', 'Navigate in the active tab', 'Open new tab in Extra View (bottom)',
            'Open new background tab in Extra View (bottom)', 'Navigate in the active tab of Extra View (bottom)', 'Open new tab in Extra View (left)', 'Open new background tab in Extra View (left)',
            'Navigate in the active tab of Extra View (left)', 'Open new tab in a priority view', 'Open new background tab in a priority view', 'Navigate in the active tab of a priority view',
            'New window', 'Paste Into', 'Properties', 'Copy path',
            'Start renaming', 'User command', 'none'
        )
        Breadcrumbs = @(
            'Open new tab', 'Open new background tab', 'Navigate in the active tab', 'Open new tab in Extra View (bottom)',
            'Open new background tab in Extra View (bottom)', 'Navigate in the active tab of Extra View (bottom)', 'Open new tab in Extra View (left)', 'Open new background tab in Extra View (left)',
            'Navigate in the active tab of Extra View (left)', 'Open new tab in the other view', 'Open new background tab in the other view', 'Navigate in the active tab of the other view',
            'New window', 'Properties', 'Copy path', 'User command',
            'none'
        )
        CommandButton = @(
            'Open new tab', 'Open new background tab', 'Navigate in the active tab', 'Open new tab in Extra View (bottom)',
            'Open new background tab in Extra View (bottom)', 'Navigate in the active tab of Extra View (bottom)', 'Open new tab in Extra View (left)', 'Open new background tab in Extra View (left)',
            'Navigate in the active tab of Extra View (left)', 'Open new tab in a priority view', 'Open new background tab in a priority view', 'Navigate in the active tab of a priority view',
            'New window', 'Properties', 'Copy path', 'Edit',
            'none'
        )
        WindowClose = @(
            'Close tab', 'Close window', 'Send to Task Tray', 'Close all but the active tab',
            'User command', 'none'
        )
        GroupMenu = @(
            'Default', 'Open in background', 'Replace', 'Open new tab in Extra View (bottom)',
            'Open new background tab in Extra View (bottom)', 'Replace in Extra View (bottom)', 'Open new tab in Extra View (left)', 'Open new background tab in Extra View (left)',
            'Replace in Extra View (left)', 'Open new tab in the other view', 'Open new background tab in the other view', 'Replace in the other view',
            'New window', 'none'
        )
        SubFolderMenu = @(
            'Open new tab', 'Open new background tab', 'Navigate in the active tab', 'Open new tab in Extra View (bottom)',
            'Open new background tab in Extra View (bottom)', 'Navigate in the active tab of Extra View (bottom)', 'Open new tab in Extra View (left)', 'Open new background tab in Extra View (left)',
            'Navigate in the active tab of Extra View (left)', 'Open new tab in the other view', 'Open new background tab in the other view', 'Navigate in the active tab of the other view',
            'New window', 'Copy', 'Cut', 'Paste Into',
            'Properties', 'Copy path', 'none'
        )
        PlusButton = @(
            'Browse folder and open new tab', 'Browse folder and open new tab in background', 'Open desktop', 'Open default tab',
            'Duplicate active tab', 'User command', 'none'
        )
    }

    # Fork settings schema: HKCU\Software\QTTabBar\Config\<Category> -> property:type, from the
    # Config._<Category> classes in QTTabBar\Config.cs. Registry kind: bool/int -> REG_DWORD,
    # string and enums -> REG_SZ (enum member name), everything else -> REG_SZ holding
    # DataContractJsonSerializer JSON.
    ForkSchema = @{
        Window = @(
            'CaptureNewWindows:bool', 'CaptureWeChatSelection:bool', 'RestoreSession:bool', 'RestoreOnlyLocked:bool',
            'CloseBtnClosesUnlocked:bool', 'CloseBtnClosesSingleTab:bool', 'TrayOnClose:bool', 'TrayOnMinimize:bool',
            'AutoHookWindow:bool', 'ShowFailNavMsg:bool', 'AutoEnableExperimental:bool', 'OpenExplorerMaximized:bool',
            'DefaultLocation:byte[]'
        )
        Tabs = @(
            'NewTabPosition:TabPos', 'NextAfterClosed:TabPos', 'ActivateNewTab:bool', 'NeverOpenSame:bool',
            'RenameAmbTabs:bool', 'DragOverTabOpensSDT:bool', 'ShowFolderIcon:bool', 'ShowSubDirTipOnTab:bool',
            'ShowDriveLetters:bool', 'ShowCloseButtons:bool', 'CloseBtnsWithAlt:bool', 'CloseBtnsOnHover:bool',
            'ShowNavButtons:bool', 'NavButtonsOnRight:bool', 'MultipleTabRows:bool', 'ActiveTabOnBottomRow:bool',
            'NeedPlusButton:bool'
        )
        Tweaks = @(
            'AlwaysShowHeaders:bool', 'KillExtWhileRenaming:bool', 'RedirectLibraryFolders:bool', 'F2Selection:bool',
            'WrapArrowKeySelection:bool', 'BackspaceUpLevel:bool', 'HorizontalScroll:bool', 'ForceSysListView:bool',
            'ToggleFullRowSelect:bool', 'DetailsGridLines:bool', 'AlternateRowColors:bool', 'AltRowBackgroundColor:Color',
            'AltRowForegroundColor:Color'
        )
        Tips = @(
            'ShowSubDirTips:bool', 'SubDirTipsPreview:bool', 'SubDirTipsFiles:bool', 'SubDirTipsWithShift:bool',
            'ShowTooltipPreviews:bool', 'ShowPreviewsWithShift:bool', 'ShowPreviewInfo:bool', 'PreviewMaxWidth:int',
            'PreviewMaxHeight:int', 'PreviewFont:Font', 'TextExt:List<string>', 'ImageExt:List<string>',
            'VideoExt:List<string>'
        )
        Misc = @(
            'TaskbarThumbnails:bool', 'KeepHistory:bool', 'TabHistoryCount:int', 'KeepRecentFiles:bool',
            'FileHistoryCount:int', 'NetworkTimeout:int', 'AutoUpdate:bool', 'SoundBox:bool',
            'EnableLog:bool'
        )
        Skin = @(
            'UseTabSkin:bool', 'TabImageFile:string', 'TabSizeMargin:Padding', 'TabContentMargin:Padding',
            'OverlapPixels:int', 'HitTestTransparent:bool', 'TabHeight:int', 'TabMinWidth:int',
            'TabMaxWidth:int', 'FixedWidthTabs:bool', 'TabTextFont:Font', 'ToolBarTextColor:Color',
            'TabTextActiveColor:Color', 'TabTextInactiveColor:Color', 'TabTextHotColor:Color', 'TabShadActiveColor:Color',
            'TabShadInactiveColor:Color', 'TabShadHotColor:Color', 'TabTitleShadows:bool', 'TabTextCentered:bool',
            'UseRebarBGColor:bool', 'RebarColor:Color', 'UseRebarImage:bool', 'RebarStretchMode:StretchMode',
            'RebarImageFile:string', 'RebarImageSeperateBars:bool', 'RebarSizeMargin:Padding', 'ActiveTabInBold:bool',
            'SkinAutoColorChangeClose:bool', 'DrawHorizontalExplorerBarBgColor:bool', 'DrawVerticalExplorerBarBgColor:bool',
            'TabTitleScroll:int'
        )
        BBar = @(
            'ButtonIndexes:int[]', 'ActivePluginIDs:string[]', 'LargeButtons:bool', 'LockSearchBarWidth:bool',
            'LockDropDownButtons:bool', 'ShowButtonLabels:bool', 'ImageStripPath:string', 'IconSize:int'
        )
        CmdBars = @(
            'SecondBarItems:CommandBarItem[]', 'SecondBarIconSize:int', 'SecondBarShowLabels:bool', 'VerticalBarItems:CommandBarItem[]',
            'VerticalBarIconSize:int', 'VerticalBarShowLabels:bool', 'VerticalBarVisible:bool', 'ClickActions:int[]',
            'MiddleClickActions:int[]'
        )
        Mouse = @(
            'MouseScrollsHotWnd:bool', 'GlobalMouseActions:Dictionary<MouseChord,BindAction>', 'TabActions:Dictionary<MouseChord,BindAction>', 'BarActions:Dictionary<MouseChord,BindAction>',
            'LinkActions:Dictionary<MouseChord,BindAction>', 'ItemActions:Dictionary<MouseChord,BindAction>', 'MarginActions:Dictionary<MouseChord,BindAction>'
        )
        Keys = @(
            'Shortcuts:int[]', 'PluginShortcuts:Dictionary<string,int[]>', 'UseTabSwitcher:bool'
        )
        Plugin = @(
            'Enabled:string[]'
        )
        Lang = @(
            'PluginLangFiles:string[]', 'UseLangFile:bool', 'LangFile:string', 'BuiltInLang:string',
            'BuiltInLangSelectedIndex:int'
        )
        Desktop = @(
            'FirstItem:int', 'SecondItem:int', 'ThirdItem:int', 'FourthItem:int',
            'GroupExpanded:bool', 'RecentTabExpanded:bool', 'ApplicationExpanded:bool', 'RecentFileExpanded:bool',
            'TaskBarDblClickEnabled:bool', 'DesktopDblClickEnabled:bool', 'LockMenu:bool', 'TitleBackground:bool',
            'IncludeGroup:bool', 'IncludeRecentTab:bool', 'IncludeApplication:bool', 'IncludeRecentFile:bool',
            'OneClickMenu:bool', 'EnableAppShortcuts:bool', 'Width:int', 'lstSelectedIndex:int'
        )
    }
    # Fork enums stored by member name (REG_SZ).
    ForkEnums = @{
        TabPos = @('Rightmost', 'Right', 'Left', 'Leftmost', 'LastActive')
        StretchMode = @('Full', 'Real', 'Tile')
    }
}
