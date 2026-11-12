//    This file is part of QTTabBar, a shell extension for Microsoft
//    Windows Explorer.
//    Copyright (C) 2007-2026  Quizo, Paul Accisano, indiff
//
//    QTTabBar is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    QTTabBar is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with QTTabBar.  If not, see <http://www.gnu.org/licenses/>.

using System;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using BandObjectLib;
using Microsoft.Win32;
using QTTabBarLib.DesktopMenuInterop;
using QTTabBarLib.Interop;

namespace QTTabBarLib {

    // The menu that a double-click on an empty spot of the desktop shows (QTDesktopTool).
    // QTDesktopTool used to run only as a taskbar toolbar, which the Windows 11 taskbar can't
    // host. Here it runs in the process that owns the desktop instead, with no toolbar:
    //  - The installer puts a .qtdesktop file into the Startup folder. Explorer opens it at
    //    sign-in, and the file type's open verb is DesktopMenuLoader, an in-process handler:
    //    that is how QTTabBar.dll gets into the desktop's process.
    //  - After Explorer was restarted, the first tabbed window that opens asks the desktop to
    //    open that file again (EnsureRunning).
    internal static class DesktopMenu {
        internal const string StartupFileName = "QTTabBar Desktop Menu.qtdesktop";
        private const string PropRunning = "QTTabBar_DesktopMenu";

        private static int started;         // in the desktop's process
        private static int askedFromHere;   // in any process

        // The process of the desktop window (Progman), which is Explorer's first process.
        internal static bool IsShellProcess() {
            IntPtr hwndShell = PInvoke.GetShellWindow();
            if(hwndShell == IntPtr.Zero) return false;
            uint pid;
            PInvoke.GetWindowThreadProcessId(hwndShell, out pid);
            return pid == PInvoke.GetCurrentProcessId();
        }

        internal static bool IsRunningInShell() {
            IntPtr hwndShell = PInvoke.GetShellWindow();
            return hwndShell != IntPtr.Zero && PInvoke.GetProp(hwndShell, PropRunning) != IntPtr.Zero;
        }

        // Runs the menu in this process, which must own the desktop. Once per process.
        internal static void StartHere() {
            if(Interlocked.Exchange(ref started, 1) != 0) return;
            Thread thread = new Thread(() => {
                try {
                    QTDesktopTool tool = new QTDesktopTool();
                    if(!tool.StartWithoutTaskbar()) {
                        tool.Dispose();
                        return;
                    }
                    Application.Run();
                }
                catch(Exception ex) {
                    QTUtility2.MakeErrorLog(ex, "DesktopMenu.StartHere");
                }
            }) { IsBackground = true, Name = "QTTabBar desktop menu" };
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();
        }

        internal static void MarkRunning(IntPtr hwnd) {
            IntPtr hwndShell = PInvoke.GetShellWindow();
            if(hwndShell != IntPtr.Zero) PInvoke.SetProp(hwndShell, PropRunning, hwnd);
        }

        internal static void UnmarkRunning() {
            IntPtr hwndShell = PInvoke.GetShellWindow();
            if(hwndShell != IntPtr.Zero) PInvoke.RemoveProp(hwndShell, PropRunning);
        }

        // The Startup file, if it is there and not turned off in Task Manager's Startup apps.
        internal static string FindStartupFile() {
            foreach(Environment.SpecialFolder folder in new[] { Environment.SpecialFolder.CommonStartup, Environment.SpecialFolder.Startup }) {
                string path;
                try {
                    path = Path.Combine(Environment.GetFolderPath(folder), StartupFileName);
                }
                catch {
                    continue;
                }
                if(File.Exists(path) && !IsTurnedOffAtStartup(StartupFileName)) return path;
            }
            return null;
        }

