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

@:publicFields
class GlobalVarOfs {
    @i static inline var self = 28; // edict
    @i static inline var other = 29; // edict
    @i static inline var world = 30; // edict
    @f static inline var time = 31; // float
    @f static inline var frametime = 32; // float
    @f static inline var force_retouch = 33; // float
    @i static inline var mapname = 34; // string
    @f static inline var deathmatch = 35; // float
    @f static inline var coop = 36; // float
    @f static inline var teamplay = 37; // float
    @f static inline var serverflags = 38; // float
    @f static inline var total_secrets = 39; // float
    @f static inline var total_monsters = 40; // float
    @f static inline var found_secrets = 41; // float
    @f static inline var killed_monsters = 42; // float

    @f static inline var parms = 43; // float[16]
    @f static inline var parms1 = 44;
    @f static inline var parms2 = 45;
    @f static inline var parms3 = 46;
    @f static inline var parms4 = 47;
    @f static inline var parms5 = 48;
    @f static inline var parms6 = 49;
    @f static inline var parms7 = 50;
    @f static inline var parms8 = 51;
    @f static inline var parms9 = 52;
    @f static inline var parms10 = 53;
    @f static inline var parms11 = 53;
    @f static inline var parms12 = 55;
    @f static inline var parms13 = 56;
    @f static inline var parms14 = 57;
    @f static inline var parms15 = 58;

    @f static inline var v_forward = 59; // vec3
    @f static inline var v_forward1 = 60;
    @f static inline var v_forward2 = 61;
    @f static inline var v_up = 62; // vec3
    @f static inline var v_up1 = 63;
    @f static inline var v_up2 = 64;
    @f static inline var v_right = 65; // vec3,
    @f static inline var v_right1 = 66;
    @f static inline var v_right2 = 67;
    @f static inline var trace_allsolid = 68; // float
    @f static inline var trace_startsolid = 69; // float
    @f static inline var trace_fraction = 70; // float
    @f static inline var trace_endpos = 71; // vec3
    @f static inline var trace_endpos1 = 72;
    @f static inline var trace_endpos2 = 73;
    @f static inline var trace_plane_normal = 74; // vec3
    @f static inline var trace_plane_normal1 = 75;
    @f static inline var trace_plane_normal2 = 76;
    @f static inline var trace_plane_dist = 77; // float
    @i static inline var trace_ent = 78; // edict
    @f static inline var trace_inopen = 79; // float
    @f static inline var trace_inwater = 80; // float
    @i static inline var msg_entity = 81; // edict
    @i static inline var main = 82; // func
    @i static inline var StartFrame = 83; // func
    @i static inline var PlayerPreThink = 84; // func
    @i static inline var PlayerPostThink = 85; // func
    @i static inline var ClientKill = 86; // func
    @i static inline var ClientConnect = 87; // func
    @i static inline var PutClientInServer = 88; // func
    @i static inline var ClientDisconnect = 89; // func
    @i static inline var SetNewParms = 90; // func
    @i static inline var SetChangeParms = 91; // func
}
