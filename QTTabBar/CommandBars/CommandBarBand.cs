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
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Media;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Windows.Forms.VisualStyles;
using BandObjectLib;
using QTTabBarLib.Interop;

namespace QTTabBarLib {

    // A bar of user buttons (folders, files, programs, groups) shared by the second command bar
    // (a toolbar band) and the vertical command bar (a pane on the left of the window). The items
    // live in Config.CmdBars; every open window's bar is rebuilt when they change. Clicks follow
    // 2048 Beta2's command bar buttons (Config.CmdBars.ClickActions / MiddleClickActions).
    [ComVisible(false)]
    public abstract class CommandBarBand : BandObject {
        private static readonly List<CommandBarBand> liveBars = new List<CommandBarBand>();

        // Values of the click tables (2048 Beta2's numbering). 2048's 3..11 were the first three
        // in its extra views; here they act like 0..2.
        private const int ActNone = -1;
        private const int ActNewTab = 0;
        private const int ActBackgroundTab = 1;
        private const int ActThisTab = 2;
        private const int ActNewWindow = 12;
        private const int ActProperties = 13;
        private const int ActCopyPath = 14;
        private const int ActEdit = 15;

        private readonly ToolStrip toolStrip;
        private readonly ContextMenuStripEx barMenu;
        private int menuItemIndex = -1;   // item the context menu was opened on, -1 for the bar
        private IContainer components;

        protected abstract bool IsVerticalBar { get; }
        protected abstract CommandBarItem[] Items { get; set; }
        protected abstract int IconSize { get; set; }
        protected abstract bool ShowLabels { get; set; }

        protected CommandBarBand() {
            components = new Container();
            toolStrip = new ToolStrip {
                Dock = DockStyle.Fill,
                GripStyle = ToolStripGripStyle.Hidden,
                ImeMode = ImeMode.Disable,
                Renderer = new ToolbarRenderer(),
                BackColor = Color.Transparent,
                ShowItemToolTips = true,
                LayoutStyle = IsVerticalBar ? ToolStripLayoutStyle.VerticalStackWithOverflow : ToolStripLayoutStyle.HorizontalStackWithOverflow,
                Padding = IsVerticalBar ? new Padding(2, 4, 2, 4) : new Padding(2, 0, 2, 0),
            };
            toolStrip.KeyDown += toolStrip_KeyDown;
            barMenu = new ContextMenuStripEx(components, false);
            barMenu.Opening += barMenu_Opening;
            SuspendLayout();
            Controls.Add(toolStrip);
            MinSize = new Size(24, 24);
            ResumeLayout(false);
        }

        // ---------------------------------------------------------------- band lifecycle

        // The Explorer window (CabinetWClass) this bar belongs to.
        protected IntPtr FrameHandle { get; private set; }

        protected override void OnExplorerAttached() {
            try {
                if(Explorer != null) FrameHandle = (IntPtr)Explorer.HWND;
            }
            catch {
            }
            lock(liveBars) liveBars.Add(this);
            Rebuild();
        }

        public override void CloseDW(uint dwReserved) {
            lock(liveBars) liveBars.Remove(this);
            ClearItems();
            base.CloseDW(dwReserved);
        }

        protected override void Dispose(bool disposing) {
            if(disposing) {
                lock(liveBars) liveBars.Remove(this);
                ClearItems();
                if(components != null) components.Dispose();
            }
            base.Dispose(disposing);
        }

        public override void GetBandInfo(uint dwBandID, uint dwViewMode, ref DESKBANDINFO dbi) {
            base.GetBandInfo(dwBandID, dwViewMode, ref dbi);
            Size pref = toolStrip.GetPreferredSize(Size.Empty);
            if(IsVerticalBar) {
                int width = Math.Max(pref.Width, IconSize + 12);
                if((dbi.dwMask & DBIM.ACTUAL) != 0) {
                    dbi.ptActual.X = width;
                    dbi.ptActual.Y = Size.Height;
                }
                if((dbi.dwMask & DBIM.MINSIZE) != 0) {
                    dbi.ptMinSize.X = IconSize + 12;
                    dbi.ptMinSize.Y = IconSize + 12;
                }
                if((dbi.dwMask & DBIM.INTEGRAL) != 0) {
                    dbi.ptIntegral.X = 1;
                    dbi.ptIntegral.Y = 1;
                }
                if((dbi.dwMask & DBIM.MODEFLAGS) != 0) {
                    dbi.dwModeFlags = DBIMF.VARIABLEHEIGHT | DBIMF.NOMARGINS;
                }
            }
            else {
                int height = BarHeight;
                if((dbi.dwMask & DBIM.ACTUAL) != 0) {
                    dbi.ptActual.X = Math.Max(pref.Width, MinSize.Width);
                    dbi.ptActual.Y = height;
                }
                if((dbi.dwMask & DBIM.INTEGRAL) != 0) {
                    dbi.ptIntegral.X = -1;
                    dbi.ptIntegral.Y = 10;
                }
                if((dbi.dwMask & DBIM.MAXSIZE) != 0) {
                    dbi.ptMaxSize.X = -1;
                    dbi.ptMaxSize.Y = height;
                }
                if((dbi.dwMask & DBIM.MINSIZE) != 0) {
                    dbi.ptMinSize.X = MinSize.Width;
                    dbi.ptMinSize.Y = height;
                }
            }
        }

