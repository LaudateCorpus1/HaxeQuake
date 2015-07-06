package quake;

import js.Browser.window;
import js.Browser.document;
import js.Error;
import js.html.Event;
import js.html.KeyboardEvent;
import js.html.MouseEvent;
import js.html.WheelEvent;

@:expose("Sys")
@:publicFields
class Sys {
    static var events = [
        'onbeforeunload',
        'oncontextmenu',
        'onfocus',
        'onkeydown',
        'onkeyup',
        'onmousedown',
        'onmouseup',
        'onunload',
        'onwheel'
    ];

    static var oldtime:Float;
    static var frame:Int;
    static var scantokey:Map<Int,Int>;

    static function Quit():Void {
        if (frame != null)
            window.clearInterval(frame);
        for (e in events)
            Reflect.setField(window, e, null);
        (untyped Host).Shutdown();
        document.body.style.cursor = 'auto';
        VID.mainwindow.style.display = 'none';
        if ((untyped COM).registered.value != 0)
            document.getElementById('end2').style.display = 'inline';
        else
            document.getElementById('end1').style.display = 'inline';
        throw new Error();
    }

    static function Print(text:String):Void {
        if (window.console != null)
            window.console.log(text);
    }

    static function Error(text:String):Void {
        if (frame != null)
            window.clearInterval(frame);
        for (e in events)
            Reflect.setField(window, e, null);
        if (untyped Host.initialized)
            untyped Host.Shutdown();
        document.body.style.cursor = 'auto';
        var i = (untyped Con).text.length - 25;
        if (i < 0)
            i = 0;
        if (window.console != null) {
            while (i < (untyped Con).text.length)
                window.console.log((untyped Con).text[i++].text);
        }
        window.alert(text);
        throw new Error(text);
    }

    static function FloatTime():Float {
        return Date.now().getTime() * 0.001 - oldtime;
    }

