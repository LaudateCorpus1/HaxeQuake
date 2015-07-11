package quake;

@:build(quake.GlobalVarOfsMacro.build())
abstract GlobalVarOfs<@:const TViewField>(Int) to Int {
    @i var self = 28; // edict
    @i var other = 29; // edict
    @i var world = 30; // edict
    @f var time = 31; // float
    @f var frametime = 32; // float
    @f var force_retouch = 33; // float
    @i var mapname = 34; // string
    @f var deathmatch = 35; // float
    @f var coop = 36; // float
    @f var teamplay = 37; // float
    @f var serverflags = 38; // float
    @f var total_secrets = 39; // float
    @f var total_monsters = 40; // float
    @f var found_secrets = 41; // float
    @f var killed_monsters = 42; // float
    @f var parms = 43; // float[16]
    @f var v_forward = 59; // vec3
    @f var v_forward1 = 60;
    @f var v_forward2 = 61;
    @f var v_up = 62; // vec3
    @f var v_up1 = 63;
    @f var v_up2 = 64;
    @f var v_right = 65; // vec3,
    @f var v_right1 = 66;
    @f var v_right2 = 67;
    @f var trace_allsolid = 68; // float
    @f var trace_startsolid = 69; // float
    @f var trace_fraction = 70; // float
    @f var trace_endpos = 71; // vec3
    @f var trace_endpos1 = 72;
    @f var trace_endpos2 = 73;
    @f var trace_plane_normal = 74; // vec3
    @f var trace_plane_normal1 = 75;
    @f var trace_plane_normal2 = 76;
    @f var trace_plane_dist = 77; // float
    @i var trace_ent = 78; // edict
    @f var trace_inopen = 79; // float
    @f var trace_inwater = 80; // float
    @i var msg_entity = 81; // edict
    @i var main = 82; // func
    @i var StartFrame = 83; // func
    @i var PlayerPreThink = 84; // func
    @i var PlayerPostThink = 85; // func
    @i var ClientKill = 86; // func
    @i var ClientConnect = 87; // func
    @i var PutClientInServer = 88; // func
    @i var ClientDisconnect = 89; // func
    @i var SetNewParms = 90; // func
    @i var SetChangeParms = 91; // func
}
