package quake;

import quake.PR.PROffset;

@:build(quake.GlobalVarsMacro.build())
abstract GlobalVars(Int) {
    public inline function SetReturnVector(v:Vec):Void {
        PR._globals_float[OFS_RETURN] = v[0];
        PR._globals_float[OFS_RETURN + 1] = v[1];
        PR._globals_float[OFS_RETURN + 2] = v[2];
    }

    public inline function SetReturnFloat(f:Float):Void {
        PR._globals_float[OFS_RETURN] = f;
    }

    public inline function SetReturnInt(i:Int):Void {
        PR._globals_int[OFS_RETURN] = i;
    }

    public inline function GetVector(ofs:Int):Vec {
        return Vec.of(PR._globals_float[ofs], PR._globals_float[ofs + 1], PR._globals_float[ofs + 2]);
    }

    public inline function GetFloat(ofs:Int):Float {
        return PR._globals_float[ofs];
    }

    public inline function GetIntFromFloat(ofs:Int):Int {
        return Std.int(PR._globals_float[ofs]);
    }

    public inline function GetInt(ofs:Int):Int {
        return PR._globals_int[ofs];
    }
}
