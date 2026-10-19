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
using System.Runtime.Serialization;

namespace QTTabBarLib {

    // What a command bar button does. Values are persisted (as numbers in the
    // Config\CmdBars JSON), so only ever append.
    public enum CommandBarItemType {
        // A file, folder or shell location (Path). Folders open in QTTabBar; anything else
        // is started like an Applications entry (Args/WorkingDir, %cd% etc. expanded).
        File = 0,
        // One or more tab groups (Groups), opened like the Groups button does.
        Group = 1,
        Separator = 2,
    }

    // File items: how a folder target opens, overriding the click table (Config.CmdBars
    // ClickActions). Same members as 2048 Beta2's FileAction 0..5; persisted, only append.
    public enum CommandBarFileAction {
        Default = 0,
        NewTab = 1,
        NewTabBackground = 2,
        InPlace = 3,
        NewWindow = 4,
        // Start the target with the shell even when it is a folder.
        ShellExecute = 5,
    }

    // Group items: as 2048 Beta2's GroupAction; persisted, only append.
    public enum CommandBarGroupAction {
        Default = 0,
        Background = 1,
        NewWindow = 2,
        // Open the group's folders and close the other tabs.
        Replace = 3,
    }

    // One button on the second command bar or the vertical command bar.
    [Serializable, DataContract]
    public sealed class CommandBarItem {
        [DataMember] public CommandBarItemType Type { get; set; }

        // File and Group: also show a drop-down arrow (folder contents / the group's items).
        [DataMember] public bool Split { get; set; }

        // Label; empty means the target's display name (File) or the group name (Group).
        [DataMember] public string Text { get; set; }

        // File: a file system path or a shell parsing name such as ::{20D04FE0-...}.
        // Environment variables are expanded.
        [DataMember] public string Path { get; set; }

        // File, programs only: command line arguments and working directory. %cd%, %c%, %d%,
        // %f% and %s% are expanded as for Applications.
        [DataMember] public string Args { get; set; }
        [DataMember] public string WorkingDir { get; set; }

        // Group: names of the groups to open.
        [DataMember] public string[] Groups { get; set; }

        [DataMember] public CommandBarFileAction FileAction { get; set; }
        [DataMember] public CommandBarGroupAction GroupAction { get; set; }

        // File, programs only: ShellExecute verb ("runas" = run as administrator), empty for the
        // default, and the window state: 0 normal, 1 maximized, 2 minimized, 3 hidden.
        [DataMember] public string Verb { get; set; }
        [DataMember] public int WindowSize { get; set; }

        public CommandBarItem Clone() {
            CommandBarItem item = (CommandBarItem)MemberwiseClone();
            if(Groups != null) item.Groups = (string[])Groups.Clone();
            return item;
        }
    }
}