        // The horizontal bar sits on the toolbar and uses its text colour (the skin may make that
        // white on a dark toolbar); the vertical bar sits in a normal window pane.
        private Color TextColor {
            get {
                if(!IsVerticalBar) return Config.Skin.ToolBarTextColor;
                return QTUtility.InNightMode ? Color.White : SystemColors.ControlText;
            }
        }

        private int BarHeight {
            get {
                int text = ShowLabels ? Font.Height : 0;
                return Math.Max(IconSize, text) + 10;
            }
        }

        protected override void OnPaintBackground(PaintEventArgs e) {
            if(!IsVerticalBar && VisualStyleRenderer.IsSupported) {
                new VisualStyleRenderer(VisualStyleElement.Rebar.Band.Normal).DrawParentBackground(e.Graphics, e.ClipRectangle, this);
                return;
            }
            base.OnPaintBackground(e);
        }

        // The tool strip passes right-clicks (and the menu key) up as WM_CONTEXTMENU; left to the
        // default handling it reaches the rebar, which shows its toolbar menu instead of ours.
        protected override void WndProc(ref Message m) {
            if(m.Msg == WM.CONTEXTMENU) {
                ShowBarMenu(m.LParam);
                return;
            }
            base.WndProc(ref m);
        }

        // ---------------------------------------------------------------- keyboard

        // "Focus the vertical command bar" shortcut: focus the first button of this window's bar.
        // Then arrows move, Enter / Space press, the menu key opens the bar menu, Esc goes back to
        // the file list.
        internal static bool FocusVerticalBar(IntPtr frame) {
            CommandBarBand bar;
            lock(liveBars) bar = liveBars.FirstOrDefault(b => b.IsVerticalBar && b.FrameHandle == frame && b.IsHandleCreated && b.Visible);
            if(bar == null) return false;
            bar.toolStrip.Focus();
            ToolStripItem first = bar.SelectableItems().FirstOrDefault();
            if(first != null) first.Select();
            return true;
        }

        private IEnumerable<ToolStripItem> SelectableItems() {
            return toolStrip.Items.Cast<ToolStripItem>().Where(i => i.Tag is int && (int)i.Tag >= 0 && !(i is ToolStripSeparator) && i.Enabled && i.Visible);
        }

        private void toolStrip_KeyDown(object sender, KeyEventArgs e) {
            List<ToolStripItem> items = SelectableItems().ToList();
            if(items.Count == 0) return;
            int index = items.FindIndex(i => i.Selected);
            switch(e.KeyCode) {
                case Keys.Up:
                case Keys.Left:
                    items[index <= 0 ? items.Count - 1 : index - 1].Select();
                    break;
                case Keys.Down:
                case Keys.Right:
                    items[index < 0 || index >= items.Count - 1 ? 0 : index + 1].Select();
                    break;
                case Keys.Home:
                    items[0].Select();
                    break;
                case Keys.End:
                    items[items.Count - 1].Select();
                    break;
                case Keys.Enter:
                case Keys.Space:
                    if(index >= 0) OnItemClicked(items[index], false);
                    break;
                case Keys.Apps:
                    ShowBarMenu((IntPtr)(-1));
                    break;
                case Keys.Escape:
                    QTTabBarClass tabBar = InstanceManager.GetThreadTabBar();
                    if(tabBar != null && tabBar.GetListView() != null) tabBar.GetListView().SetFocus();
                    break;
                default:
                    return;
            }
            e.Handled = true;
        }

        // ---------------------------------------------------------------- building the buttons

