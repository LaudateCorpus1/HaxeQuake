package quake;

import quake.ED.Edict;
using Tools;

@:expose("PF")
@:publicFields
class PF {

static function VarString(first:Int) {
	var out = '';
	for (i in first...PR.argc)
		out += PR.GetString(PR.globals_int[4 + i * 3]);
	return out;
}

static function error() {
	Console.Print('====SERVER ERROR in ' + PR.GetString(PR.xfunction.name) + '\n' + PF.VarString(0) + '\n');
	ED.Print((untyped SV).server.edicts[PR.globals_int[PR.globalvars.self]]);
	(untyped Host).Error('Program error');
}

static function objerror() {
	Console.Print('====OBJECT ERROR in ' + PR.GetString(PR.xfunction.name) + '\n' + PF.VarString(0) + '\n');
	ED.Print((untyped SV).server.edicts[PR.globals_int[PR.globalvars.self]]);
	(untyped Host).Error('Program error');
}

static function makevectors() {
	var forward = [], right = [], up = [];
	Vec.AngleVectors([PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]], forward, right, up);
	for (i in 0...3) {
		PR.globals_float[PR.globalvars.v_forward + i] = forward[i];
		PR.globals_float[PR.globalvars.v_right + i] = right[i];
		PR.globals_float[PR.globalvars.v_up + i] = up[i];
	}
}

static function setorigin() {
	var e = (untyped SV).server.edicts[PR.globals_int[4]];
	e.v_float[PR.entvars.origin] = PR.globals_float[7];
	e.v_float[PR.entvars.origin1] = PR.globals_float[8];
	e.v_float[PR.entvars.origin2] = PR.globals_float[9];
	(untyped SV).LinkEdict(e);
}

static function SetMinMaxSize(e:Edict, min:Vec, max:Vec):Void {
	if ((min[0] > max[0]) || (min[1] > max[1]) || (min[2] > max[2]))
		PR.RunError('backwards mins/maxs');
	ED.SetVector(e, PR.entvars.mins, min);
	ED.SetVector(e, PR.entvars.maxs, max);
	e.v_float[PR.entvars.size] = max[0] - min[0];
	e.v_float[PR.entvars.size1] = max[1] - min[1];
	e.v_float[PR.entvars.size2] = max[2] - min[2];
	(untyped SV).LinkEdict(e);
}

static function setsize() {
	PF.SetMinMaxSize((untyped SV).server.edicts[PR.globals_int[4]],
		[PR.globals_float[7], PR.globals_float[8], PR.globals_float[9]],
		[PR.globals_float[10], PR.globals_float[11], PR.globals_float[12]]);
}

static function setmodel() {
	var e:Edict = (untyped SV).server.edicts[PR.globals_int[4]];
	var m = PR.GetString(PR.globals_int[7]);
	var i = 0;
	while (i < (untyped SV).server.model_precache.length) {
		if ((untyped SV).server.model_precache[i] == m)
			break;
		i++;
	}
	if (i == (untyped SV).server.model_precache.length)
		PR.RunError('no precache: ' + m + '\n');

	e.v_int[PR.entvars.model] = PR.globals_int[7];
	e.v_float[PR.entvars.modelindex] = i;
	var mod = (untyped SV).server.models[i];
	if (mod != null)
		PF.SetMinMaxSize(e, mod.mins, mod.maxs);
	else
		PF.SetMinMaxSize(e, Vec.origin, Vec.origin);
}

static function bprint() {
	(untyped Host).BroadcastPrint(PF.VarString(0));
}

static function sprint() {
	var entnum = PR.globals_int[4];
	if ((entnum <= 0) || (entnum > (untyped SV).svs.maxclients)) {
		Console.Print('tried to sprint to a non-client\n');
		return;
	}
	var client = (untyped SV).svs.clients[entnum - 1];
	MSG.WriteByte(client.message, Protocol.svc.print);
	MSG.WriteString(client.message, PF.VarString(1));
}

static function centerprint() {
	var entnum = PR.globals_int[4];
	if ((entnum <= 0) || (entnum > (untyped SV).svs.maxclients)) {
		Console.Print('tried to sprint to a non-client\n');
		return;
	}
	var client = (untyped SV).svs.clients[entnum - 1];
	MSG.WriteByte(client.message, Protocol.svc.centerprint);
	MSG.WriteString(client.message, PF.VarString(1));
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
	(untyped SV).StartParticle([PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]],
		[PR.globals_float[7], PR.globals_float[8], PR.globals_float[9]],
		Std.int(PR.globals_float[10]), Std.int(PR.globals_float[13]));
}

