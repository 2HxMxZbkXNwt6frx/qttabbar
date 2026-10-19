//    This file is part of QTTabBar, a shell extension for Microsoft
//    Windows Explorer.
//    Copyright (C) 2007-2021  Quizo, Paul Accisano
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
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;
using QTTabBarLib.Interop;

namespace QTTabBarLib {

    // The second command bar: a toolbar band (enabled like QTTabBar from View > Options or the
    // toolbar menu) holding user buttons. New CLSID; 2048 Beta2's bars used other classes.
    [ComVisible(true), Guid("0215a1de-3818-44d4-a134-a44676cb5faf")]
    public sealed class QTCommandBar2 : CommandBarBand {
        internal const string MenuName = "QTTab Command Bar 2";

        protected override bool IsVerticalBar { get { return false; } }
        protected override CommandBarItem[] Items {
            get { return Config.CmdBars.SecondBarItems; }
            set { Config.CmdBars.SecondBarItems = value; }
        }
        protected override int IconSize {
            get { return Config.CmdBars.SecondBarIconSize; }
            set { Config.CmdBars.SecondBarIconSize = value; }
        }
        protected override bool ShowLabels {
            get { return Config.CmdBars.SecondBarShowLabels; }
            set { Config.CmdBars.SecondBarShowLabels = value; }
        }

        // regasm (Register.bat) only; the installer writes the same entries.
        [ComRegisterFunction]
        private static void Register(Type t) {
            string name = t.GUID.ToString("B");
            using(RegistryKey key = Registry.ClassesRoot.CreateSubKey(@"CLSID\" + name)) {
                key.SetValue(null, MenuName);
                key.SetValue("MenuText", MenuName);
                key.SetValue("HelpText", MenuName);
            }
            using(RegistryKey key = Registry.LocalMachine.CreateSubKey(@"Software\Microsoft\Internet Explorer\Toolbar")) {
                key.SetValue(name, "QTCommandBar2");
            }
        }

        [ComUnregisterFunction]
        private static void Unregister(Type t) {
            string name = t.GUID.ToString("B");
            try {
                using(RegistryKey key = Registry.LocalMachine.CreateSubKey(@"Software\Microsoft\Internet Explorer\Toolbar")) {
                    key.DeleteValue(name, false);
                }
                Registry.ClassesRoot.DeleteSubKeyTree(@"CLSID\" + name, false);
            }
            catch {
            }
        }
    }

    // The vertical command bar: an Explorer bar on the left of the window (CATID_InfoBand),
    // showing the same kind of buttons in a column.
    [ComVisible(true), Guid("b29f2c4b-67b6-4abf-97c4-2e10c4a06fb9")]
    public sealed class QTCommandBarVertical : CommandBarBand {
        internal const string MenuName = "QTTab Vertical Command Bar";

        protected override bool IsVerticalBar { get { return true; } }
        protected override CommandBarItem[] Items {
            get { return Config.CmdBars.VerticalBarItems; }
            set { Config.CmdBars.VerticalBarItems = value; }
        }
        protected override int IconSize {
            get { return Config.CmdBars.VerticalBarIconSize; }
            set { Config.CmdBars.VerticalBarIconSize = value; }
        }
        protected override bool ShowLabels {
            get { return Config.CmdBars.VerticalBarShowLabels; }
            set { Config.CmdBars.VerticalBarShowLabels = value; }
        }

        // Remember whether the user wants the bar, so new windows show it (QTTabBarClass asks
        // Explorer to, see ShowInWindow). Hiding also happens when the window closes; that must not
        // count, so a hide only counts if the window is still there a moment later.
        public override void ShowDW(bool fShow) {
            base.ShowDW(fShow);
            if(fShow) {
                SetVisibleSetting(true);
                return;
            }
            IntPtr frame = FrameHandle;
            Timer timer = new Timer { Interval = 1000 };
            timer.Tick += (sender, e) => {
                timer.Stop();
                timer.Dispose();
                if(!IsDisposed && frame != IntPtr.Zero && PInvoke.IsWindow(frame) && PInvoke.IsWindowVisible(frame) && !Visible) {
                    SetVisibleSetting(false);
                }
            };
            timer.Start();
        }

        private static void SetVisibleSetting(bool visible) {
            if(Config.CmdBars.VerticalBarVisible == visible) return;
            Config.CmdBars.VerticalBarVisible = visible;
            ConfigManager.WriteConfig();
        }

        // Shows the bar in a window (no-op when it is already shown).
        internal static void ShowInWindow(SHDocVw.WebBrowserClass explorer) {
            try {
                object clsid = typeof(QTCommandBarVertical).GUID.ToString("B");
                object show = true;
                object size = null;
                explorer.ShowBrowserBar(ref clsid, ref show, ref size);
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "QTCommandBarVertical.ShowInWindow");
            }
        }

        [ComRegisterFunction]
        private static void Register(Type t) {
            string name = t.GUID.ToString("B");
            using(RegistryKey key = Registry.ClassesRoot.CreateSubKey(@"CLSID\" + name)) {
                key.SetValue(null, MenuName);
                key.SetValue("MenuText", MenuName);
                key.SetValue("HelpText", MenuName);
                key.CreateSubKey(@"Implemented Categories\{00021493-0000-0000-C000-000000000046}").Close();   // CATID_InfoBand
            }
        }

        private static bool categoryCacheChecked;

        // Explorer keeps a per-user cache of the vertical Explorer bars it found; one written before
        // this bar was installed hides it (ShowBrowserBar succeeds but nothing appears). Drop such a
        // cache so Explorer enumerates again. Called once per process by AutoLoader.
        internal static void EnsureExplorerBarCacheIncludesThis() {
            if(categoryCacheChecked) return;
            categoryCacheChecked = true;
            byte[] clsid = typeof(QTCommandBarVertical).GUID.ToByteArray();
            const string root = @"Software\Microsoft\Windows\CurrentVersion\Explorer\Discardable\PostSetup\";
            const string infoBand = @"\{00021493-0000-0000-C000-000000000046}";
            foreach(string cache in new[] { "Component Categories", "Component Categories64" }) {
                try {
                    bool stale;
                    using(RegistryKey key = Registry.CurrentUser.OpenSubKey(root + cache + infoBand + @"\Enum")) {
                        if(key == null) continue;
                        byte[] listed = key.GetValue("Implementing") as byte[];
                        stale = listed == null || IndexOf(listed, clsid) < 0;
                    }
                    if(stale) Registry.CurrentUser.DeleteSubKeyTree(root + cache + infoBand, false);
                }
                catch(Exception ex) {
                    QTUtility2.MakeErrorLog(ex, "EnsureExplorerBarCacheIncludesThis");
                }
            }
        }

        private static int IndexOf(byte[] haystack, byte[] needle) {
            for(int i = 0; i + needle.Length <= haystack.Length; i++) {
                int j = 0;
                while(j < needle.Length && haystack[i + j] == needle[j]) j++;
                if(j == needle.Length) return i;
            }
            return -1;
        }

        [ComUnregisterFunction]
        private static void Unregister(Type t) {
            try {
                Registry.ClassesRoot.DeleteSubKeyTree(@"CLSID\" + t.GUID.ToString("B"), false);
            }
            catch {
            }
        }
    }
}