        // Re-reads the items in every window (after an edit, or after Options changed them).
        internal static void RebuildAll() {
            CommandBarBand[] bars;
            lock(liveBars) bars = liveBars.ToArray();
            foreach(CommandBarBand bar in bars) {
                try {
                    if(bar.IsHandleCreated && !bar.IsDisposed) bar.BeginInvoke(new MethodInvoker(bar.Rebuild));
                }
                catch(Exception ex) {
                    QTUtility2.MakeErrorLog(ex, "CommandBarBand.RebuildAll");
                }
            }
        }

        private void Rebuild() {
            try {
                toolStrip.SuspendLayout();
                ClearItems();
                toolStrip.ImageScalingSize = new Size(IconSize, IconSize);
                toolStrip.ForeColor = TextColor;
                CommandBarItem[] items = Items ?? new CommandBarItem[0];
                for(int i = 0; i < items.Length; i++) {
                    ToolStripItem button = CreateButton(items[i]);
                    button.Tag = i;
                    toolStrip.Items.Add(button);
                }
                if(items.Length == 0) {
                    // Something to right-click on, so an empty bar can be filled.
                    toolStrip.Items.Add(new ToolStripLabel(Text_Empty) { ForeColor = SystemColors.GrayText, Tag = -1 });
                }
                toolStrip.ResumeLayout(true);
                Height = IsVerticalBar ? Height : BarHeight;
                RefreshBandSize();
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "CommandBarBand.Rebuild");
            }
        }

        private void ClearItems() {
            foreach(ToolStripItem item in toolStrip.Items.Cast<ToolStripItem>().ToArray()) {
                Image img = item.Image;
                item.Image = null;
                if(img != null) img.Dispose();
                ToolStripDropDownItem dd = item as ToolStripDropDownItem;
                if(dd != null && dd.DropDown != null) dd.DropDown.Dispose();
                item.Dispose();
            }
            toolStrip.Items.Clear();
        }

