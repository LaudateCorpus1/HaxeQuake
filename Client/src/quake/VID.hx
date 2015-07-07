package quake;

import js.Browser.document;
import js.html.ArrayBuffer;
import js.html.CanvasElement;
import js.html.Uint32Array;
import js.html.Uint8Array;

@:expose("VID")
@:publicFields
class VID {
    static var mainwindow:CanvasElement;
    static var width:Int;
    static var height:Int;

    static var d_8to24table = new Uint32Array(new ArrayBuffer(1024));

    static function SetPalette() {
        var palette = (untyped COM).LoadFile('gfx/palette.lmp');
        if (palette == null)
            Sys.Error('Couldn\'t load gfx/palette.lmp');
        var pal = new Uint8Array(palette);
        var src = 0;
        for (i in 0...256) {
            d_8to24table[i] = pal[src] + (pal[src + 1] << 8) + (pal[src + 2] << 16);
            src += 3;
        }
    }

    static function Init() {
        document.getElementById('progress').style.display = 'none';
        GL.Init();
        SetPalette();
    }
}
