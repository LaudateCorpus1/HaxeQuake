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

    public inline function GetParms():Array<Float> {
        return [
            parms,
            parms1,
            parms2,
            parms3,
            parms4,
            parms5,
            parms6,
            parms7,
            parms8,
            parms9,
            parms10,
            parms11,
            parms12,
            parms13,
            parms14,
            parms15
        ];
    }

    public inline function SetParms(values:Array<Float>):Void {
        parms = values[0];
        parms1 = values[1];
        parms2 = values[2];
        parms3 = values[3];
        parms4 = values[4];
        parms5 = values[5];
        parms6 = values[6];
        parms7 = values[7];
        parms8 = values[8];
        parms9 = values[9];
        parms10 = values[10];
        parms11 = values[11];
        parms12 = values[12];
        parms13 = values[13];
        parms14 = values[14];
        parms15 = values[15];
    }
}