    static function main():Void {
        window.onload = function() {
            var cmdline = StringTools.urlDecode(document.location.search);
            var location = document.location;
            var argv = [location.href.substring(0, location.href.length - location.search.length)];
            if (cmdline.charCodeAt(0) == 63)
            {
                var text = '';
                var quotes = false;
                for (i in 1...cmdline.length)
                {
                    var c = cmdline.charCodeAt(i);
                    if ((c < 32) || (c > 127))
                        continue;
                    if (c == 34)
                    {
                        quotes = !quotes;
                        continue;
                    }
                    if ((quotes == false) && (c == 32))
                    {
                        if (text.length == 0)
                            continue;
                        argv[argv.length] = text;
                        text = '';
                        continue;
                    }
                    text += cmdline.charAt(i);
                }
                if (text.length != 0)
                    argv[argv.length] = text;
            }
            (untyped COM).InitArgv(argv);

            var elem = document.documentElement;
            VID.width = (elem.clientWidth <= 320) ? 320 : elem.clientWidth;
            VID.height = (elem.clientHeight <= 200) ? 200 : elem.clientHeight;

            Sys.scantokey = new Map();
            Sys.scantokey[8] = (untyped Key).k.backspace;
            Sys.scantokey[9] = (untyped Key).k.tab;
            Sys.scantokey[13] = (untyped Key).k.enter;
            Sys.scantokey[16] = (untyped Key).k.shift;
            Sys.scantokey[17] = (untyped Key).k.ctrl;
            Sys.scantokey[18] = (untyped Key).k.alt;
            Sys.scantokey[19] = (untyped Key).k.pause;
            Sys.scantokey[27] = (untyped Key).k.escape;
            Sys.scantokey[32] = (untyped Key).k.space;
            Sys.scantokey[33] = Sys.scantokey[105] = (untyped Key).k.pgup;
            Sys.scantokey[34] = Sys.scantokey[99] = (untyped Key).k.pgdn;
            Sys.scantokey[35] = Sys.scantokey[97] = (untyped Key).k.end;
            Sys.scantokey[36] = Sys.scantokey[103] = (untyped Key).k.home;
            Sys.scantokey[37] = Sys.scantokey[100] = (untyped Key).k.leftarrow;
            Sys.scantokey[38] = Sys.scantokey[104] = (untyped Key).k.uparrow;
            Sys.scantokey[39] = Sys.scantokey[102] = (untyped Key).k.rightarrow;
            Sys.scantokey[40] = Sys.scantokey[98] = (untyped Key).k.downarrow;
            Sys.scantokey[45] = Sys.scantokey[96] = (untyped Key).k.ins;
            Sys.scantokey[46] = Sys.scantokey[110] = (untyped Key).k.del;
            for (i in 48...58)
                Sys.scantokey[i] = i; // 0-9
            Sys.scantokey[59] = Sys.scantokey[186] = 59; // ;
            Sys.scantokey[61] = Sys.scantokey[187] = 61; // =
            for (i in 65...91)
                Sys.scantokey[i] = i + 32; // a-z
            Sys.scantokey[106] = 42; // *
            Sys.scantokey[107] = 43; // +
            Sys.scantokey[109] = Sys.scantokey[173] = Sys.scantokey[189] = 45; // -
            Sys.scantokey[111] = Sys.scantokey[191] = 47; // /
            for (i in 112...124)
                Sys.scantokey[i] = i - 112 + (untyped Key).k.f1; // f1-f12
            Sys.scantokey[188] = 44; // ,
            Sys.scantokey[190] = 46; // .
            Sys.scantokey[192] = 96; // `
            Sys.scantokey[219] = 91; // [
            Sys.scantokey[220] = 92; // backslash
            Sys.scantokey[221] = 93; // ]
            Sys.scantokey[222] = 39; // '

            Sys.oldtime = Date.now().getTime() * 0.001;

            Sys.Print('Host.Init\n');
            (untyped Host).Init();

            for (e in events)
                Reflect.setField(window, e, Reflect.field(Sys, e));

            frame = window.setInterval((untyped Host).Frame, 1000.0 / 60.0);
        }
    }

    static function onbeforeunload():String {
        return 'Are you sure you want to quit?';
    }

    static function oncontextmenu(e:MouseEvent):Void {
        e.preventDefault();
    }

    static function onfocus():Void {
        for (i in 0...256) {
            (untyped Key).Event(i);
            (untyped Key).down[i] = false;
        }
    }

    static function onkeydown(e:KeyboardEvent):Void {
        var key = scantokey[e.keyCode];
        if (key == null)
            return;
        (untyped Key).Event(key, true);
        e.preventDefault();
    }

    static function onkeyup(e:KeyboardEvent):Void
    {
        var key = scantokey[e.keyCode];
        if (key == null)
            return;
        (untyped Key).Event(key);
        e.preventDefault();
    }

    static function onmousedown(e:MouseEvent):Void {
        var key = switch (e.which) {
            case 1:
                (untyped Key).k.mouse1;
            case 2:
                (untyped Key).k.mouse3;
            case 3:
                (untyped Key).k.mouse2;
            default:
                return;
        };
        (untyped Key).Event(key, true);
        e.preventDefault();
    }

    static function onmouseup(e:MouseEvent):Void
    {
        var key = switch (e.which) {
            case 1:
                (untyped Key).k.mouse1;
            case 2:
                (untyped Key).k.mouse3;
            case 3:
                (untyped Key).k.mouse2;
            default:
                return;
        };
        (untyped Key).Event(key);
        e.preventDefault();
    }

    static function onunload() {
        (untyped Host).Shutdown();
    }

    static function onwheel(e:WheelEvent):Void {
        var key = e.deltaY < 0 ? (untyped Key).k.mwheelup : (untyped Key).k.mwheeldown;
        (untyped Key).Event(key, true);
        (untyped Key).Event(key);
        e.preventDefault();
    }
}
