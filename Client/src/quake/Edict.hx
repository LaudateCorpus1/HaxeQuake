package quake;

import js.html.ArrayBuffer;
import js.html.Float32Array;
import js.html.Int32Array;
import quake.Mod.MLink;
import quake.R.REntityState;
import quake.SV.EntFlag;

@:publicFields
class Edict {
    var num:Int;
    var free:Bool;
    var freetime:Float;
    var _v:ArrayBuffer;
    var _v_int:Int32Array;
    var _v_float:Float32Array;

    public var v(get,never):EdictVars;
    inline function get_v() return new EdictVars(this);

    var leafnums:Array<Int>;
    var baseline:REntityState;
    var area:MLink;

    var flags(get,set):EntFlag;
    inline function get_flags():EntFlag return cast Std.int(v.flags);
    inline function set_flags(v:EntFlag):EntFlag return {this.v.flags = v; v;}

    var items(get,set):Int;
    inline function get_items():Int return Std.int(v.items);
    inline function set_items(v:Int):Int return {this.v.items = v; v;}

    function new() {}
}