        // Tells the hosting rebar the new size (button count or icon size changed).
        private void RefreshBandSize() {
            if(BandObjectSite == null) return;
            try {
                const uint DBID_BANDINFOCHANGED = 0;
                Guid cgid = new Guid("EB0FE172-1A3A-11D0-89B3-00A0C90A90AC");   // CGID_DeskBand
                IOleCommandTarget target = BandObjectSite as IOleCommandTarget;
                if(target != null) target.Exec(ref cgid, DBID_BANDINFOCHANGED, 0, IntPtr.Zero, IntPtr.Zero);
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "CommandBarBand.RefreshBandSize");
            }
        }

        private ToolStripItem CreateButton(CommandBarItem item) {
            if(item.Type == CommandBarItemType.Separator) {
                return new ToolStripSeparator();
            }
            string text = DisplayText(item);
            Image image = item.Type == CommandBarItemType.Group
                    ? GroupImage(item)
                    : CommandBarIcons.ForPath(item.Path, IconSize);
            ToolStripItem button;
            if(item.Split) {
                ToolStripSplitButton split = new ToolStripSplitButton(text, image);
                // The arrow opens a menu built on demand (folder contents or the group's items);
                // the empty placeholder drop-down is never shown.
                ToolStripDropDown placeholder = new ToolStripDropDown();
                placeholder.Opening += (sender, e) => {
                    e.Cancel = true;
                    ShowItemMenu(split);
                };
                split.DropDown = placeholder;
                split.ButtonClick += (sender, e) => OnItemClicked(split, false);
                button = split;
            }
            else {
                ToolStripButton plain = new ToolStripButton(text, image);
                plain.Click += (sender, e) => OnItemClicked(plain, false);
                button = plain;
            }
            button.ImageScaling = ToolStripItemImageScaling.None;
            button.DisplayStyle = ShowLabels || image == null ? ToolStripItemDisplayStyle.ImageAndText : ToolStripItemDisplayStyle.Image;
            if(IsVerticalBar && ShowLabels) {
                button.TextImageRelation = TextImageRelation.ImageAboveText;
            }
            button.ToolTipText = ToolTip(item, text);
            button.ForeColor = TextColor;
            button.MouseUp += (sender, e) => {
                if(e.Button == MouseButtons.Middle) OnItemClicked((ToolStripItem)sender, true);
            };
            return button;
        }

        // As 2048: the icon of the first folder of the first group that has one.
        private Image GroupImage(CommandBarItem item) {
            foreach(string name in item.Groups ?? new string[0]) {
                Group group = GroupsManager.GetGroup(name);
                if(group == null || group.Paths.Count == 0) continue;
                Image image = CommandBarIcons.ForPath(group.Paths[0], IconSize);
                if(image != null) return image;
            }
            return CommandBarIcons.ForGroup(IconSize, TextColor.GetBrightness() > 0.5f);
        }

        private static string DisplayText(CommandBarItem item) {
            if(!string.IsNullOrEmpty(item.Text)) return item.Text;
            if(item.Type == CommandBarItemType.Group) {
                return item.Groups == null ? "" : string.Join(", ", item.Groups);
            }
            try {
                using(IDLWrapper wrapper = new IDLWrapper(ExpandPath(item.Path))) {
                    if(wrapper.Available && !string.IsNullOrEmpty(wrapper.DisplayName)) return wrapper.DisplayName;
                }
            }
            catch {
            }
            return Path.GetFileNameWithoutExtension(item.Path ?? "");
        }

        private static string ToolTip(CommandBarItem item, string text) {
            if(item.Type == CommandBarItemType.Group) {
                string groups = Text_GroupTip + string.Join(", ", item.Groups ?? new string[0]);
                return text == string.Join(", ", item.Groups ?? new string[0]) ? groups : text + "\r\n" + groups;
            }
            string tip = ExpandPath(item.Path);
            if(!string.IsNullOrEmpty(item.Args)) tip += " " + item.Args;
            return text == tip ? text : text + "\r\n" + tip;
        }

        private static string ExpandPath(string path) {
            return string.IsNullOrEmpty(path) ? path : Environment.ExpandEnvironmentVariables(path);
        }

        private CommandBarItem ItemOf(ToolStripItem button) {
            return ItemAt(button.Tag is int ? (int)button.Tag : -1);
        }

        private CommandBarItem ItemAt(int index) {
            CommandBarItem[] items = Items;
            return (items != null && index >= 0 && index < items.Length) ? items[index] : null;
        }

        // ---------------------------------------------------------------- running the buttons

        // The action configured for this click (index: Ctrl 1 | Shift 2 | Alt 4).
        private static int ClickAction(bool middle, Keys modifiers) {
            int[] table = middle ? Config.CmdBars.MiddleClickActions : Config.CmdBars.ClickActions;
            int index = ((modifiers & Keys.Control) != 0 ? 1 : 0) |
                        ((modifiers & Keys.Shift) != 0 ? 2 : 0) |
                        ((modifiers & Keys.Alt) != 0 ? 4 : 0);
            int action = table != null && table.Length == 8 ? table[index] : ActNone;
            if(action >= 3 && action <= 11) action = (action - 3) % 3;
            return action;
        }

        private void OnItemClicked(ToolStripItem button, bool middle) {
            int index = button.Tag is int ? (int)button.Tag : -1;
            CommandBarItem item = ItemAt(index);
            if(item == null) return;
            int action = ClickAction(middle, ModifierKeys);
            if(action == ActEdit) {
                BeginInvoke(new MethodInvoker(() => EditItem(index)));
                return;
            }
            if(action != ActNone) RunItem(item, action);
        }

        // Folders open in QTTabBar as the action says; files and programs are started (only Edit,
        // Properties and Copy path differ for them, as in 2048); groups open their folders.
        private void RunItem(CommandBarItem item, int action) {
            QTTabBarClass tabBar = InstanceManager.GetThreadTabBar();
            try {
                if(item.Type == CommandBarItemType.Group) {
                    RunGroup(item, action, tabBar);
                    return;
                }
                string path = ExpandPath(item.Path);
                if(action == ActCopyPath) {
                    QTUtility2.SetStringClipboard(path);
                    return;
                }
                using(IDLWrapper wrapper = new IDLWrapper(path)) {
                    if(action == ActProperties) {
                        if(wrapper.Available) ShellMethods.ShowProperties(wrapper.IDL, FrameHandle);
                        else SystemSounds.Beep.Play();
                        return;
                    }
                    if(item.FileAction != CommandBarFileAction.ShellExecute && wrapper.Available && wrapper.IsFolder && !IsProgram(path)) {
                        OpenFolder(tabBar, wrapper, FolderAction(item.FileAction, action));
                        return;
                    }
                }
                Launch(item, tabBar);
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "CommandBarBand click");
                SystemSounds.Beep.Play();
            }
        }

        private static int FolderAction(CommandBarFileAction fileAction, int action) {
            switch(fileAction) {
                case CommandBarFileAction.NewTab: return ActNewTab;
                case CommandBarFileAction.NewTabBackground: return ActBackgroundTab;
                case CommandBarFileAction.InPlace: return ActThisTab;
                case CommandBarFileAction.NewWindow: return ActNewWindow;
                default: return action;
            }
        }

        private void Launch(CommandBarItem item, QTTabBarClass tabBar) {
            int show;
            switch(item.WindowSize) {
                case 1: show = 3; break;    // SW_SHOWMAXIMIZED
                case 2: show = 7; break;    // SW_SHOWMINNOACTIVE
                case 3: show = 0; break;    // SW_HIDE
                default: show = 1; break;   // SW_SHOWNORMAL
            }
            UserApp app = new UserApp(DisplayText(item), item.Path, item.Args ?? "", item.WorkingDir ?? "", Keys.None);
            AppsManager.Execute(app, tabBar != null ? tabBar.GetShellBrowser() : null, item.Verb, show);
        }

        private static bool IsProgram(string path) {
            try {
                return File.Exists(path);
            }
            catch {
                return false;
            }
        }

        private void OpenFolder(QTTabBarClass tabBar, IDLWrapper wrapper, int action) {
            if(tabBar == null) {
                // No tab bar in this window: navigate the window itself.
                if(Explorer != null) {
                    object url = wrapper.Path, none = null, none2 = null, none3 = null, none4 = null;
                    Explorer.Navigate2(ref url, ref none, ref none2, ref none3, ref none4);
                }
                return;
            }
            switch(action) {
                case ActNewWindow:
                    tabBar.OpenNewWindow(wrapper);
                    break;
                case ActThisTab:
                    ShellBrowserEx browser = tabBar.GetShellBrowser();
                    if(browser != null) browser.Navigate(wrapper);
                    break;
                case ActBackgroundTab:
                    tabBar.OpenNewTab(wrapper, true);
                    break;
                default:
                    tabBar.OpenNewTab(wrapper);
                    break;
            }
        }

        private static void RunGroup(CommandBarItem item, int action, QTTabBarClass tabBar) {
            string[] names = (item.Groups ?? new string[0]).Where(n => GroupsManager.GetGroup(n) != null).ToArray();
            if(tabBar == null || names.Length == 0) {
                SystemSounds.Beep.Play();
                return;
            }
            if(action == ActProperties) return;
            if(action == ActCopyPath) {
                QTUtility2.SetStringClipboard(string.Join(Environment.NewLine, names.SelectMany(n => GroupsManager.GetGroup(n).Paths)));
                return;
            }
            switch(item.GroupAction) {
                case CommandBarGroupAction.Background: action = ActBackgroundTab; break;
                case CommandBarGroupAction.NewWindow: action = ActNewWindow; break;
                case CommandBarGroupAction.Replace: action = ActThisTab; break;
            }
            for(int i = 0; i < names.Length; i++) {
                switch(action) {
                    case ActNewWindow:
                        tabBar.OpenGroup(names[i], true);
                        break;
                    case ActThisTab:
                        if(i == 0) tabBar.ReplaceTabsWithGroup(names[i]);
                        else tabBar.OpenGroup(names[i], false, true);
                        break;
                    case ActBackgroundTab:
                        tabBar.OpenGroupInBackground(names[i]);
                        break;
                    default:
                        tabBar.OpenGroup(names[i], false, true);
                        break;
                }
            }
        }

        // Split arrow: the folder's contents (the same menu as a tab's subfolder arrow), or the
        // folders of the group.
        private void ShowItemMenu(ToolStripSplitButton split) {
            CommandBarItem item = ItemOf(split);
            if(item == null) return;
            Rectangle bounds = split.Bounds;
            Point pnt = IsVerticalBar
                    ? toolStrip.PointToScreen(new Point(bounds.Right, bounds.Top))
                    : toolStrip.PointToScreen(new Point(bounds.Left, bounds.Bottom));
            QTTabBarClass tabBar = InstanceManager.GetThreadTabBar();
            if(item.Type == CommandBarItemType.Group) {
                ShowGroupMenu(item, pnt, tabBar);
                return;
            }
            if(tabBar == null || !tabBar.ShowFolderMenu(ExpandPath(item.Path), pnt)) {
                SystemSounds.Beep.Play();
            }
        }

        private void ShowGroupMenu(CommandBarItem item, Point pnt, QTTabBarClass tabBar) {
            ContextMenuStripEx menu = new ContextMenuStripEx(null, false);
            menu.ImageScalingSize = new Size(16, 16);
            foreach(string name in item.Groups ?? new string[0]) {
                Group group = GroupsManager.GetGroup(name);
                if(group == null) continue;
                if(menu.Items.Count > 0) menu.Items.Add(new ToolStripSeparator());
                foreach(string path in group.Paths) {
                    string target = path;
                    string label = target;
                    try {
                        using(IDLWrapper wrapper = new IDLWrapper(target)) {
                            if(wrapper.Available) label = wrapper.DisplayName;
                        }
                    }
                    catch {
                    }
                    ToolStripMenuItem entry = new ToolStripMenuItem(label, CommandBarIcons.ForPath(target, 16));
                    entry.Click += (sender, e) => {
                        Keys keys = ModifierKeys;
                        int action = (keys & Keys.Control) != 0 ? ActNewWindow
                                : (keys & Keys.Shift) != 0 ? ActBackgroundTab : ActNewTab;
                        using(IDLWrapper wrapper = new IDLWrapper(target)) {
                            if(wrapper.Available) OpenFolder(tabBar, wrapper, action);
                        }
                    };
                    menu.Items.Add(entry);
                }
            }
            if(menu.Items.Count == 0) {
                menu.Dispose();
                SystemSounds.Beep.Play();
                return;
            }
            menu.Closed += (sender, e) => BeginInvoke(new MethodInvoker(() => {
                foreach(ToolStripItem i in menu.Items) {
                    if(i.Image != null) i.Image.Dispose();
                }
                menu.Dispose();
            }));
            menu.Show(pnt);
        }

        // ---------------------------------------------------------------- editing the bar

        // lParam: screen point of the click, or -1 for the menu key (then the selected button).
        private void ShowBarMenu(IntPtr lParam) {
            long lp = lParam.ToInt64();
            int x = (short)(lp & 0xFFFF), y = (short)((lp >> 16) & 0xFFFF);
            ToolStripItem at;
            Point client;
            if(x == -1 && y == -1) {
                at = toolStrip.Items.Cast<ToolStripItem>().FirstOrDefault(i => i.Selected);
                client = at != null ? new Point(at.Bounds.Left, at.Bounds.Bottom) : new Point(0, 0);
            }
            else {
                client = toolStrip.PointToClient(new Point(x, y));
                at = toolStrip.GetItemAt(client);
            }
            menuItemIndex = at != null && at.Tag is int ? (int)at.Tag : -1;
            barMenu.Show(toolStrip, client);
        }

        private void barMenu_Opening(object sender, CancelEventArgs e) {
            barMenu.Items.Clear();
            CommandBarItem[] items = Items ?? new CommandBarItem[0];
            int index = menuItemIndex;
            bool onItem = index >= 0 && index < items.Length;
            if(onItem) {
                CommandBarItem item = items[index];
                if(AddOpenItems(item)) barMenu.Items.Add(new ToolStripSeparator());
                if(item.Type != CommandBarItemType.Separator) {
                    barMenu.Items.Add(Text_Edit, null, (s, a) => EditItem(index));
                }
                barMenu.Items.Add(IsVerticalBar ? Text_MoveUp : Text_MoveLeft, null, (s, a) => MoveItem(index, -1)).Enabled = index > 0;
                barMenu.Items.Add(IsVerticalBar ? Text_MoveDown : Text_MoveRight, null, (s, a) => MoveItem(index, 1)).Enabled = index < items.Length - 1;
                barMenu.Items.Add(Text_Remove, null, (s, a) => RemoveItem(index));
                barMenu.Items.Add(new ToolStripSeparator());
            }
            int insertAt = onItem ? index + 1 : items.Length;
            QTTabBarClass tabBar = InstanceManager.GetThreadTabBar();
            ToolStripMenuItem addCurrent = new ToolStripMenuItem(Text_AddCurrent, null, (s, a) => AddCurrentFolder(insertAt));
            addCurrent.Enabled = tabBar != null;
            barMenu.Items.Add(addCurrent);
            barMenu.Items.Add(Text_AddFolder, null, (s, a) => AddFolder(insertAt));
            barMenu.Items.Add(Text_AddFile, null, (s, a) => AddFile(insertAt));
            ToolStripMenuItem addGroup = new ToolStripMenuItem(Text_AddGroup);
            foreach(Group group in GroupsManager.Groups) {
                string name = group.Name;
                addGroup.DropDownItems.Add(name, null, (s, a) => Insert(insertAt, new CommandBarItem { Type = CommandBarItemType.Group, Split = true, Groups = new[] { name } }));
            }
            addGroup.Enabled = addGroup.DropDownItems.Count > 0;
            barMenu.Items.Add(addGroup);
            barMenu.Items.Add(Text_AddSeparator, null, (s, a) => Insert(insertAt, new CommandBarItem { Type = CommandBarItemType.Separator }));
            barMenu.Items.Add(new ToolStripSeparator());
            ToolStripMenuItem labels = new ToolStripMenuItem(Text_ShowLabels) { Checked = ShowLabels };
            labels.Click += (s, a) => Save(() => ShowLabels = !ShowLabels);
            barMenu.Items.Add(labels);
            ToolStripMenuItem sizes = new ToolStripMenuItem(Text_IconSize);
            List<int> choices = new List<int> { 16, 24, 32, 48, 64, 96 };
            if(!choices.Contains(IconSize)) {
                choices.Add(IconSize);
                choices.Sort();
            }
            foreach(int size in choices) {
                int value = size;
                ToolStripMenuItem entry = new ToolStripMenuItem(size + " px") { Checked = IconSize == size };
                entry.Click += (s, a) => Save(() => IconSize = value);
                sizes.DropDownItems.Add(entry);
            }
            barMenu.Items.Add(sizes);
            e.Cancel = false;
        }

        // The ways to open the item under the menu (as 2048's item menu). False when there are none.
        private bool AddOpenItems(CommandBarItem item) {
            if(item.Type == CommandBarItemType.Group) {
                barMenu.Items.Add(Text_OpenNewTab, null, (s, a) => RunItem(item, ActNewTab));
                barMenu.Items.Add(Text_OpenBackground, null, (s, a) => RunItem(item, ActBackgroundTab));
                barMenu.Items.Add(Text_OpenNewWindow, null, (s, a) => RunItem(item, ActNewWindow));
                barMenu.Items.Add(Text_ReplaceTabs, null, (s, a) => RunItem(item, ActThisTab));
                return true;
            }
            if(item.Type != CommandBarItemType.File) return false;
            string path = ExpandPath(item.Path);
            bool folder = false, available = false;
            try {
                using(IDLWrapper wrapper = new IDLWrapper(path)) {
                    available = wrapper.Available;
                    folder = available && wrapper.IsFolder && !IsProgram(path);
                }
            }
            catch {
            }
            if(folder) {
                barMenu.Items.Add(Text_OpenNewTab, null, (s, a) => RunItem(item, ActNewTab));
                barMenu.Items.Add(Text_OpenBackground, null, (s, a) => RunItem(item, ActBackgroundTab));
                barMenu.Items.Add(Text_OpenThisTab, null, (s, a) => RunItem(item, ActThisTab));
                barMenu.Items.Add(Text_OpenNewWindow, null, (s, a) => RunItem(item, ActNewWindow));
            }
            else {
                barMenu.Items.Add(Text_Run, null, (s, a) => RunItem(item, ActNewTab));
                string parent = null;
                try {
                    if(IsProgram(path)) parent = Path.GetDirectoryName(path);
                }
                catch {
                }
                ToolStripMenuItem containing = new ToolStripMenuItem(Text_OpenContaining, null, (s, a) => {
                    using(IDLWrapper wrapper = new IDLWrapper(parent)) {
                        if(wrapper.Available) OpenFolder(InstanceManager.GetThreadTabBar(), wrapper, ActNewTab);
                    }
                });
                containing.Enabled = !string.IsNullOrEmpty(parent);
                barMenu.Items.Add(containing);
            }
            barMenu.Items.Add(Text_CopyPath, null, (s, a) => RunItem(item, ActCopyPath));
            barMenu.Items.Add(Text_Properties, null, (s, a) => RunItem(item, ActProperties)).Enabled = available;
            return true;
        }

        private void AddCurrentFolder(int index) {
            QTTabBarClass tabBar = InstanceManager.GetThreadTabBar();
            ShellBrowserEx browser = tabBar == null ? null : tabBar.GetShellBrowser();
            if(browser == null) return;
            using(IDLWrapper wrapper = browser.GetShellPath()) {
                if(wrapper == null || !wrapper.Available) return;
                Insert(index, new CommandBarItem { Type = CommandBarItemType.File, Split = wrapper.IsFolder, Path = wrapper.Path });
            }
        }

        private void AddFolder(int index) {
            using(FolderBrowserDialog dialog = new FolderBrowserDialog()) {
                if(dialog.ShowDialog(this) == DialogResult.OK) {
                    Insert(index, new CommandBarItem { Type = CommandBarItemType.File, Split = true, Path = dialog.SelectedPath });
                }
            }
        }

        private void AddFile(int index) {
            using(OpenFileDialog dialog = new OpenFileDialog { CheckFileExists = true, DereferenceLinks = false }) {
                if(dialog.ShowDialog(this) == DialogResult.OK) {
                    Insert(index, new CommandBarItem { Type = CommandBarItemType.File, Path = dialog.FileName });
                }
            }
        }

        private void EditItem(int index) {
            CommandBarItem[] items = Items;
            if(items == null || index < 0 || index >= items.Length) return;
            if(items[index].Type == CommandBarItemType.Separator) return;
            CommandBarItem edited = items[index].Clone();
            using(CommandBarItemForm form = new CommandBarItemForm(edited)) {
                if(form.ShowDialog(this) == DialogResult.OK) {
                    Save(() => {
                        CommandBarItem[] copy = (CommandBarItem[])Items.Clone();
                        if(index < copy.Length) copy[index] = edited;
                        Items = copy;
                    });
                }
            }
        }

        private void Insert(int index, CommandBarItem item) {
            Save(() => {
                List<CommandBarItem> list = (Items ?? new CommandBarItem[0]).ToList();
                list.Insert(Math.Max(0, Math.Min(index, list.Count)), item);
                Items = list.ToArray();
            });
        }

        private void MoveItem(int index, int delta) {
            Save(() => {
                List<CommandBarItem> list = Items.ToList();
                int to = index + delta;
                if(index < 0 || index >= list.Count || to < 0 || to >= list.Count) return;
                CommandBarItem item = list[index];
                list.RemoveAt(index);
                list.Insert(to, item);
                Items = list.ToArray();
            });
        }

        private void RemoveItem(int index) {
            Save(() => {
                List<CommandBarItem> list = Items.ToList();
                if(index >= 0 && index < list.Count) list.RemoveAt(index);
                Items = list.ToArray();
            });
        }

        // Applies an edit to Config.CmdBars, stores it and rebuilds the bar in every window.
        private static void Save(Action change) {
            try {
                change();
                ConfigManager.WriteConfig();
                RebuildAll();
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "CommandBarBand.Save");
            }
        }

        // ---------------------------------------------------------------- text

        private static bool Japanese { get { return QTUtility.IsJapanese; } }
        private static string Text_Empty { get { return Japanese ? "(右クリックでボタンを追加)" : "(right-click to add buttons)"; } }
        private static string Text_GroupTip { get { return Japanese ? "グループ: " : "Group: "; } }
        private static string Text_OpenNewTab { get { return Japanese ? "新しいタブで開く" : "Open in new tab"; } }
        private static string Text_OpenBackground { get { return Japanese ? "バックグラウンドのタブで開く" : "Open in background tab"; } }
        private static string Text_OpenThisTab { get { return Japanese ? "現在のタブで開く" : "Open in current tab"; } }
        private static string Text_OpenNewWindow { get { return Japanese ? "新しいウィンドウで開く" : "Open in new window"; } }
        private static string Text_ReplaceTabs { get { return Japanese ? "開いているタブと置き換える" : "Replace open tabs"; } }
        private static string Text_Run { get { return Japanese ? "開く" : "Open"; } }
        private static string Text_OpenContaining { get { return Japanese ? "ファイルの場所を開く" : "Open containing folder"; } }
        private static string Text_CopyPath { get { return Japanese ? "パスをコピー" : "Copy path"; } }
        private static string Text_Properties { get { return Japanese ? "プロパティ" : "Properties"; } }
        private static string Text_Edit { get { return Japanese ? "編集..." : "Edit..."; } }
        private static string Text_MoveLeft { get { return Japanese ? "左へ移動" : "Move left"; } }
        private static string Text_MoveRight { get { return Japanese ? "右へ移動" : "Move right"; } }
        private static string Text_MoveUp { get { return Japanese ? "上へ移動" : "Move up"; } }
        private static string Text_MoveDown { get { return Japanese ? "下へ移動" : "Move down"; } }
        private static string Text_Remove { get { return Japanese ? "削除" : "Remove"; } }
        private static string Text_AddCurrent { get { return Japanese ? "現在のフォルダーを追加" : "Add current folder"; } }
        private static string Text_AddFolder { get { return Japanese ? "フォルダーを追加..." : "Add folder..."; } }
        private static string Text_AddFile { get { return Japanese ? "ファイル/プログラムを追加..." : "Add file or program..."; } }
        private static string Text_AddGroup { get { return Japanese ? "グループを追加" : "Add group"; } }
        private static string Text_AddSeparator { get { return Japanese ? "区切りを追加" : "Add separator"; } }
        private static string Text_ShowLabels { get { return Japanese ? "ラベルを表示" : "Show labels"; } }
        private static string Text_IconSize { get { return Japanese ? "アイコンサイズ" : "Icon size"; } }
    }
}
