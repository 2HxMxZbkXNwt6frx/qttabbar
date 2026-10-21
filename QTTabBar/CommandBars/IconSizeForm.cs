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
using System.Windows.Forms;

namespace QTTabBarLib {

    // Asks for a command bar's icon size in pixels (the sizes the bar menu doesn't list).
    internal sealed class IconSizeForm : Form {
        private readonly NumericUpDown numSize = new NumericUpDown();

        private IconSizeForm(int current, int min, int max) {
            bool ja = QTUtility.IsJapanese;
            Text = ja ? "アイコンサイズ" : "Icon size";
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
            string label = ja ? string.Format("アイコンのサイズ ({0}～{1} px):", min, max) : string.Format("Icon size ({0}-{1} px):", min, max);
            table.Controls.Add(new Label { Text = label, AutoSize = true, Margin = new Padding(0, 0, 0, 4) });
            numSize.Minimum = min;
            numSize.Maximum = max;
            numSize.Value = Math.Max(min, Math.Min(max, current));
            numSize.Width = 80;
            table.Controls.Add(numSize);

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
                numSize.Focus();
                numSize.Select(0, numSize.Text.Length);
            };
        }

        // The entered size, or 0 when cancelled.
        internal static int Ask(IWin32Window owner, int current, int min, int max) {
            using(IconSizeForm form = new IconSizeForm(current, min, max)) {
                if(form.ShowDialog(owner) != DialogResult.OK) return 0;
                return (int)form.numSize.Value;
            }
        }
    }
}
