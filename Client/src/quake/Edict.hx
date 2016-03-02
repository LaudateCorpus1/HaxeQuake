package quake;

import js.html.ArrayBuffer;
import js.html.Float32Array;
import js.html.Int32Array;
import quake.Entity.EntityState;
import quake.SV.EntFlag;
import quake.Edict;

@:publicFields
class Edict {
    var num:Int;
    var free:Bool;
    var area:EdictLink;
    var leafnums:Array<Int>;
    var baseline:EntityState;
    var freetime:Float;
    public var v(default,null):EdictVars;

    var flags(get,set):EntFlag;
    inline function get_flags():EntFlag return cast Std.int(v.flags);
    inline function set_flags(v:EntFlag):EntFlag return {this.v.flags = v; v;}

    var items(get,set):Int;
    inline function get_items():Int return Std.int(v.items);
    inline function set_items(v:Int):Int return {this.v.items = v; v;}

    function new(num:Int) {
        this.num = num;
        this.free = false;
        this.area = new EdictLink();
        this.area.ent = this;
        this.leafnums = [];
        this.baseline = new EntityState();
        this.freetime = 0.0;
        this.v = new EdictVars(new ArrayBuffer(PR.entityfields << 2));
    }

    inline function GetVector(o:Int):Vec {
        return cast new Float32Array(v.buffer.slice(o * 4, (o * 4 + 3 * 4)));
    }

    inline function SetVector(ofs:Int, vec:Vec):Void {
        v.floats.set(vec, ofs);
    }

    function Clear():Void {
        for (i in 0...PR.entityfields)
            v.ints[i] = 0;
        free = false;
    }
}

@:publicFields
class EdictLink {
    var prev:EdictLink;
    var next:EdictLink;
    var ent:Edict;
    function new() {}
}
