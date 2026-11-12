> **Unofficial fork.** This is a fork of [indiff/qttabbar](https://github.com/indiff/qttabbar) that brings the full tab bar back on Windows 11 26H2 and adds features from QTTabBar 2048 Beta2. It is not affiliated with or endorsed by Quizo, Paul Accisano, indiff or any other QTTabBar author, so please don't report problems with this fork upstream. Everything below [About this fork](#about-this-fork) is the upstream README: its links, badges and downloads point to upstream, not to this fork.

## About this fork

Tested on Windows 11 Pro 26H2, build 26300.9711. Other builds may behave differently.

### What this fork changes

- **Full tab bar on Windows 11.** Tab features depend on whether the tab bar is docked, not on the Windows version. Fixes for Explorer crashes with many windows, windows that stayed hidden, and middle clicks that closed a window.
- **Second and vertical command bars** for folders, files, programs and groups, with child menus, drag and drop, and custom icons.
- **Command bar icon sizes in pixels.** 8-48 px for the first bar (Options > Button Bar), 8-256 px for the other two (right-click the bar > Icon size).
- **Mouse and keyboard.** 2048-style folder double-clicks, Select all and the shortcuts 2048 had. The mouse side buttons now act once per press, which keeps the back/forward history correct.
- **History.** Up to 128 closed tabs and recent files.
- **Tabs.** Long titles can scroll through the tab. Start-up tabs on network shares that don't answer no longer hold the window up.
- **One window.** A folder that another program opens becomes a tab in the window you used last, also when Explorer gives it a process of its own. Before, such a folder got a window of its own with all the tabs of your last session in it.
- **Tabs between windows.** Drag a tab out of its window to give it a window of its own, or drop it on another tabbed window to move it there.
- **Control Panel.** Explorer replaces a folder window that is sent to a Control Panel page, and its tabs used to go with it. Now the tabs come back in a new window in the same place, and the Control Panel window moves aside.
- **Desktop menu.** A click on an empty spot of the desktop opens a menu of recently closed folders, recent files, applications and groups, as in 2048. A double-click by default; one click is in the menu's own settings (*Desktop menu settings* at its end), and the 2048 settings converter takes it over. No taskbar toolbar is needed: Explorer starts the menu at sign-in from the Startup folder entry *QTTabBar Desktop Menu*. Folders from the menu open as tabs in the window you used last. The *QTTab Desktop Tool* toolbar of a Windows 10 style taskbar loads again too: the installer had registered it under a class name that doesn't exist.
- **Version.** Builds of this fork carry upstream's version and this fork's id, like `1.6.4-26h2.4`. Options, About, Programs and Features and the DLL's details show it.
- **Button images.** Reads QTTabBar 1.x and 2048 image strips.
- **Japanese UI.** A built-in Japanese language (Options > Language).
- **Tools.** `QTTabBarDoctor` diagnoses an install, repairs it and exports or imports settings. `Win11ToolbarFix` restores the classic toolbar. `Import-QTTabBar2048Settings` converts 2048 settings. `Tools\Kit` packs an installer and guide for setting up another PC.

### Install on Windows 11 26H2

A step-by-step guide in Japanese is in [README_ja.md](README_ja.md).

1. Uninstall any other version of QTTabBar. If you want to keep 2048 settings, export them first.
   Download the MSI and **Source code (zip)** from Releases, unblock both (right-click > Properties > Unblock), and extract the zip.
2. In an elevated PowerShell, apply the toolbar fix, then restart Windows. Read [the section below](#before-you-run-win11toolbarfix) first.

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Tools\Win11ToolbarFix\Win11ToolbarFix.ps1 -Action InstallTask
   ```

3. Double-click the MSI. After the UAC prompt, Setup closes all File Explorer windows and restarts Explorer, so wait for any file copies to finish first. On the last page, leave the option ticked and click Finish. A window with your saved tabs opens.
4. Turn the bars on as described in [Getting the full tab bar back](#getting-the-full-tab-bar-back-on-windows-11-24h2--25h2--26h2).
5. Run `QTTabBarDoctor.ps1` with no arguments. It should end with `Result: nothing wrong found.` If it doesn't, run this in a normal PowerShell. It reinstalls the MSI with Explorer closed, and there is one UAC prompt.

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Tools\QTTabBarDoctor\QTTabBarDoctor.ps1 -Action Repair -Msi "C:\path\to\QTTabBar-Setup-1.6.4.msi"
   ```

### Before you run Win11ToolbarFix

This script changes system-wide Windows settings. Use it at your own risk, and create a restore point first.

- It needs administrator rights. It backs up, then deletes, the feature overrides that remove the classic toolbar (under `HKLM\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides`), and writes "disabled" overrides in their place.
- `-Action InstallTask` also copies the script to Program Files and registers a startup task that runs as SYSTEM, because a cumulative update can put the overrides back.
- `-Action Restore` puts back what was backed up and removes the task. Restart Windows after either action.
- Modes larger than the default `Minimal` disable more feature bundles. Disabling 57048216 has been reported to hide the Widgets button.
- Microsoft doesn't support this, and a future Windows update may stop it working.

### Moving settings from QTTabBar 2048 Beta2

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\Import2048Settings\Import-QTTabBar2048Settings.ps1 -XmlPath C:\path\to\export.xml
```

This shows what would be converted and what can't be. Add `-Apply` to write the settings, then sign out and back in before opening QTTabBar's options.

QTTabBar 2048 is a separate closed-source program and isn't part of this project. The converter contains interoperability data needed to read your own settings export (setting names, value ranges, defaults and option labels). This fork contains no 2048 code, binaries or images.

### Known limitations

- The installer is unsigned, so Windows may show a SmartScreen warning.
- Selecting a tab on a network share that doesn't answer still waits for the Windows timeout (about 5 seconds).
- The window that comes back after a Control Panel page has the same tabs in the same order, but not their back/forward history. A window with a single tab is replaced by the Control Panel window, as Explorer does on its own.
- A tab can't be dragged out of a maximized window on a single screen: there is nowhere outside the window to drop it.
- The desktop menu starts at sign-in. After Explorer is restarted (the installer does that), it comes back when the next tabbed window opens. To turn it off, switch off *QTTabBar Desktop Menu* in Task Manager > Startup apps.
- A double-click on the taskbar opens the desktop menu only on the taskbar's edge, not on its empty space.
- Text added by this fork is in English and Japanese only.
- Some plugin names and descriptions are in Chinese, as upstream wrote them.

### Building this fork

```powershell
.\Installer\Build-Installer.ps1 -Version 1.6.4 -ForkId 26h2.4
```

This builds `QTTabBar Setup 1.6.4-26h2.4.msi`. `-Version` is upstream's version and `-ForkId` this fork's id, whose last number becomes the fourth part of the file and MSI versions (1.6.4.4). The assembly version stays 1.6.4.0, because COM registration, the GAC and plugins bind to it. `-PlatformToolset` and `-WixDir` select a newer VC toolset and a portable WiX. See [Build](#build) below for the requirements.

### License and credits

GPL v3, see [LICENSE.txt](LICENSE.txt). There is no warranty. This fork is built on the work of Quizo, Paul Accisano, indiff and the other QTTabBar contributors. It modifies upstream commit `9b81f72`; the changes date from October 2026 and `git log 9b81f72..` lists them. MinHook and the Windows API Code Pack remain under their own licenses.

---

- [QTTabBar Document](https://www.yuque.com/indiff/qttabbar/zqtdig)
- [汉化GitHub modify by indiff](https://openuserjs.org/scripts/indiff/GitHub_%E6%B1%89%E5%8C%96%E6%8F%92%E4%BB%B6_(indiff)%E4%BF%AE%E6%94%B9)
- [Generate chm db document(Support Group By Module) modify by indiff](https://github.com/indiff/DBCHM)

[![Download sf qttabbar2](https://img.shields.io/sourceforge/dt/qttabbar2.svg)](https://sourceforge.net/projects/qttabbar2/files)
[![GitHub all releases](https://img.shields.io/github/downloads/indiff/qttabbar/total)](https://github.com/indiff/qttabbar/releases)
[![Github Stars](https://img.shields.io/github/stars/indiff/qttabbar?logo=github)](https://github.com/indiff/qttabbar)
[![Gitee Stars](https://gitee.com/qwop/qttabbar/badge/star.svg)](https://gitee.com/qwop/qttabbar)
[![.NET Framework 4.8](https://img.shields.io/badge/.NET-4.8-blue.svg)](https://dotnet.microsoft.com/download/dotnet-framework/net48)

QTTabBar adds tabbed browsing and other enhancements to Windows Explorer. updated for .NET 4.8 and modern Windows.


![qttabbar2](https://user-images.githubusercontent.com/501276/131287626-fe8f1fdd-a894-43f8-9620-b7145d70936d.gif)

1. Qttabbar domestic optimized version is based on sf.net/projects/qttabbar/ (2012-06-17). The original author of this version has not released it. I don't know why. Adding some Chinese features is mainly for the convenience of domestic users; in addition, the capture window of quizo official website maintained by Japanese authors is not used to all the time, so this version retains the easy-to-use function of capture window.
2. Qttabbar is a small tool that allows you to use tab multi label function in Windows Explorer. Since then, there are no windows folder and awesome folder preview functions, which greatly improves the efficiency of your work. It's like IE 7, and it's like Firefox and opera. Qttabbar also provides some plug-ins, such as file operation tool, tree directory, display status bar and so on.
3. [Install qttabbar Windows11](https://github.com/indiff/qttabbar/wiki/Windows11%E5%AE%89%E8%A3%85qttabbar)
4. [Dark Mode for Windows11](https://github.com/StickySli/qttabbar-dark-mode-skin)
- [GitHub Mirror](https://indiff.github.io/qttabbar)
- [Gitee Mirror](https://gitee.com/qwop/qttabbar)
- [SourceForge Mirror](https://sourceforge.net/projects/qttabbar2/)
## Changes

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

## Download

* [qttabbar Latest version](https://github.com/indiff/qttabbar/releases)
* [qttabbar Chinese mirror](https://gitee.com/qwop/qttabbar/releases)
* [![Download qttabbar2](https://a.fsdn.com/con/app/sf-download-button)](https://sourceforge.net/projects/qttabbar2/files/latest/download)

## Installation

1. Run `QTTabBar Setup.exe` — it will install .NET Framework 4.8 automatically if not present
2. After installation, open a File Explorer window
3. Activate QTTabBar — the steps differ by Windows version (see below)

### Activating on Windows 10

Explorer still has a classic toolbar, so enable the bands the normal way: right-click an empty part of the toolbar area (or use **View → Options**) and tick **QTTabBar** and **QT ButtonBar**. This gives the full experience, including QTTabBar's own tab bar.

### Activating on Windows 11

Current Windows 11 builds hide the classic Explorer toolbar, so there's no toolbar menu to enable QTTabBar through. You can either bring the toolbar back and get the full tab bar (see [the next section](#getting-the-full-tab-bar-back-on-windows-11-24h2--25h2--26h2)), or turn on the auto-attach option for a reduced feature set:

1. Right-click an empty area inside any folder and choose **QTTabBar Options**.
2. On the **Window** tab, tick **“Enable QTTabBar on every Explorer window (experimental, must restart Explorer)”**.
3. Click **OK**, then restart Explorer — either sign out and back in, or open Task Manager, find **Windows Explorer**, and click **Restart**.

![QTTabBar Options — Enable QTTabBar on every Explorer window](docs/images/win11-enable-on-every-window.png)

On Windows 11, QTTabBar works alongside Explorer's own native tabs rather than showing its own tab bar. Once enabled you get:

- **Double-click** an empty area of a folder to go up one level
- **Hover previews** of text files and photos/media files

### Getting the full tab bar back on Windows 11 24H2 / 25H2 / 26H2

Explorer still contains the classic toolbar; recent cumulative updates switch it off with feature overrides stored at *ImageOverride* priority, which `ViVeTool /disable` can no longer beat. `Tools\Win11ToolbarFix\Win11ToolbarFix.ps1` removes those overrides (backing them up first) and writes user-priority "disabled" overrides in their place:

```powershell
# elevated PowerShell
powershell -ExecutionPolicy Bypass -File .\Tools\Win11ToolbarFix\Win11ToolbarFix.ps1 -Action Status
powershell -ExecutionPolicy Bypass -File .\Tools\Win11ToolbarFix\Win11ToolbarFix.ps1 -Action Apply
# optional: re-apply automatically at startup after a cumulative update puts the overrides back
powershell -ExecutionPolicy Bypass -File .\Tools\Win11ToolbarFix\Win11ToolbarFix.ps1 -Action InstallTask
```

`-Mode` picks which feature bundles to disable: `Minimal` (default, 57048237 only - its child bundles such as 58988972 follow it), `Pair` (adds 57048216), `Full` (adds 58988972 explicitly) or `Extended` (adds 57048218/26/31). `Minimal` and `Pair` were both verified on 26300.9711, with ExplorerPatcher's ribbon and with the default Windows 11 UI; try a larger mode only if the bars still don't appear. Restart Windows afterwards (the override store is only read at boot), then turn the bars on: with ExplorerPatcher's Windows 10 ribbon, **View** tab > **Options** (arrow) > **QTTabBar** and **QTTab Standard Buttons**. With the tab bar docked, QTTabBar behaves as on Windows 10 (shortcuts, capturing new windows into tabs, its own back/forward). `-Action Restore` puts the original overrides back. Leave "Enable QTTabBar on every Explorer window" off in this setup - it is only for windows without the toolbar.

Error logs are written to `%APPDATA%\QTTabBar\QTTabBarException.log`.

## Build

**Requirements:**
- Visual Studio 2022
- [WiX Toolset v3.14](https://github.com/wixtoolset/wix3/releases) (command-line tools)
- [NotifyPropertyWeaver](https://github.com/SimonCropp/NotifyPropertyWeaver) (included in `Tools\`)

**Day-to-day code changes** (no installer needed):

```powershell
msbuild QTTabBar\QTTabBar.csproj /p:Configuration=Release /p:SolutionDir="$pwd\\"
```

**Cutting a versioned release installer:**

```powershell
.\Installer\Build-Installer.ps1 -Version 1.5.6.4
```

This is the *only* place the version number needs to be typed — the script stamps it into `AssemblyInfo.cs`, `Installer.wxs`, and `Bundle.wxs`, then builds the DLL, MSI, and bootstrapper. (`QTUtility.CurrentVersion`, shown in the About tab, reads the version from the built assembly at runtime instead of being hardcoded separately.)

Output: `Installer\bin\Release\QTTabBar Setup <version>.exe` (bootstrapper with embedded MSI)

# QQ Group
* Group: [157604022](https://qm.qq.com/cgi-bin/qm/qr?k=fPZlN22xK_Y7NU60ZGMm8gIjH_u_8PVE&jump_from=webapi)
* Group2: [963211351](https://jq.qq.com/?_wv=1027&k=VCPD2zLH)

## Thanks

* [Original author Quizo](https://twitter.com/QTTabBar)
* [indiff](https://github.com/indiff/qttabbar) — upstream fork maintainer
* [SF Version Author](https://sourceforge.net/u/masamunexgp/profile)
* [Donation List](https://github.com/indiff/qttabbar/wiki/Thanks-%E9%B8%A3%E8%B0%A2%E6%8D%90%E5%8A%A9)
* [Donation](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=7YNCVL5P9ZDY8)
* Recruit volunteers for a long time and send an email to indiff@126.com Or add wechat adgmtt
# Thanks for free JetBrains Open Source license

<a href="https://www.jetbrains.com/?from=QtTabBar" target="_blank">
<img src="https://user-images.githubusercontent.com/501276/128459507-b98484a4-f20d-4224-80e3-d16886ea9365.png" height="200"/></a>

# Wechat Group
<table>
    <tr>
        <td>Invitation to wechat group</td>
        <td><img src="https://user-images.githubusercontent.com/501276/141719517-a6f28c27-3d8b-4b35-87f3-0c326789745e.jpg" width="120"/></td>
    </tr>
</table>
