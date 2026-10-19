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
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace QTTabBarLib {

    // Edits one command bar button in place (the item passed in is changed on OK).
    internal sealed class CommandBarItemForm : Form {
        private readonly CommandBarItem item;
        private readonly TextBox txtLabel = new TextBox();
        private readonly TextBox txtPath = new TextBox();
        private readonly TextBox txtArgs = new TextBox();
        private readonly TextBox txtDir = new TextBox();
        private readonly TextBox txtIcon = new TextBox();
        private readonly CheckBox chkSplit = new CheckBox();
        private readonly CheckBox chkAdmin = new CheckBox();
        private readonly ComboBox cmbAction = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList };
        private readonly CheckedListBox lstGroups = new CheckedListBox();

        public CommandBarItemForm(CommandBarItem item) {
            this.item = item;
            bool ja = QTUtility.IsJapanese;
            bool group = item.Type == CommandBarItemType.Group;
            bool menu = item.Type == CommandBarItemType.Menu;
            Text = ja ? "ボタンの編集" : "Edit button";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = MinimizeBox = false;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.CenterParent;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;
            Font = SystemFonts.MessageBoxFont;
            Padding = new Padding(10);

            TableLayoutPanel table = new TableLayoutPanel {
                ColumnCount = 3, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Dock = DockStyle.Fill,
            };
            table.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 340));
            table.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));

            AddRow(table, ja ? "ラベル (空欄で自動):" : "Label (empty = automatic):", txtLabel, null);
            txtLabel.Text = item.Text ?? "";
            if(group) {
                foreach(Group g in GroupsManager.Groups) {
                    lstGroups.Items.Add(g.Name, item.Groups != null && item.Groups.Contains(g.Name));
                }
                lstGroups.Height = 120;
                lstGroups.CheckOnClick = true;
                AddRow(table, ja ? "グループ:" : "Groups:", lstGroups, null);
                // CommandBarGroupAction order.
                cmbAction.Items.AddRange(ja
                        ? new object[] { "既定 (クリックの設定に従う)", "バックグラウンドで開く", "新しいウィンドウで開く", "開いているタブと置き換える" }
                        : new object[] { "Default (as the click settings)", "Open in background", "Open in new window", "Replace open tabs" });
                cmbAction.SelectedIndex = Math.Max(0, Math.Min((int)item.GroupAction, cmbAction.Items.Count - 1));
                AddRow(table, ja ? "動作:" : "Action:", cmbAction, null);
            }
            else if(!menu) {
                Button browse = new Button { Text = "...", Width = 32, AutoSize = false };
                browse.Click += (s, e) => Browse();
                AddRow(table, ja ? "パス:" : "Path:", txtPath, browse);
                AddRow(table, ja ? "引数 (%cd% など):" : "Arguments (%cd% etc.):", txtArgs, null);
                AddRow(table, ja ? "作業フォルダー:" : "Working folder:", txtDir, null);
                txtPath.Text = item.Path ?? "";
                txtArgs.Text = item.Args ?? "";
                txtDir.Text = item.WorkingDir ?? "";
                // CommandBarFileAction order.
                cmbAction.Items.AddRange(ja
                        ? new object[] { "既定 (クリックの設定に従う)", "新しいタブで開く", "バックグラウンドのタブで開く", "現在のタブで開く", "新しいウィンドウで開く", "シェルで実行" }
                        : new object[] { "Default (as the click settings)", "Open in new tab", "Open in background tab", "Open in current tab", "Open in new window", "Execute by shell" });
                cmbAction.SelectedIndex = Math.Max(0, Math.Min((int)item.FileAction, cmbAction.Items.Count - 1));
                AddRow(table, ja ? "フォルダーの開き方:" : "Folder action:", cmbAction, null);
                chkAdmin.Text = ja ? "管理者として実行" : "Run as administrator";
                chkAdmin.AutoSize = true;
                chkAdmin.Checked = string.Equals(item.Verb, "runas", StringComparison.OrdinalIgnoreCase);
                table.Controls.Add(chkAdmin, 1, table.RowCount++);
            }
            Button browseIcon = new Button { Text = "...", Width = 32, AutoSize = false };
            browseIcon.Click += (s, e) => BrowseIcon();
            AddRow(table, ja ? "アイコン (空欄で自動):" : "Icon (empty = automatic):", txtIcon, browseIcon);
            txtIcon.Text = item.Icon ?? "";
            chkSplit.Text = group
                    ?(ja ? "▼ でグループの項目を表示" : "Show the group's folders under the arrow")
                    : (ja ? "▼ でフォルダーの中身を表示" : "Show the folder's contents under the arrow");
            chkSplit.AutoSize = true;
            chkSplit.Checked = item.Split;
            if(!menu) table.Controls.Add(chkSplit, 1, table.RowCount++);

            FlowLayoutPanel buttons = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Dock = DockStyle.Fill };
            Button cancel = new Button { Text = ja ? "キャンセル" : "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
            Button ok = new Button { Text = "OK", DialogResult = DialogResult.OK, AutoSize = true };
            ok.Click += (s, e) => Apply();
            buttons.Controls.Add(cancel);
            buttons.Controls.Add(ok);
            table.Controls.Add(buttons, 1, table.RowCount++);
            table.SetColumnSpan(buttons, 2);
            AcceptButton = ok;
            CancelButton = cancel;
            Controls.Add(table);
        }

        private static void AddRow(TableLayoutPanel table, string label, Control field, Control extra) {
            int row = table.RowCount++;
            table.Controls.Add(new Label { Text = label, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 6, 6, 0) }, 0, row);
            field.Dock = DockStyle.Fill;
            table.Controls.Add(field, 1, row);
            if(extra != null) table.Controls.Add(extra, 2, row);
        }

        private void Browse() {
            using(OpenFileDialog dialog = new OpenFileDialog { CheckFileExists = false, DereferenceLinks = false, ValidateNames = false, FileName = "" }) {
                if(dialog.ShowDialog(this) == DialogResult.OK) txtPath.Text = dialog.FileName;
            }
        }

        // An image / .ico file, or an icon resource of an .exe / .dll (its first icon; the index can be
        // edited after the comma).
        private void BrowseIcon() {
            using(OpenFileDialog dialog = new OpenFileDialog { CheckFileExists = true, DereferenceLinks = false,
                    Filter = "Icons, images, programs|*.ico;*.png;*.bmp;*.jpg;*.gif;*.exe;*.dll|*.*|*.*" }) {
                if(dialog.ShowDialog(this) != DialogResult.OK) return;
                string ext = System.IO.Path.GetExtension(dialog.FileName).ToLowerInvariant();
                txtIcon.Text = ext == ".exe" || ext == ".dll" ? dialog.FileName + ",0" : dialog.FileName;
            }
        }

        private void Apply() {
            item.Text = txtLabel.Text.Trim();
            item.Icon = txtIcon.Text.Trim().Length > 0 ? txtIcon.Text.Trim() : null;
            if(item.Type != CommandBarItemType.Menu) item.Split = chkSplit.Checked;
            if(item.Type == CommandBarItemType.Group) {
                item.Groups = lstGroups.CheckedItems.Cast<string>().ToArray();
                item.GroupAction = (CommandBarGroupAction)Math.Max(0, cmbAction.SelectedIndex);
            }
            else if(item.Type == CommandBarItemType.File) {
                item.Path = txtPath.Text.Trim();
                item.Args = txtArgs.Text;
                item.WorkingDir = txtDir.Text.Trim();
                item.FileAction = (CommandBarFileAction)Math.Max(0, cmbAction.SelectedIndex);
                if(chkAdmin.Checked) {
                    item.Verb = "runas";
                }
                else if(string.Equals(item.Verb, "runas", StringComparison.OrdinalIgnoreCase)) {
                    item.Verb = null;
                }
            }
        }
    }
}
