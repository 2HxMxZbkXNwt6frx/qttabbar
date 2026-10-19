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

using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace QTTabBarLib {

    // Asks for a file or folder name (rename the current folder, name a new library).
    internal sealed class InputNameForm : Form {
        private readonly TextBox txtName = new TextBox();

        private InputNameForm(string title, string label, string initial) {
            bool ja = QTUtility.IsJapanese;
            Text = title;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = MinimizeBox = false;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.CenterParent;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;
            Font = SystemFonts.MessageBoxFont;
            Padding = new Padding(10);

            TableLayoutPanel table = new TableLayoutPanel {
                ColumnCount = 1, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Dock = DockStyle.Fill,
            };
            table.Controls.Add(new Label { Text = label, AutoSize = true, Margin = new Padding(0, 0, 0, 4) });
            txtName.Width = 360;
            txtName.Text = initial ?? "";
            table.Controls.Add(txtName);

            FlowLayoutPanel buttons = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Dock = DockStyle.Fill };
            Button cancel = new Button { Text = ja ? "キャンセル" : "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
            Button ok = new Button { Text = "OK", DialogResult = DialogResult.OK, AutoSize = true };
            buttons.Controls.Add(cancel);
            buttons.Controls.Add(ok);
            table.Controls.Add(buttons);
            AcceptButton = ok;
            CancelButton = cancel;
            Controls.Add(table);
            Shown += (s, e) => {
                txtName.Focus();
                txtName.SelectAll();
            };
        }

        // The entered name, or null when cancelled, empty, unchanged or not a valid file name.
        internal static string Ask(IWin32Window owner, string title, string label, string initial) {
            using(InputNameForm form = new InputNameForm(title, label, initial)) {
                if(form.ShowDialog(owner) != DialogResult.OK) return null;
                string name = form.txtName.Text.Trim();
                if(name.Length == 0 || name == initial || name.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0) {
                    if(name.Length > 0 && name != initial) QTUtility.SoundPlay();
                    return null;
                }
                return name;
            }
        }
    }
}