static function ambientsound() {
	var samp = PR.GetString(PR.globals_int[7]);
	var i = 0;
	while (i < (untyped SV).server.sound_precache.length) {
		if ((untyped SV).server.sound_precache[i] == samp)
			break;
		i++;
	}
	if (i == (untyped SV).server.sound_precache.length) {
		Console.Print('no precache: ' + samp + '\n');
		return;
	}
	var signon = (untyped SV).server.signon;
	MSG.WriteByte(signon, Protocol.svc.spawnstaticsound);
	MSG.WriteCoord(signon, PR.globals_float[4]);
	MSG.WriteCoord(signon, PR.globals_float[5]);
	MSG.WriteCoord(signon, PR.globals_float[6]);
	MSG.WriteByte(signon, i);
	MSG.WriteByte(signon, Std.int(PR.globals_float[10] * 255));
	MSG.WriteByte(signon, Std.int(PR.globals_float[13] * 64));
}

static function sound() {
	(untyped SV).StartSound((untyped SV).server.edicts[PR.globals_int[4]],
		Std.int(PR.globals_float[7]),
		PR.GetString(PR.globals_int[10]),
		Std.int(PR.globals_float[13] * 255),
		PR.globals_float[16]);
}

static function breakstatement() {
	Console.Print('break statement\n');
}

static function traceline() {
	var trace = (untyped SV).Move([PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]],
		Vec.origin, Vec.origin, [PR.globals_float[7], PR.globals_float[8], PR.globals_float[9]],
		Std.int(PR.globals_float[10]), (untyped SV).server.edicts[PR.globals_int[13]]);
	PR.globals_float[PR.globalvars.trace_allsolid] = (trace.allsolid) ? 1.0 : 0.0;
	PR.globals_float[PR.globalvars.trace_startsolid] = (trace.startsolid) ? 1.0 : 0.0;
	PR.globals_float[PR.globalvars.trace_fraction] = trace.fraction;
	PR.globals_float[PR.globalvars.trace_inwater] = (trace.inwater) ? 1.0 : 0.0;
	PR.globals_float[PR.globalvars.trace_inopen] = (trace.inopen) ? 1.0 : 0.0;
	PR.globals_float[PR.globalvars.trace_endpos] = trace.endpos[0];
	PR.globals_float[PR.globalvars.trace_endpos1] = trace.endpos[1];
	PR.globals_float[PR.globalvars.trace_endpos2] = trace.endpos[2];
	var plane = trace.plane;
	PR.globals_float[PR.globalvars.trace_plane_normal] = plane.normal[0];
	PR.globals_float[PR.globalvars.trace_plane_normal1] = plane.normal[1];
	PR.globals_float[PR.globalvars.trace_plane_normal2] = plane.normal[2];
	PR.globals_float[PR.globalvars.trace_plane_dist] = plane.dist;
	PR.globals_int[PR.globalvars.trace_ent] = (trace.ent != null) ? trace.ent.num : 0;
}

static function newcheckclient(check:Int):Int {
	if (check <= 0)
		check = 1;
	else if (check > (untyped SV).svs.maxclients)
		check = (untyped SV).svs.maxclients;
	var i = 1;
	if (check != (untyped SV).svs.maxclients)
		i += check;
	var ent;
	while (true) {
		if (i == (untyped SV).svs.maxclients + 1)
			i = 1;
		ent = (untyped SV).server.edicts[i];
		if (i == check)
			break;
		if (ent.free) {
			i++;
			continue;
		}
		if ((ent.v_float[PR.entvars.health] <= 0.0) || ((Std.int(ent.v_float[PR.entvars.flags]) & (untyped SV).fl.notarget) != 0)) {
			i++;
			continue;
		}
		break;
	}
	PF.checkpvs = (untyped Mod).LeafPVS((untyped Mod).PointInLeaf([
			ent.v_float[PR.entvars.origin] + ent.v_float[PR.entvars.view_ofs],
			ent.v_float[PR.entvars.origin1] + ent.v_float[PR.entvars.view_ofs1],
			ent.v_float[PR.entvars.origin2] + ent.v_float[PR.entvars.view_ofs2]
		], (untyped SV).server.worldmodel), (untyped SV).server.worldmodel);
	return i;
}

static var checkpvs:Array<Int>;

