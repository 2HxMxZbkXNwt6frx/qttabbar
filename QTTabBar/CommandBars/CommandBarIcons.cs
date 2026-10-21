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
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace QTTabBarLib {

    // Icons for command bar buttons at any size (8-256 px), with transparency. The bitmaps are
    // created per call, so each window's bar owns its own (GDI+ objects aren't thread-safe).
    internal static class CommandBarIcons {
        [ComImport, Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IShellItemImageFactory {
            [PreserveSig]
            int GetImage(SIZE size, int flags, out IntPtr phbm);
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct SIZE {
            public int cx;
            public int cy;
        }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern int SHCreateItemFromParsingName(string pszPath, IntPtr pbc,
                [MarshalAs(UnmanagedType.LPStruct)] Guid riid, [MarshalAs(UnmanagedType.Interface)] out object ppv);

        [DllImport("gdi32.dll")]
        private static extern bool DeleteObject(IntPtr hObject);

        private const int SIIGBF_BIGGERSIZEOK = 0x1;
        private const int SIIGBF_ICONONLY = 0x4;
        private static readonly Guid IID_IShellItemImageFactory = new Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b");

        // The shell icon of a file system path or parsing name (::{CLSID}...) at the given size;
        // null when it can't be resolved.
        public static Bitmap ForPath(string path, int size) {
            if(string.IsNullOrEmpty(path)) return null;
            object obj = null;
            try {
                if(SHCreateItemFromParsingName(Environment.ExpandEnvironmentVariables(path), IntPtr.Zero, IID_IShellItemImageFactory, out obj) != 0) {
                    return null;
                }
                IShellItemImageFactory factory = obj as IShellItemImageFactory;
                IntPtr hbm;
                if(factory == null || factory.GetImage(new SIZE { cx = size, cy = size }, SIIGBF_ICONONLY | SIIGBF_BIGGERSIZEOK, out hbm) != 0 || hbm == IntPtr.Zero) {
                    return null;
                }
                try {
                    return Fit(FromHBitmap(hbm), size);
                }
                finally {
                    DeleteObject(hbm);
                }
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "CommandBarIcons " + path);
                return null;
            }
            finally {
                if(obj != null) Marshal.ReleaseComObject(obj);
            }
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern uint PrivateExtractIcons(string lpszFile, int nIconIndex, int cxIcon, int cyIcon,
                IntPtr[] phicon, uint[] piconid, uint nIcons, uint flags);

        [DllImport("user32.dll")]
        private static extern bool DestroyIcon(IntPtr hIcon);

        // A button's own icon: "file,index" (index < 0 = resource id, as in .lnk / registry icon
        // locations) or an image or .ico file. Null when it can't be loaded.
        public static Bitmap ForIconSpec(string spec, int size) {
            if(string.IsNullOrEmpty(spec)) return null;
            try {
                string file = spec.Trim();
                int index = 0;
                int comma = file.LastIndexOf(',');
                if(comma > 0 && int.TryParse(file.Substring(comma + 1).Trim(), out index)) {
                    file = file.Substring(0, comma).Trim();
                }
                file = Environment.ExpandEnvironmentVariables(file.Trim('"'));
                if(!System.IO.File.Exists(file)) return null;
                string ext = System.IO.Path.GetExtension(file).ToLowerInvariant();
                if(ext == ".png" || ext == ".bmp" || ext == ".jpg" || ext == ".jpeg" || ext == ".gif") {
                    using(Image image = Image.FromFile(file)) {
                        return Fit(new Bitmap(image), size);
                    }
                }
                IntPtr[] icons = new IntPtr[1];
                uint[] ids = new uint[1];
                uint got = PrivateExtractIcons(file, index, size, size, icons, ids, 1, 0);
                if(got == 0 || got == 0xFFFFFFFF || icons[0] == IntPtr.Zero) return null;
                try {
                    using(Icon icon = Icon.FromHandle(icons[0])) {
                        return Fit(icon.ToBitmap(), size);
                    }
                }
                finally {
                    DestroyIcon(icons[0]);
                }
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "CommandBarIcons " + spec);
                return null;
            }
        }

        // The Groups icon of the standard button bar, scaled to size; the white variant for dark bars.
        public static Bitmap ForGroup(int size, bool light) {
            try {
                Bitmap source = light
                        ? (size > 16 ? Resources_Image.ButtonStripWhite24 : Resources_Image.ButtonStripWhite16)
                        : (size > 16 ? Resources_Image.ButtonStrip24 : Resources_Image.ButtonStrip16);
                using(Bitmap strip = source) {
                    int cell = strip.Height;
                    // Index BII_GROUP - 1 in the strip (see QTButtonBar).
                    Rectangle src = new Rectangle((QTButtonBar.BII_GROUP - 1) * cell, 0, cell, cell);
                    using(Bitmap one = strip.Clone(src, PixelFormat.Format32bppArgb)) {
                        return Fit(new Bitmap(one), size);
                    }
                }
            }
            catch(Exception ex) {
                QTUtility2.MakeErrorLog(ex, "CommandBarIcons group");
                return null;
            }
        }

        // Image.FromHbitmap drops the alpha channel; the pixel data still has it, so reinterpret the
        // bits as ARGB when they carry any alpha.
        private static Bitmap FromHBitmap(IntPtr hbm) {
            using(Bitmap src = Image.FromHbitmap(hbm)) {
                Rectangle rect = new Rectangle(0, 0, src.Width, src.Height);
                BitmapData data = src.LockBits(rect, ImageLockMode.ReadOnly, src.PixelFormat);
                try {
                    if(src.PixelFormat == PixelFormat.Format32bppRgb && HasAlpha(data)) {
                        using(Bitmap argb = new Bitmap(data.Width, data.Height, data.Stride, PixelFormat.Format32bppArgb, data.Scan0)) {
                            return new Bitmap(argb);
                        }
                    }
                }
                finally {
                    src.UnlockBits(data);
                }
                return new Bitmap(src);
            }
        }

        private static bool HasAlpha(BitmapData data) {
            for(int y = 0; y < data.Height; y++) {
                IntPtr row = data.Scan0 + y * data.Stride;
                for(int x = 0; x < data.Width; x++) {
                    if(Marshal.ReadByte(row, x * 4 + 3) != 0) return true;
                }
            }
            return false;
        }

        // Scales bmp (which it disposes) to fit a size x size square. Also used for the standard
        // button bar's icons at sizes other than 16 and 24.
        internal static Bitmap Fit(Bitmap bmp, int size) {
            if(bmp == null || (bmp.Width == size && bmp.Height == size)) return bmp;
            Bitmap fitted = new Bitmap(size, size, PixelFormat.Format32bppArgb);
            using(Graphics g = Graphics.FromImage(fitted))
            using(ImageAttributes edges = new ImageAttributes()) {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                // Without this the filter reads past the edge and small icons get a faint frame.
                edges.SetWrapMode(WrapMode.TileFlipXY);
                float scale = Math.Min((float)size / bmp.Width, (float)size / bmp.Height);
                int w = Math.Max(1, (int)Math.Round(bmp.Width * scale)), h = Math.Max(1, (int)Math.Round(bmp.Height * scale));
                Rectangle dest = new Rectangle((size - w) / 2, (size - h) / 2, w, h);
                g.DrawImage(bmp, dest, 0, 0, bmp.Width, bmp.Height, GraphicsUnit.Pixel, edges);
            }
            bmp.Dispose();
            return fitted;
        }
    }
}
