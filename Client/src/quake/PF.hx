package quake;

import quake.ED.Edict;
import quake.Protocol.SVC;
import quake.PR.EntVarOfs;
import quake.PR.GlobalVarOfs;
import quake.SV.EntFlag;
import quake.SV.DamageType;
import quake.SV.SolidType;
using Tools;


@:publicFields
class PF {

    static function VarString(first:Int) {
        var out = '';
        for (i in first...PR.argc)
            out += PR.GetString(PR.globals_int[4 + i * 3]);
        return out;
    }

    static function error() {
        Console.Print('====SERVER ERROR in ' + PR.GetString(PR.xfunction.name) + '\n' + VarString(0) + '\n');
        ED.Print(SV.server.edicts[PR.globals_int[GlobalVarOfs.self]]);
        Host.Error('Program error');
    }

    static function objerror() {
        Console.Print('====OBJECT ERROR in ' + PR.GetString(PR.xfunction.name) + '\n' + VarString(0) + '\n');
        ED.Print(SV.server.edicts[PR.globals_int[GlobalVarOfs.self]]);
        Host.Error('Program error');
    }

    static function makevectors() {
        var forward = [], right = [], up = [];
        Vec.AngleVectors([PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]], forward, right, up);
        for (i in 0...3) {
            PR.globals_float[GlobalVarOfs.v_forward + i] = forward[i];
            PR.globals_float[GlobalVarOfs.v_right + i] = right[i];
            PR.globals_float[GlobalVarOfs.v_up + i] = up[i];
        }
    }

    static function setorigin() {
        var e = SV.server.edicts[PR.globals_int[4]];
        e.v_float[EntVarOfs.origin] = PR.globals_float[7];
        e.v_float[EntVarOfs.origin1] = PR.globals_float[8];
        e.v_float[EntVarOfs.origin2] = PR.globals_float[9];
        SV.LinkEdict(e, false);
    }

    static function SetMinMaxSize(e:Edict, min:Vec, max:Vec):Void {
        if ((min[0] > max[0]) || (min[1] > max[1]) || (min[2] > max[2]))
            PR.RunError('backwards mins/maxs');
        ED.SetVector(e, EntVarOfs.mins, min);
        ED.SetVector(e, EntVarOfs.maxs, max);
        e.v_float[EntVarOfs.size] = max[0] - min[0];
        e.v_float[EntVarOfs.size1] = max[1] - min[1];
        e.v_float[EntVarOfs.size2] = max[2] - min[2];
        SV.LinkEdict(e, false);
    }

    static function setsize() {
        SetMinMaxSize(SV.server.edicts[PR.globals_int[4]],
            [PR.globals_float[7], PR.globals_float[8], PR.globals_float[9]],
            [PR.globals_float[10], PR.globals_float[11], PR.globals_float[12]]);
    }

    static function setmodel() {
        var e:Edict = SV.server.edicts[PR.globals_int[4]];
        var m = PR.GetString(PR.globals_int[7]);
        var i = 0;
        while (i < SV.server.model_precache.length) {
            if (SV.server.model_precache[i] == m)
                break;
            i++;
        }
        if (i == SV.server.model_precache.length)
            PR.RunError('no precache: ' + m + '\n');

        e.v_int[EntVarOfs.model] = PR.globals_int[7];
        e.v_float[EntVarOfs.modelindex] = i;
        var mod = SV.server.models[i];
        if (mod != null)
            SetMinMaxSize(e, mod.mins, mod.maxs);
        else
            SetMinMaxSize(e, Vec.origin, Vec.origin);
    }

    static function bprint() {
        Host.BroadcastPrint(VarString(0));
    }

    static function sprint() {
        var entnum = PR.globals_int[4];
        if ((entnum <= 0) || (entnum > SV.svs.maxclients)) {
            Console.Print('tried to sprint to a non-client\n');
            return;
        }
        var client = SV.svs.clients[entnum - 1];
        client.message.WriteByte(SVC.print);
        client.message.WriteString(VarString(1));
    }

    static function centerprint() {
        var entnum = PR.globals_int[4];
        if ((entnum <= 0) || (entnum > SV.svs.maxclients)) {
            Console.Print('tried to sprint to a non-client\n');
            return;
        }
        var client = SV.svs.clients[entnum - 1];
        client.message.WriteByte(SVC.centerprint);
        client.message.WriteString(VarString(1));
    }

    static function normalize() {
        var newvalue = [PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]];
        Vec.Normalize(newvalue);
        PR.globals_float[1] = newvalue[0];
        PR.globals_float[2] = newvalue[1];
        PR.globals_float[3] = newvalue[2];
    }

    static function vlen() {
        PR.globals_float[1] = Math.sqrt(PR.globals_float[4] * PR.globals_float[4] + PR.globals_float[5] * PR.globals_float[5] + PR.globals_float[6] * PR.globals_float[6]);
    }

    static function vectoyaw() {
        var value1 = PR.globals_float[4], value2 = PR.globals_float[5];
        if ((value1 == 0.0) && (value2 == 0.0)) {
            PR.globals_float[1] = 0.0;
            return;
        }
        var yaw = Std.int(Math.atan2(value2, value1) * 180.0 / Math.PI);
        if (yaw < 0)
            yaw += 360;
        PR.globals_float[1] = yaw;
    }

    static function vectoangles() {
        PR.globals_float[3] = 0.0;
        var value1 = [PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]];
        if ((value1[0] == 0.0) && (value1[1] == 0.0)) {
            if (value1[2] > 0.0)
                PR.globals_float[1] = 90.0;
            else
                PR.globals_float[1] = 270.0;
            PR.globals_float[2] = 0.0;
            return;
        }

        var yaw = Std.int(Math.atan2(value1[1], value1[0]) * 180.0 / Math.PI);
        if (yaw < 0)
            yaw += 360;
        var pitch = Std.int(Math.atan2(value1[2], Math.sqrt(value1[0] * value1[0] + value1[1] * value1[1])) * 180.0 / Math.PI);
        if (pitch < 0)
            pitch += 360;
        PR.globals_float[1] = pitch;
        PR.globals_float[2] = yaw;
    }

    static function random() {
        PR.globals_float[1] = Math.random();
    }

    static function particle() {
        SV.StartParticle([PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]],
            [PR.globals_float[7], PR.globals_float[8], PR.globals_float[9]],
            Std.int(PR.globals_float[10]), Std.int(PR.globals_float[13]));
    }

    static function ambientsound() {
        var samp = PR.GetString(PR.globals_int[7]);
        var i = 0;
        while (i < SV.server.sound_precache.length) {
            if (SV.server.sound_precache[i] == samp)
                break;
            i++;
        }
        if (i == SV.server.sound_precache.length) {
            Console.Print('no precache: ' + samp + '\n');
            return;
        }
        var signon = SV.server.signon;
        signon.WriteByte(SVC.spawnstaticsound);
        signon.WriteCoord(PR.globals_float[4]);
        signon.WriteCoord(PR.globals_float[5]);
        signon.WriteCoord(PR.globals_float[6]);
        signon.WriteByte(i);
        signon.WriteByte(Std.int(PR.globals_float[10] * 255));
        signon.WriteByte(Std.int(PR.globals_float[13] * 64));
    }

    static function sound() {
        SV.StartSound(SV.server.edicts[PR.globals_int[4]],
            Std.int(PR.globals_float[7]),
            PR.GetString(PR.globals_int[10]),
            Std.int(PR.globals_float[13] * 255),
            PR.globals_float[16]);
    }

    static function breakstatement() {
        Console.Print('break statement\n');
    }

    static function traceline() {
        var trace = SV.Move([PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]],
            Vec.origin, Vec.origin, [PR.globals_float[7], PR.globals_float[8], PR.globals_float[9]],
            Std.int(PR.globals_float[10]), SV.server.edicts[PR.globals_int[13]]);
        PR.globals_float[GlobalVarOfs.trace_allsolid] = (trace.allsolid) ? 1.0 : 0.0;
        PR.globals_float[GlobalVarOfs.trace_startsolid] = (trace.startsolid) ? 1.0 : 0.0;
        PR.globals_float[GlobalVarOfs.trace_fraction] = trace.fraction;
        PR.globals_float[GlobalVarOfs.trace_inwater] = (trace.inwater) ? 1.0 : 0.0;
        PR.globals_float[GlobalVarOfs.trace_inopen] = (trace.inopen) ? 1.0 : 0.0;
        PR.globals_float[GlobalVarOfs.trace_endpos] = trace.endpos[0];
        PR.globals_float[GlobalVarOfs.trace_endpos1] = trace.endpos[1];
        PR.globals_float[GlobalVarOfs.trace_endpos2] = trace.endpos[2];
        var plane = trace.plane;
        PR.globals_float[GlobalVarOfs.trace_plane_normal] = plane.normal[0];
        PR.globals_float[GlobalVarOfs.trace_plane_normal1] = plane.normal[1];
        PR.globals_float[GlobalVarOfs.trace_plane_normal2] = plane.normal[2];
        PR.globals_float[GlobalVarOfs.trace_plane_dist] = plane.dist;
        PR.globals_int[GlobalVarOfs.trace_ent] = (trace.ent != null) ? trace.ent.num : 0;
    }

    static function newcheckclient(check:Int):Int {
        if (check <= 0)
            check = 1;
        else if (check > SV.svs.maxclients)
            check = SV.svs.maxclients;
        var i = 1;
        if (check != SV.svs.maxclients)
            i += check;
        var ent;
        while (true) {
            if (i == SV.svs.maxclients + 1)
                i = 1;
            ent = SV.server.edicts[i];
            if (i == check)
                break;
            if (ent.free) {
                i++;
                continue;
            }
            if ((ent.v_float[EntVarOfs.health] <= 0.0) || ((ent.flags & EntFlag.notarget) != 0)) {
                i++;
                continue;
            }
            break;
        }
        checkpvs = Mod.LeafPVS(Mod.PointInLeaf([
                ent.v_float[EntVarOfs.origin] + ent.v_float[EntVarOfs.view_ofs],
                ent.v_float[EntVarOfs.origin1] + ent.v_float[EntVarOfs.view_ofs1],
                ent.v_float[EntVarOfs.origin2] + ent.v_float[EntVarOfs.view_ofs2]
            ], SV.server.worldmodel), SV.server.worldmodel);
        return i;
    }

    static var checkpvs:Array<Int>;

    static function checkclient() {
        if ((SV.server.time - SV.server.lastchecktime) >= 0.1) {
            SV.server.lastcheck = newcheckclient(SV.server.lastcheck);
            SV.server.lastchecktime = SV.server.time;
        }
        var ent = SV.server.edicts[SV.server.lastcheck];
        if ((ent.free) || (ent.v_float[EntVarOfs.health] <= 0.0)) {
            PR.globals_int[1] = 0;
            return;
        }
        var self = SV.server.edicts[PR.globals_int[GlobalVarOfs.self]];
        var l = Mod.PointInLeaf([
                self.v_float[EntVarOfs.origin] + self.v_float[EntVarOfs.view_ofs],
                self.v_float[EntVarOfs.origin1] + self.v_float[EntVarOfs.view_ofs1],
                self.v_float[EntVarOfs.origin2] + self.v_float[EntVarOfs.view_ofs2]
            ], SV.server.worldmodel).num - 1;
        if ((l < 0) || ((checkpvs[l >> 3] & (1 << (l & 7))) == 0)) {
            PR.globals_int[1] = 0;
            return;
        }
        PR.globals_int[1] = ent.num;
    }

    static function stuffcmd() {
        var entnum = PR.globals_int[4];
        if ((entnum <= 0) || (entnum > SV.svs.maxclients))
            PR.RunError('Parm 0 not a client');
        var client = SV.svs.clients[entnum - 1];
        client.message.WriteByte(SVC.stufftext);
        client.message.WriteString(PR.GetString(PR.globals_int[7]));
    }

    static function localcmd() {
        Cmd.text += PR.GetString(PR.globals_int[4]);
    }

    static function cvar() {
        var v = Cvar.FindVar(PR.GetString(PR.globals_int[4]));
        PR.globals_float[1] = v != null ? v.value : 0.0;
    }

    static function cvar_set() {
        Cvar.Set(PR.GetString(PR.globals_int[4]), PR.GetString(PR.globals_int[7]));
    }

    static function findradius() {
        var chain = 0;
        var org = [PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]], eorg = [];
        var rad = PR.globals_float[7];
        for (i in 1...SV.server.num_edicts) {
            var ent = SV.server.edicts[i];
            if (ent.free)
                continue;
            if (ent.v_float[EntVarOfs.solid] == SolidType.not)
                continue;
            eorg[0] = org[0] - (ent.v_float[EntVarOfs.origin] + (ent.v_float[EntVarOfs.mins] + ent.v_float[EntVarOfs.maxs]) * 0.5);
            eorg[1] = org[1] - (ent.v_float[EntVarOfs.origin1] + (ent.v_float[EntVarOfs.mins1] + ent.v_float[EntVarOfs.maxs1]) * 0.5);
            eorg[2] = org[2] - (ent.v_float[EntVarOfs.origin2] + (ent.v_float[EntVarOfs.mins2] + ent.v_float[EntVarOfs.maxs2]) * 0.5);
            if (Math.sqrt(eorg[0] * eorg[0] + eorg[1] * eorg[1] + eorg[2] * eorg[2]) > rad)
                continue;
            ent.v_int[EntVarOfs.chain] = chain;
            chain = i;
        }
        PR.globals_int[1] = chain;
    }

    static function dprint() {
        Console.DPrint(VarString(0));
    }

    static function ftos() {
        var v = PR.globals_float[4];
        if (v == Math.floor(v))
            PR.TempString(Std.string(v));
        else
            PR.TempString(v.toFixed(1));
        PR.globals_int[1] = PR.string_temp;
    }

    static function fabs() {
        PR.globals_float[1] = Math.abs(PR.globals_float[4]);
    }

    static function vtos() {
        PR.TempString(PR.globals_float[4].toFixed(1)
            + ' ' + PR.globals_float[5].toFixed(1)
            + ' ' + PR.globals_float[6].toFixed(1));
        PR.globals_int[1] = PR.string_temp;
    }

    static function Spawn() {
        PR.globals_int[1] = ED.Alloc().num;
    }

    static function Remove() {
        ED.Free(SV.server.edicts[PR.globals_int[4]]);
    }

    static function Find() {
        var e = PR.globals_int[4];
        var f = PR.globals_int[7];
        var s = PR.GetString(PR.globals_int[10]);
        for (e in (e + 1)...SV.server.num_edicts) {
            var ed = SV.server.edicts[e];
            if (ed.free)
                continue;
            if (PR.GetString(ed.v_int[f]) == s) {
                PR.globals_int[1] = ed.num;
                return;
            }
        }
        PR.globals_int[1] = 0;
    }

    static function MoveToGoal() {
        var ent = SV.server.edicts[PR.globals_int[GlobalVarOfs.self]];
        if ((ent.flags & (EntFlag.onground + EntFlag.fly + EntFlag.swim)) == 0) {
            PR.globals_float[1] = 0.0;
            return;
        }
        var goal = SV.server.edicts[ent.v_int[EntVarOfs.goalentity]];
        var dist = PR.globals_float[4];
        if ((ent.v_int[EntVarOfs.enemy] != 0) && (SV.CloseEnough(ent, goal, dist)))
            return;
        if ((Math.random() >= 0.75) || !SV.StepDirection(ent, ent.v_float[EntVarOfs.ideal_yaw], dist))
            SV.NewChaseDir(ent, goal, dist);
    }

    static function precache_file() {
        PR.globals_int[1] = PR.globals_int[4];
    }

    static function precache_sound() {
        var s = PR.GetString(PR.globals_int[4]);
        PR.globals_int[1] = PR.globals_int[4];
        PR.CheckEmptyString(s);
        var i = 0;
        while (i < SV.server.sound_precache.length) {
            if (SV.server.sound_precache[i] == s)
                return;
            i++;
        }
        SV.server.sound_precache[i] = s;
    }

    static function precache_model() {
        if (!SV.server.loading)
            PR.RunError('Precache_*: Precache can only be done in spawn functions');
        var s = PR.GetString(PR.globals_int[4]);
        PR.globals_int[1] = PR.globals_int[4];
        PR.CheckEmptyString(s);
        var i = 0;
        while (i < SV.server.model_precache.length) {
            if (SV.server.model_precache[i] == s)
                return;
            i++;
        }
        SV.server.model_precache[i] = s;
        SV.server.models[i] = Mod.ForName(s, true);
    }

    static function coredump() {
        ED.PrintEdicts();
    }

    static function traceon() {
        PR.trace = true;
    }

    static function traceoff() {
        PR.trace = false;
    }

    static function eprint() {
        ED.Print(SV.server.edicts[Std.int(PR.globals_float[4])]);
    }

    static function walkmove() {
        var ent = SV.server.edicts[PR.globals_int[GlobalVarOfs.self]];
        if ((ent.flags & (EntFlag.onground + EntFlag.fly + EntFlag.swim)) == 0) {
            PR.globals_float[1] = 0.0;
            return;
        }
        var yaw = PR.globals_float[4] * Math.PI / 180.0;
        var dist = PR.globals_float[7];
        var oldf = PR.xfunction;
        PR.globals_float[1] = SV.movestep(ent, [Math.cos(yaw) * dist, Math.sin(yaw) * dist], true).toInt();
        PR.xfunction = oldf;
        PR.globals_int[GlobalVarOfs.self] = ent.num;
    }

    static function droptofloor() {
        var ent = SV.server.edicts[PR.globals_int[GlobalVarOfs.self]];
        var trace = SV.Move(ED.Vector(ent, EntVarOfs.origin),
            ED.Vector(ent, EntVarOfs.mins), ED.Vector(ent, EntVarOfs.maxs),
            [ent.v_float[EntVarOfs.origin], ent.v_float[EntVarOfs.origin1], ent.v_float[EntVarOfs.origin2] - 256.0], 0, ent);
        if ((trace.fraction == 1.0) || (trace.allsolid)) {
            PR.globals_float[1] = 0.0;
            return;
        }
        ED.SetVector(ent, EntVarOfs.origin, trace.endpos);
        SV.LinkEdict(ent, false);
        ent.flags = ent.flags | EntFlag.onground;
        ent.v_int[EntVarOfs.groundentity] = trace.ent.num;
        PR.globals_float[1] = 1.0;
    }

    static function lightstyle() {
        var style = Std.int(PR.globals_float[4]);
        var val = PR.GetString(PR.globals_int[7]);
        SV.server.lightstyles[style] = val;
        if (SV.server.loading)
            return;
        for (i in 0...SV.svs.maxclients) {
            var client = SV.svs.clients[i];
            if (!client.active && !client.spawned)
                continue;
            client.message.WriteByte(SVC.lightstyle);
            client.message.WriteByte(style);
            client.message.WriteString(val);
        }
    }

    static function rint() {
        var f = PR.globals_float[4];
        PR.globals_float[1] = Std.int(f >= 0.0 ? f + 0.5 : f - 0.5);
    }

    static function floor() {
        PR.globals_float[1] = Math.floor(PR.globals_float[4]);
    }

    static function ceil() {
        PR.globals_float[1] = Math.ceil(PR.globals_float[4]);
    }

    static function checkbottom() {
        PR.globals_float[1] = SV.CheckBottom(SV.server.edicts[PR.globals_int[4]]).toInt();
    }

    static function pointcontents() {
        PR.globals_float[1] = SV.PointContents([PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]]);
    }

    static function nextent() {
        for (i in (PR.globals_int[4] + 1)...SV.server.num_edicts) {
            if (!SV.server.edicts[i].free) {
                PR.globals_int[1] = i;
                return;
            }
        }
        PR.globals_int[1] = 0;
    }

    static function aim() {
        var ent = SV.server.edicts[PR.globals_int[4]];
        var start = [ent.v_float[EntVarOfs.origin], ent.v_float[EntVarOfs.origin1], ent.v_float[EntVarOfs.origin2] + 20.0];
        var dir = [PR.globals_float[GlobalVarOfs.v_forward], PR.globals_float[GlobalVarOfs.v_forward1], PR.globals_float[GlobalVarOfs.v_forward2]];
        var end = [start[0] + 2048.0 * dir[0], start[1] + 2048.0 * dir[1], start[2] + 2048.0 * dir[2]];
        var tr = SV.Move(start, Vec.origin, Vec.origin, end, 0, ent);
        if (tr.ent != null) {
            if ((tr.ent.v_float[EntVarOfs.takedamage] == DamageType.aim) &&
                ((Host.teamplay.value == 0) || (ent.v_float[EntVarOfs.team] <= 0) ||
                (ent.v_float[EntVarOfs.team] != tr.ent.v_float[EntVarOfs.team]))) {
                PR.globals_float[1] = dir[0];
                PR.globals_float[2] = dir[1];
                PR.globals_float[3] = dir[2];
                return;
            }
        }
        var bestdir = [dir[0], dir[1], dir[2]];
        var bestdist = SV.aim.value;
        var bestent, end = [];
        for (i in 1...SV.server.num_edicts) {
            var check = SV.server.edicts[i];
            if (check.v_float[EntVarOfs.takedamage] != DamageType.aim)
                continue;
            if (check == ent)
                continue;
            if ((Host.teamplay.value != 0) && (ent.v_float[EntVarOfs.team] > 0) && (ent.v_float[EntVarOfs.team] == check.v_float[EntVarOfs.team]))
                continue;
            end[0] = check.v_float[EntVarOfs.origin] + 0.5 * (check.v_float[EntVarOfs.mins] + check.v_float[EntVarOfs.maxs]);
            end[1] = check.v_float[EntVarOfs.origin1] + 0.5 * (check.v_float[EntVarOfs.mins1] + check.v_float[EntVarOfs.maxs1]);
            end[2] = check.v_float[EntVarOfs.origin2] + 0.5 * (check.v_float[EntVarOfs.mins2] + check.v_float[EntVarOfs.maxs2]);
            dir[0] = end[0] - start[0];
            dir[1] = end[1] - start[1];
            dir[2] = end[2] - start[2];
            Vec.Normalize(dir);
            var dist = dir[0] * bestdir[0] + dir[1] * bestdir[1] + dir[2] * bestdir[2];
            if (dist < bestdist)
                continue;
            tr = SV.Move(start, Vec.origin, Vec.origin, end, 0, ent);
            if (tr.ent == check) {
                bestdist = dist;
                bestent = check;
            }
        }
        if (bestent != null) {
            dir[0] = bestent.v_float[EntVarOfs.origin] - ent.v_float[EntVarOfs.origin];
            dir[1] = bestent.v_float[EntVarOfs.origin1] - ent.v_float[EntVarOfs.origin1];
            dir[2] = bestent.v_float[EntVarOfs.origin2] - ent.v_float[EntVarOfs.origin2];
            var dist = dir[0] * bestdir[0] + dir[1] * bestdir[1] + dir[2] * bestdir[2];
            end[0] = bestdir[0] * dist;
            end[1] = bestdir[1] * dist;
            end[2] = dir[2];
            Vec.Normalize(end);
            PR.globals_float[1] = end[0];
            PR.globals_float[2] = end[1];
            PR.globals_float[3] = end[2];
            return;
        }
        PR.globals_float[1] = bestdir[0];
        PR.globals_float[2] = bestdir[1];
        PR.globals_float[3] = bestdir[2];
    }

    static function changeyaw() {
        var ent = SV.server.edicts[PR.globals_int[GlobalVarOfs.self]];
        var current = Vec.Anglemod(ent.v_float[EntVarOfs.angles1]);
        var ideal = ent.v_float[EntVarOfs.ideal_yaw];
        if (current == ideal)
            return;
        var move = ideal - current;
        if (ideal > current) {
            if (move >= 180.0)
                move -= 360.0;
        }
        else if (move <= -180.0)
            move += 360.0;
        var speed = ent.v_float[EntVarOfs.yaw_speed];
        if (move > 0.0) {
            if (move > speed)
                move = speed;
        }
        else if (move < -speed)
            move = -speed;
        ent.v_float[EntVarOfs.angles1] = Vec.Anglemod(current + move);
    }

    static function WriteDest() {
        switch (Std.int(PR.globals_float[4])) {
            case 0: // broadcast
                return SV.server.datagram;
            case 1: // one
                var entnum = PR.globals_int[GlobalVarOfs.msg_entity];
                if ((entnum <= 0) || (entnum > SV.svs.maxclients))
                    PR.RunError('WriteDest: not a client');
                return SV.svs.clients[entnum - 1].message;
            case 2: // all
                return SV.server.reliable_datagram;
            case 3: // init
                return SV.server.signon;
            default:
                PR.RunError('WriteDest: bad destination');
                return null;
        }
    }

    static function WriteByte() WriteDest().WriteByte(Std.int(PR.globals_float[7]));
    static function WriteChar() WriteDest().WriteChar(Std.int(PR.globals_float[7]));
    static function WriteShort() WriteDest().WriteShort(Std.int(PR.globals_float[7]));
    static function WriteLong() WriteDest().WriteLong(Std.int(PR.globals_float[7]));
    static function WriteAngle() WriteDest().WriteAngle(PR.globals_float[7]);
    static function WriteCoord() WriteDest().WriteCoord(PR.globals_float[7]);
    static function WriteString() WriteDest().WriteString(PR.GetString(PR.globals_int[7]));
    static function WriteEntity() WriteDest().WriteShort(PR.globals_int[7]);

    static function makestatic() {
        var ent:Edict = SV.server.edicts[PR.globals_int[4]];
        var message = SV.server.signon;
        message.WriteByte(SVC.spawnstatic);
        message.WriteByte(SV.ModelIndex(PR.GetString(ent.v_int[EntVarOfs.model])));
        message.WriteByte(Std.int(ent.v_float[EntVarOfs.frame]));
        message.WriteByte(Std.int(ent.v_float[EntVarOfs.colormap]));
        message.WriteByte(Std.int(ent.v_float[EntVarOfs.skin]));
        message.WriteCoord(ent.v_float[EntVarOfs.origin]);
        message.WriteAngle(ent.v_float[EntVarOfs.angles]);
        message.WriteCoord(ent.v_float[EntVarOfs.origin1]);
        message.WriteAngle(ent.v_float[EntVarOfs.angles1]);
        message.WriteCoord(ent.v_float[EntVarOfs.origin2]);
        message.WriteAngle(ent.v_float[EntVarOfs.angles2]);
        ED.Free(ent);
    }

    static function setspawnparms() {
        var i = PR.globals_int[4];
        if ((i <= 0) || (i > SV.svs.maxclients))
            PR.RunError('Entity is not a client');
        var spawn_parms = SV.svs.clients[i - 1].spawn_parms;
        for (i in 0...16)
            PR.globals_float[GlobalVarOfs.parms + i] = spawn_parms[i];
    }

    static function changelevel() {
        if (SV.svs.changelevel_issued)
            return;
        SV.svs.changelevel_issued = true;
        Cmd.text += 'changelevel ' + PR.GetString(PR.globals_int[4]) + '\n';
    }

    static function Fixme() {
        PR.RunError('unimplemented builtin');
    }

    static var builtin:Array<Void->Void> = [
        Fixme,
        makevectors,
        setorigin,
        setmodel,
        setsize,
        Fixme,
        breakstatement,
        random,
        sound,
        normalize,
        error,
        objerror,
        vlen,
        vectoyaw,
        Spawn,
        Remove,
        traceline,
        checkclient,
        Find,
        precache_sound,
        precache_model,
        stuffcmd,
        findradius,
        bprint,
        sprint,
        dprint,
        ftos,
        vtos,
        coredump,
        traceon,
        traceoff,
        eprint,
        walkmove,
        Fixme,
        droptofloor,
        lightstyle,
        rint,
        floor,
        ceil,
        Fixme,
        checkbottom,
        pointcontents,
        Fixme,
        fabs,
        aim,
        cvar,
        localcmd,
        nextent,
        particle,
        changeyaw,
        Fixme,
        vectoangles,
        WriteByte,
        WriteChar,
        WriteShort,
        WriteLong,
        WriteCoord,
        WriteAngle,
        WriteString,
        WriteEntity,
        Fixme,
        Fixme,
        Fixme,
        Fixme,
        Fixme,
        Fixme,
        Fixme,
        MoveToGoal,
        precache_file,
        makestatic,
        changelevel,
        Fixme,
        cvar_set,
        centerprint,
        ambientsound,
        precache_model,
        precache_sound,
        precache_file,
        setspawnparms
    ];

}