static function checkclient() {
	if (((untyped SV).server.time - (untyped SV).server.lastchecktime) >= 0.1) {
		(untyped SV).server.lastcheck = PF.newcheckclient((untyped SV).server.lastcheck);
		(untyped SV).server.lastchecktime = (untyped SV).server.time;
	}
	var ent = (untyped SV).server.edicts[(untyped SV).server.lastcheck];
	if ((ent.free) || (ent.v_float[PR.entvars.health] <= 0.0)) {
		PR.globals_int[1] = 0;
		return;
	}
	var self = (untyped SV).server.edicts[PR.globals_int[PR.globalvars.self]];
	var l = (untyped Mod).PointInLeaf([
			self.v_float[PR.entvars.origin] + self.v_float[PR.entvars.view_ofs],
			self.v_float[PR.entvars.origin1] + self.v_float[PR.entvars.view_ofs1],
			self.v_float[PR.entvars.origin2] + self.v_float[PR.entvars.view_ofs2]
		], (untyped SV).server.worldmodel).num - 1;
	if ((l < 0) || ((PF.checkpvs[l >> 3] & (1 << (l & 7))) == 0)) {
		PR.globals_int[1] = 0;
		return;
	}
	PR.globals_int[1] = ent.num;
}

static function stuffcmd() {
	var entnum = PR.globals_int[4];
	if ((entnum <= 0) || (entnum > (untyped SV).svs.maxclients))
		PR.RunError('Parm 0 not a client');
	var client = (untyped SV).svs.clients[entnum - 1];
	MSG.WriteByte(client.message, Protocol.svc.stufftext);
	MSG.WriteString(client.message, PR.GetString(PR.globals_int[7]));
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
	for (i in 1...(untyped SV).server.num_edicts) {
		var ent = (untyped SV).server.edicts[i];
		if (ent.free)
			continue;
		if (ent.v_float[PR.entvars.solid] == (untyped SV).solid.not)
			continue;
		eorg[0] = org[0] - (ent.v_float[PR.entvars.origin] + (ent.v_float[PR.entvars.mins] + ent.v_float[PR.entvars.maxs]) * 0.5);
		eorg[1] = org[1] - (ent.v_float[PR.entvars.origin1] + (ent.v_float[PR.entvars.mins1] + ent.v_float[PR.entvars.maxs1]) * 0.5);
		eorg[2] = org[2] - (ent.v_float[PR.entvars.origin2] + (ent.v_float[PR.entvars.mins2] + ent.v_float[PR.entvars.maxs2]) * 0.5);
		if (Math.sqrt(eorg[0] * eorg[0] + eorg[1] * eorg[1] + eorg[2] * eorg[2]) > rad)
			continue;
		ent.v_int[PR.entvars.chain] = chain;
		chain = i;
	}
	PR.globals_int[1] = chain;
}

static function dprint() {
	Console.DPrint(PF.VarString(0));
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
	ED.Free((untyped SV).server.edicts[PR.globals_int[4]]);
}