        // Task Manager keeps its on/off switch in StartupApproved: an odd first byte means off.
        private static bool IsTurnedOffAtStartup(string name) {
            string[] keys = {
                @"Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder",
                @"Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\CommonStartupFolder"
            };
            foreach(RegistryKey root in new[] { Registry.CurrentUser, Registry.LocalMachine }) {
                foreach(string key in keys) {
                    try {
                        using(RegistryKey rk = root.OpenSubKey(key)) {
                            byte[] data = rk == null ? null : rk.GetValue(name) as byte[];
                            if(data != null && data.Length > 0 && (data[0] & 1) != 0) return true;
                        }
                    }
                    catch {
                    }
                }
            }
            return false;
        }

        // Called when a tabbed window opens, in any Explorer process. If the desktop has no menu,
        // as after Explorer was restarted, the desktop opens the Startup file again.
        internal static void EnsureRunning() {
            try {
                if(IsRunningInShell() || Interlocked.Exchange(ref askedFromHere, 1) != 0) return;
                if(IsShellProcess()) {
                    if(FindStartupFile() != null) StartHere();
                    return;
                }
                Thread thread = new Thread(() => {
                    try {
                        string path = FindStartupFile();
                        if(path != null && !IsRunningInShell()) AskShellToOpen(path);
                    }
                    catch(Exception ex) {
                        QTUtility2.MakeErrorLog(ex, "DesktopMenu.EnsureRunning");
                    }
                }) { IsBackground = true };
                thread.SetApartmentState(ApartmentState.STA);
                thread.Start();
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "DesktopMenu.EnsureRunning");
            }
        }

        // Opens a file from inside the desktop's process: the desktop's folder view hands out
        // a Shell.Application object that lives there, and its ShellExecute runs there.
        internal static bool AskShellToOpen(string path) {
            const int SWC_DESKTOP = 0x00000008;
            const int SWFO_NEEDDISPATCH = 0x00000001;
            const uint SVGIO_BACKGROUND = 0;
            const int SW_SHOWNORMAL = 1;
            Guid SID_STopLevelBrowser = new Guid("4C96BE40-915C-11CF-99D3-00AA004AE837");
            Guid IID_IDispatch = new Guid("00020400-0000-0000-C000-000000000046");

            SHDocVw.ShellWindows shellWindows = null;
            object desktop = null, browser = null, view = null, app = null;
            IShellView shellView = null;
            try {
                shellWindows = new SHDocVw.ShellWindows();
                object loc = null, locRoot = null;
                int hwnd;
                desktop = shellWindows.FindWindowSW(ref loc, ref locRoot, SWC_DESKTOP, out hwnd, SWFO_NEEDDISPATCH);
                _IServiceProvider sp = desktop as _IServiceProvider;
                if(sp == null) return false;
                sp.QueryService(SID_STopLevelBrowser, typeof(IShellBrowser).GUID, out browser);
                IShellBrowser shellBrowser = browser as IShellBrowser;
                if(shellBrowser == null || shellBrowser.QueryActiveShellView(out shellView) != 0 || shellView == null) return false;
                if(shellView.GetItemObject(SVGIO_BACKGROUND, ref IID_IDispatch, out view) != 0 || view == null) return false;
                app = view.GetType().InvokeMember("Application", BindingFlags.GetProperty, null, view, null);
                if(app == null) return false;
                app.GetType().InvokeMember("ShellExecute", BindingFlags.InvokeMethod, null, app,
                        new object[] { path, "", Path.GetDirectoryName(path) ?? "", "open", SW_SHOWNORMAL });
                QTUtility2.log("DesktopMenu: asked the desktop to open " + Path.GetFileName(path));
                return true;
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "DesktopMenu.AskShellToOpen");
                return false;
            }
            finally {
                foreach(object o in new[] { app, view, shellView, browser, desktop, shellWindows }) {
                    if(o != null && Marshal.IsComObject(o)) Marshal.ReleaseComObject(o);
                }
            }
        }
    }

    // The open verb of .qtdesktop files (DelegateExecute). In the desktop's process it starts
    // the menu; anywhere else it asks the desktop to open the file.
    [ComVisible(true)]
    [Guid("8E247F31-752A-443B-8CA3-2CD5AA0B097C")]
    [ClassInterface(ClassInterfaceType.None)]
    public sealed class DesktopMenuLoader : IExecuteCommand, IObjectWithSelection {
        private const int S_OK = 0;
        private const int E_NOTIMPL = unchecked((int)0x80004001);
        private const uint SIGDN_FILESYSPATH = 0x80058000;
        private string path;

        public int SetKeyState(uint grfKeyState) { return S_OK; }
        public int SetParameters(string pszParameters) { return S_OK; }
        public int SetPosition(EXECUTECOMMAND_POINT pt) { return S_OK; }
        public int SetShowWindow(int nShow) { return S_OK; }
        public int SetNoShowUI(bool fNoShowUI) { return S_OK; }
        public int SetDirectory(string pszDirectory) { return S_OK; }

        public int Execute() {
            try {
                if(DesktopMenu.IsShellProcess()) {
                    QTUtility2.log("DesktopMenuLoader: starting the desktop menu");
                    DesktopMenu.StartHere();
                }
                else if(!DesktopMenu.IsRunningInShell()) {
                    string target = path ?? DesktopMenu.FindStartupFile();
                    if(target != null) DesktopMenu.AskShellToOpen(target);
                }
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "DesktopMenuLoader.Execute");
            }
            return S_OK;
        }

        public int SetSelection(IShellItemArray psia) {
            path = null;
            try {
                IShellItem item;
                if(psia != null && psia.GetItemAt(0, out item) == 0 && item != null) {
                    string name;
                    if(item.GetDisplayName(SIGDN_FILESYSPATH, out name) == 0) path = name;
                    Marshal.ReleaseComObject(item);
                }
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "DesktopMenuLoader.SetSelection");
            }
            return S_OK;
        }

        public int GetSelection(ref Guid riid, out IntPtr ppv) {
            ppv = IntPtr.Zero;
            return E_NOTIMPL;
        }
    }
}

