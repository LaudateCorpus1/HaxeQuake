package quake;

import js.html.ArrayBuffer;
import js.html.Float32Array;
import js.html.Int32Array;

import quake.PR.PROffset;

@:build(quake.GlobalVarsMacro.build())
class GlobalVars {
    public var buffer(default,null):ArrayBuffer;
    public var floats(default,null):Float32Array;
    public var ints(default,null):Int32Array;

    public function new(buf) {
        buffer = buf;
        floats = new Float32Array(buf);
        ints = new Int32Array(buf);
    }

    public inline function SetReturnVector(v:Vec):Void {
        floats[OFS_RETURN] = v[0];
        floats[OFS_RETURN + 1] = v[1];
        floats[OFS_RETURN + 2] = v[2];
    }

    public inline function SetReturnFloat(f:Float):Void {
        floats[OFS_RETURN] = f;
    }

    public inline function SetReturnInt(i:Int):Void {
        ints[OFS_RETURN] = i;
    }

    public inline function GetVector(ofs:Int):Vec {
        return Vec.of(floats[ofs], floats[ofs + 1], floats[ofs + 2]);
    }

    public inline function GetFloat(ofs:Int):Float {
        return floats[ofs];
    }

    public inline function GetIntFromFloat(ofs:Int):Int {
        return Std.int(floats[ofs]);
    }

    public inline function GetInt(ofs:Int):Int {
        return ints[ofs];
    }
}