static function Find() {
	var e = PR.globals_int[4];
	var f = PR.globals_int[7];
	var s = PR.GetString(PR.globals_int[10]);
	for (e in (e + 1)...(untyped SV).server.num_edicts) {
		var ed = (untyped SV).server.edicts[e];
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
	var ent = (untyped SV).server.edicts[PR.globals_int[PR.globalvars.self]];
	if ((ent.v_float[PR.entvars.flags] & ((untyped SV).fl.onground + (untyped SV).fl.fly + (untyped SV).fl.swim)) == 0) {
		PR.globals_float[1] = 0.0;
		return;
	}
	var goal = (untyped SV).server.edicts[ent.v_int[PR.entvars.goalentity]];
	var dist = PR.globals_float[4];
	if ((ent.v_int[PR.entvars.enemy] != 0) && ((untyped SV).CloseEnough(ent, goal, dist)))
		return;
	if ((Math.random() >= 0.75) || ((untyped SV).StepDirection(ent, ent.v_float[PR.entvars.ideal_yaw], dist) != true))
		(untyped SV).NewChaseDir(ent, goal, dist);
}

static function precache_file() {
	PR.globals_int[1] = PR.globals_int[4];
}

static function precache_sound() {
	var s = PR.GetString(PR.globals_int[4]);
	PR.globals_int[1] = PR.globals_int[4];
	PR.CheckEmptyString(s);
	var i = 0;
	while (i < (untyped SV).server.sound_precache.length) {
		if ((untyped SV).server.sound_precache[i] == s)
			return;
		i++;
	}
	(untyped SV).server.sound_precache[i] = s;
}

static function precache_model() {
	if ((untyped SV).server.loading != true)
		PR.RunError('PF.Precache_*: Precache can only be done in spawn functions');
	var s = PR.GetString(PR.globals_int[4]);
	PR.globals_int[1] = PR.globals_int[4];
	PR.CheckEmptyString(s);
	var i = 0;
	while (i < (untyped SV).server.model_precache.length) {
		if ((untyped SV).server.model_precache[i] == s)
			return;
		i++;
	}
	(untyped SV).server.model_precache[i] = s;
	(untyped SV).server.models[i] = (untyped Mod).ForName(s, true);
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
	ED.Print((untyped SV).server.edicts[Std.int(PR.globals_float[4])]);
}

static function walkmove() {
	var ent = (untyped SV).server.edicts[PR.globals_int[PR.globalvars.self]];
	if ((ent.v_float[PR.entvars.flags] & ((untyped SV).fl.onground + (untyped SV).fl.fly + (untyped SV).fl.swim)) == 0) {
		PR.globals_float[1] = 0.0;
		return;
	}
	var yaw = PR.globals_float[4] * Math.PI / 180.0;
	var dist = PR.globals_float[7];
	var oldf = PR.xfunction;
	PR.globals_float[1] = (untyped SV).movestep(ent, [Math.cos(yaw) * dist, Math.sin(yaw) * dist], true);
	PR.xfunction = oldf;
	PR.globals_int[PR.globalvars.self] = ent.num;
}

static function droptofloor() {
	var ent = (untyped SV).server.edicts[PR.globals_int[PR.globalvars.self]];
	var trace = (untyped SV).Move(ED.Vector(ent, PR.entvars.origin),
		ED.Vector(ent, PR.entvars.mins), ED.Vector(ent, PR.entvars.maxs),
		[ent.v_float[PR.entvars.origin], ent.v_float[PR.entvars.origin1], ent.v_float[PR.entvars.origin2] - 256.0], 0, ent);
	if ((trace.fraction == 1.0) || (trace.allsolid)) {
		PR.globals_float[1] = 0.0;
		return;
	}
	ED.SetVector(ent, PR.entvars.origin, trace.endpos);
	(untyped SV).LinkEdict(ent);
	ent.v_float[PR.entvars.flags] = Std.int(ent.v_float[PR.entvars.flags]) | (untyped SV).fl.onground;
	ent.v_int[PR.entvars.groundentity] = trace.ent.num;
	PR.globals_float[1] = 1.0;
}

static function lightstyle() {
	var style = Std.int(PR.globals_float[4]);
	var val = PR.GetString(PR.globals_int[7]);
	(untyped SV).server.lightstyles[style] = val;
	if ((untyped SV).server.loading)
		return;
	for (i in 0...(untyped SV).svs.maxclients) {
		var client = (untyped SV).svs.clients[i];
		if ((client.active != true) && (client.spawned != true))
			continue;
		MSG.WriteByte(client.message, Protocol.svc.lightstyle);
		MSG.WriteByte(client.message, style);
		MSG.WriteString(client.message, val);
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
	PR.globals_float[1] = (untyped SV).CheckBottom((untyped SV).server.edicts[PR.globals_int[4]]);
}

static function pointcontents() {
	PR.globals_float[1] = (untyped SV).PointContents([PR.globals_float[4], PR.globals_float[5], PR.globals_float[6]]);
}

static function nextent() {
	for (i in (PR.globals_int[4] + 1)...(untyped SV).server.num_edicts) {
		if ((untyped SV).server.edicts[i].free != true) {
			PR.globals_int[1] = i;
			return;
		}
	}
	PR.globals_int[1] = 0;
}

static function aim() {
	var ent = (untyped SV).server.edicts[PR.globals_int[4]];
	var start = [ent.v_float[PR.entvars.origin], ent.v_float[PR.entvars.origin1], ent.v_float[PR.entvars.origin2] + 20.0];
	var dir = [PR.globals_float[PR.globalvars.v_forward], PR.globals_float[PR.globalvars.v_forward1], PR.globals_float[PR.globalvars.v_forward2]];
	var end = [start[0] + 2048.0 * dir[0], start[1] + 2048.0 * dir[1], start[2] + 2048.0 * dir[2]];
	var tr = (untyped SV).Move(start, Vec.origin, Vec.origin, end, 0, ent);
	if (tr.ent != null) {
		if ((tr.ent.v_float[PR.entvars.takedamage] == (untyped SV).damage.aim) &&
			(((untyped Host).teamplay.value == 0) || (ent.v_float[PR.entvars.team] <= 0) ||
			(ent.v_float[PR.entvars.team] != tr.ent.v_float[PR.entvars.team]))) {
			PR.globals_float[1] = dir[0];
			PR.globals_float[2] = dir[1];
			PR.globals_float[3] = dir[2];
			return;
		}
	}
	var bestdir = [dir[0], dir[1], dir[2]];
	var bestdist = (untyped SV).aim.value;
	var bestent, end = [];
	for (i in 1...(untyped SV).server.num_edicts) {
		var check = (untyped SV).server.edicts[i];
		if (check.v_float[PR.entvars.takedamage] != (untyped SV).damage.aim)
			continue;
		if (check == ent)
			continue;
		if (((untyped Host).teamplay.value != 0) && (ent.v_float[PR.entvars.team] > 0) && (ent.v_float[PR.entvars.team] == check.v_float[PR.entvars.team]))
			continue;
		end[0] = check.v_float[PR.entvars.origin] + 0.5 * (check.v_float[PR.entvars.mins] + check.v_float[PR.entvars.maxs]);
		end[1] = check.v_float[PR.entvars.origin1] + 0.5 * (check.v_float[PR.entvars.mins1] + check.v_float[PR.entvars.maxs1]);
		end[2] = check.v_float[PR.entvars.origin2] + 0.5 * (check.v_float[PR.entvars.mins2] + check.v_float[PR.entvars.maxs2]);
		dir[0] = end[0] - start[0];
		dir[1] = end[1] - start[1];
		dir[2] = end[2] - start[2];
		Vec.Normalize(dir);
		var dist = dir[0] * bestdir[0] + dir[1] * bestdir[1] + dir[2] * bestdir[2];
		if (dist < bestdist)
			continue;
		tr = (untyped SV).Move(start, Vec.origin, Vec.origin, end, 0, ent);
		if (tr.ent == check) {
			bestdist = dist;
			bestent = check;
		}
	}
	if (bestent != null) {
		dir[0] = bestent.v_float[PR.entvars.origin] - ent.v_float[PR.entvars.origin];
		dir[1] = bestent.v_float[PR.entvars.origin1] - ent.v_float[PR.entvars.origin1];
		dir[2] = bestent.v_float[PR.entvars.origin2] - ent.v_float[PR.entvars.origin2];
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
	var ent = (untyped SV).server.edicts[PR.globals_int[PR.globalvars.self]];
	var current = Vec.Anglemod(ent.v_float[PR.entvars.angles1]);
	var ideal = ent.v_float[PR.entvars.ideal_yaw];
	if (current == ideal)
		return;
	var move = ideal - current;
	if (ideal > current) {
		if (move >= 180.0)
			move -= 360.0;
	}
	else if (move <= -180.0)
		move += 360.0;
	var speed = ent.v_float[PR.entvars.yaw_speed];
	if (move > 0.0) {
		if (move > speed)
			move = speed;
	}
	else if (move < -speed)
		move = -speed;
	ent.v_float[PR.entvars.angles1] = Vec.Anglemod(current + move);
}

static function WriteDest() {
	switch (Std.int(PR.globals_float[4])) {
		case 0: // broadcast
			return (untyped SV).server.datagram;
		case 1: // one
			var entnum = PR.globals_int[PR.globalvars.msg_entity];
			if ((entnum <= 0) || (entnum > (untyped SV).svs.maxclients))
				PR.RunError('WriteDest: not a client');
			return (untyped SV).svs.clients[entnum - 1].message;
		case 2: // all
			return (untyped SV).server.reliable_datagram;
		case 3: // init
			return (untyped SV).server.signon;
		default:
			PR.RunError('WriteDest: bad destination');
			return null;
	}
}

static function WriteByte() {MSG.WriteByte(PF.WriteDest(), Std.int(PR.globals_float[7]));};
static function WriteChar() {MSG.WriteChar(PF.WriteDest(), Std.int(PR.globals_float[7]));};
static function WriteShort() {MSG.WriteShort(PF.WriteDest(), Std.int(PR.globals_float[7]));};
static function WriteLong() {MSG.WriteLong(PF.WriteDest(), Std.int(PR.globals_float[7]));};
static function WriteAngle() {MSG.WriteAngle(PF.WriteDest(), PR.globals_float[7]);};
static function WriteCoord() {MSG.WriteCoord(PF.WriteDest(), PR.globals_float[7]);};
static function WriteString() {MSG.WriteString(PF.WriteDest(), PR.GetString(PR.globals_int[7]));};
static function WriteEntity() {MSG.WriteShort(PF.WriteDest(), PR.globals_int[7]);};

static function makestatic() {
	var ent:Edict = (untyped SV).server.edicts[PR.globals_int[4]];
	var message = (untyped SV).server.signon;
	MSG.WriteByte(message, Protocol.svc.spawnstatic);
	MSG.WriteByte(message, (untyped SV).ModelIndex(PR.GetString(ent.v_int[PR.entvars.model])));
	MSG.WriteByte(message, Std.int(ent.v_float[PR.entvars.frame]));
	MSG.WriteByte(message, Std.int(ent.v_float[PR.entvars.colormap]));
	MSG.WriteByte(message, Std.int(ent.v_float[PR.entvars.skin]));
	MSG.WriteCoord(message, ent.v_float[PR.entvars.origin]);
	MSG.WriteAngle(message, ent.v_float[PR.entvars.angles]);
	MSG.WriteCoord(message, ent.v_float[PR.entvars.origin1]);
	MSG.WriteAngle(message, ent.v_float[PR.entvars.angles1]);
	MSG.WriteCoord(message, ent.v_float[PR.entvars.origin2]);
	MSG.WriteAngle(message, ent.v_float[PR.entvars.angles2]);
	ED.Free(ent);
}

static function setspawnparms() {
	var i = PR.globals_int[4];
	if ((i <= 0) || (i > (untyped SV).svs.maxclients))
		PR.RunError('Entity is not a client');
	var spawn_parms = (untyped SV).svs.clients[i - 1].spawn_parms;
	for (i in 0...16)
		PR.globals_float[PR.globalvars.parms + i] = spawn_parms[i];
}

static function changelevel() {
	if ((untyped SV).svs.changelevel_issued)
		return;
	(untyped SV).svs.changelevel_issued = true;
	Cmd.text += 'changelevel ' + PR.GetString(PR.globals_int[4]) + '\n';
}

static function Fixme() {
	PR.RunError('unimplemented builtin');
}

static var builtin:Array<Void->Void> = [
	PF.Fixme,
	PF.makevectors,
	PF.setorigin,
	PF.setmodel,
	PF.setsize,
	PF.Fixme,
	PF.breakstatement,
	PF.random,
	PF.sound,
	PF.normalize,
	PF.error,
	PF.objerror,
	PF.vlen,
	PF.vectoyaw,
	PF.Spawn,
	PF.Remove,
	PF.traceline,
	PF.checkclient,
	PF.Find,
	PF.precache_sound,
	PF.precache_model,
	PF.stuffcmd,
	PF.findradius,
	PF.bprint,
	PF.sprint,
	PF.dprint,
	PF.ftos,
	PF.vtos,
	PF.coredump,
	PF.traceon,
	PF.traceoff,
	PF.eprint,
	PF.walkmove,
	PF.Fixme,
	PF.droptofloor,
	PF.lightstyle,
	PF.rint,
	PF.floor,
	PF.ceil,
	PF.Fixme,
	PF.checkbottom,
	PF.pointcontents,
	PF.Fixme,
	PF.fabs,
	PF.aim,
	PF.cvar,
	PF.localcmd,
	PF.nextent,
	PF.particle,
	PF.changeyaw,
	PF.Fixme,
	PF.vectoangles,
	PF.WriteByte,
	PF.WriteChar,
	PF.WriteShort,
	PF.WriteLong,
	PF.WriteCoord,
	PF.WriteAngle,
	PF.WriteString,
	PF.WriteEntity,
	PF.Fixme,
	PF.Fixme,
	PF.Fixme,
	PF.Fixme,
	PF.Fixme,
	PF.Fixme,
	PF.Fixme,
	PF.MoveToGoal,
	PF.precache_file,
	PF.makestatic,
	PF.changelevel,
	PF.Fixme,
	PF.cvar_set,
	PF.centerprint,
	PF.ambientsound,
	PF.precache_model,
	PF.precache_sound,
	PF.precache_file,
	PF.setspawnparms
];

}