namespace QTTabBarLib.DesktopMenuInterop {
    // IShellItem is QTTabBarLib.Interop.IShellItem.
    [StructLayout(LayoutKind.Sequential)]
    public struct EXECUTECOMMAND_POINT {
        public int x;
        public int y;
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("7F9185B0-CB92-43C5-80A9-92277A4F7B54")]
    public interface IExecuteCommand {
        [PreserveSig] int SetKeyState(uint grfKeyState);
        [PreserveSig] int SetParameters([MarshalAs(UnmanagedType.LPWStr)] string pszParameters);
        [PreserveSig] int SetPosition(EXECUTECOMMAND_POINT pt);
        [PreserveSig] int SetShowWindow(int nShow);
        [PreserveSig] int SetNoShowUI([MarshalAs(UnmanagedType.Bool)] bool fNoShowUI);
        [PreserveSig] int SetDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDirectory);
        [PreserveSig] int Execute();
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("1C9CD5BB-98E9-4491-A60F-31AACC72B83C")]
    public interface IObjectWithSelection {
        [PreserveSig] int SetSelection(IShellItemArray psia);
        [PreserveSig] int GetSelection(ref Guid riid, out IntPtr ppv);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("B63EA76D-1F85-456F-A19C-48159EFA858B")]
    public interface IShellItemArray {
        [PreserveSig] int BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppvOut);
        [PreserveSig] int GetPropertyStore(int flags, ref Guid riid, out IntPtr ppv);
        [PreserveSig] int GetPropertyDescriptionList(IntPtr keyType, ref Guid riid, out IntPtr ppv);
        [PreserveSig] int GetAttributes(int dwAttribFlags, uint sfgaoMask, out uint psfgaoAttribs);
        [PreserveSig] int GetCount(out uint pdwNumItems);
        [PreserveSig] int GetItemAt(uint dwIndex, out QTTabBarLib.Interop.IShellItem ppsi);
        [PreserveSig] int EnumItems(out IntPtr ppenumShellItems);
    }
}
