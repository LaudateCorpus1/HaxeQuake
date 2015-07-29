package quake;

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
