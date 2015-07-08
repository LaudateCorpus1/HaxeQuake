package quake;

import js.html.ArrayBuffer;
import js.html.Float32Array;
import js.html.Int32Array;

@:publicFields
class Edict {
	var num:Int;
	var free:Bool;
	var freetime:Float;
	var v:ArrayBuffer;
	var v_int:Int32Array;
	var v_float:Float32Array;
}

@:publicFields
class Ddef {
	var type:Int;
	var ofs:Int;
	var name:Int;
}

@:enum abstract EType(Int) from Int {
	var ev_void = 0;
	var ev_string = 1;
	var ev_float = 2;
	var ev_vector = 3;
	var ev_entity = 4;
	var ev_field = 5;
	var ev_function = 6;
	var ev_pointer = 7;
}

@:expose("ED")
class ED {
	static function ClearEdict(e:Edict):Void {
		for (i in 0...(untyped PR).entityfields)
			e.v_int[i] = 0;
		e.free = false;
	}

	static function Alloc():Edict {
		var i = (untyped SV).svs.maxclients + 1;
		var e:Edict;
		while (i < (untyped SV).server.num_edicts) {
			e = (untyped SV).server.edicts[i++];
			if ((e.free) && ((e.freetime < 2.0) || (((untyped SV).server.time - e.freetime) > 0.5))) {
				ClearEdict(e);
				return e;
			}
		}
		if (i == Def.max_edicts)
			Sys.Error('ED.Alloc: no free edicts');
		e = (untyped SV).server.edicts[(untyped SV).server.num_edicts++];
		ClearEdict(e);
		return e;
	}

	static function Free(ed:Edict):Void {
		(untyped SV).UnlinkEdict(ed);
		ed.free = true;
		ed.v_int[(untyped PR).entvars.model] = 0;
		ed.v_float[(untyped PR).entvars.takedamage] = 0.0;
		ed.v_float[(untyped PR).entvars.modelindex] = 0.0;
		ed.v_float[(untyped PR).entvars.colormap] = 0.0;
		ed.v_float[(untyped PR).entvars.skin] = 0.0;
		ed.v_float[(untyped PR).entvars.frame] = 0.0;
		SetVector(ed, (untyped PR).entvars.origin, Vec.origin);
		SetVector(ed, (untyped PR).entvars.angles, Vec.origin);
		ed.v_float[(untyped PR).entvars.nextthink] = -1.0;
		ed.v_float[(untyped PR).entvars.solid] = 0.0;
		ed.freetime = (untyped SV).server.time;
	}

	static function GlobalAtOfs(ofs:Int):Ddef {
		for (def in (untyped PR.globaldefs : Array<Ddef>)) {
			if (def.ofs == ofs)
				return def;
		}
		return null;
	}

	static function FieldAtOfs(ofs:Int):Ddef {
		for (def in (untyped PR.fielddefs : Array<Ddef>)) {
			if (def.ofs == ofs)
				return def;
		}
		return null;
	}

	static function FindField(name:String):Ddef {
		for (def in (untyped PR.fielddefs : Array<Ddef>)) {
			if ((untyped PR).GetString(def.name) == name)
				return def;
		}
		return null;
	}

	static function FindGlobal(name:String):Ddef {
		for (def in (untyped PR.globaldefs : Array<Ddef>)) {
			if ((untyped PR).GetString(def.name) == name)
				return def;
		}
		return null;
	}

	static function FindFunction(name:String):Int {
		for (i in 0...(untyped PR).functions.length) {
			if ((untyped PR).GetString((untyped PR).functions[i].name) == name)
				return i;
		}
		return null;
	}

	static function Print(ed:Edict):Void {
		if (ed.free) {
			Console.Print('FREE\n');
			return;
		}
		Console.Print('\nEDICT ' + ed.num + ':\n');
		for (i in 1...(untyped PR).fielddefs.length) {
			var d = (untyped PR).fielddefs[i];
			var name:String = (untyped PR).GetString(d.name);
			if (name.charCodeAt(name.length - 2) == 95)
				continue;
			var v = d.ofs;
			if (ed.v_int[v] == 0) {
				if ((d.type & 0x7fff) == 3) {
					if ((ed.v_int[v + 1] == 0) && (ed.v_int[v + 2] == 0))
						continue;
				}
				else
					continue;
			}
			while (name.length <= 14)
				name += ' ';
			Console.Print(name + (untyped PR).ValueString(d.type, ed.v, v) + '\n');
		}
	}

	static function PrintEdicts() {
		if (!(untyped SV).server.active)
			return;
		Console.Print((untyped SV).server.num_edicts + ' entities\n');
		for (i in 0...(untyped SV).server.num_edicts)
			Print((untyped SV).server.edicts[i]);
	}

	static function PrintEdict_f() {
		if ((untyped SV).server.active != true)
			return;
		var i = Q.atoi(Cmd.argv[1]);
		if ((i >= 0) && (i < (untyped SV).server.num_edicts))
			Print((untyped SV).server.edicts[i]);
	}

	static function Count() {
		if (!(untyped SV).server.active)
			return;
		var active = 0, models = 0, solid = 0, step = 0;
		for (i in 0...(untyped SV).server.num_edicts) {
			var ent = (untyped SV).server.edicts[i];
			if (ent.free)
				continue;
			++active;
			if (ent.v_float[(untyped PR).entvars.solid] != 0.0)
				++solid;
			if (ent.v_int[(untyped PR).entvars.model] != 0)
				++models;
			if (ent.v_float[(untyped PR).entvars.movetype] == (untyped SV).movetype.step)
				++step;
		}
		var num_edicts = (untyped SV).server.num_edicts;
		Console.Print('num_edicts:' + (num_edicts <= 9 ? '  ' : (num_edicts <= 99 ? ' ' : '')) + num_edicts + '\n');
		Console.Print('active    :' + (active <= 9 ? '  ' : (active <= 99 ? ' ' : '')) + active + '\n');
		Console.Print('view      :' + (models <= 9 ? '  ' : (models <= 99 ? ' ' : '')) + models + '\n');
		Console.Print('touch     :' + (solid <= 9 ? '  ' : (solid <= 99 ? ' ' : '')) + solid + '\n');
		Console.Print('step      :' + (step <= 9 ? '  ' : (step <= 99 ? ' ' : '')) + step + '\n');
	}

	static function ParseGlobals(data:String):Void {
		while (true) {
			data = COM.Parse(data);
			if (COM.token.charCodeAt(0) == 125)
				return;
			if (data == null)
				Sys.Error('ED.ParseGlobals: EOF without closing brace');
			var keyname = COM.token;
			data = COM.Parse(data);
			if (data == null)
				Sys.Error('ED.ParseGlobals: EOF without closing brace');
			if (COM.token.charCodeAt(0) == 125)
				Sys.Error('ED.ParseGlobals: closing brace without data');
			var key = FindGlobal(keyname);
			if (key == null) {
				Console.Print('\'' + keyname + '\' is not a global\n');
				continue;
			}
			if (ParseEpair((untyped PR).globals, key, COM.token) != true)
				(untyped Host).Error('ED.ParseGlobals: parse error');
		}
	}

	static function NewString(string:String) {
		var newstring = [];
		var i = 0;
		while (i < string.length) {
			var c = string.charCodeAt(i);
			if ((c == 92) && (i < (string.length - 1))) {
				++i;
				newstring[newstring.length] = (string.charCodeAt(i) == 110) ? '\n' : '\\';
			}
			else
				newstring[newstring.length] = String.fromCharCode(c);
			i++;
		}
		return (untyped PR).NewString(newstring.join(''), string.length + 1);
	}

	static function ParseEpair(base:ArrayBuffer, key, s:String):Bool {
		var d_float = new Float32Array(base);
		var d_int = new Int32Array(base);
		switch (key.type & 0x7fff : EType) {
			case ev_string:
				d_int[key.ofs] = NewString(s);
				return true;
			case ev_float:
				d_float[key.ofs] = Q.atof(s);
				return true;
			case ev_vector:
				var v = s.split(' ');
				d_float[key.ofs] = Q.atof(v[0]);
				d_float[key.ofs + 1] = Q.atof(v[1]);
				d_float[key.ofs + 2] = Q.atof(v[2]);
				return true;
			case ev_entity:
				d_int[key.ofs] = Q.atoi(s);
				return true;
			case ev_field:
				var d = FindField(s);
				if (d == null) {
					Console.Print('Can\'t find field ' + s + '\n');
					return false;
				}
				d_int[key.ofs] = d.ofs;
				return true;
			case ev_function:
				var d = FindFunction(s);
				if (d == null) {
					Console.Print('Can\'t find function ' + s + '\n');
					return false;
				}
				d_int[key.ofs] = d;
			default:
		}
		return true;
	}

	static function ParseEdict(data:String, ent:Edict):String {
		if (ent != (untyped SV).server.edicts[0]) {
			for (i in 0...(untyped PR).entityfields)
				ent.v_int[i] = 0;
		}
		var init = false;
		while (true) {
			data = COM.Parse(data);
			if (COM.token.charCodeAt(0) == 125)
				break;
			if (data == null)
				Sys.Error('ED.ParseEdict: EOF without closing brace');
			var anglehack;
			if (COM.token == 'angle') {
				COM.token = 'angles';
				anglehack = true;
			}
			else
			{
				anglehack = false;
				if (COM.token == 'light')
					COM.token = 'light_lev';
			}
			var n = COM.token.length;
			while (n > 0) {
				if (COM.token.charCodeAt(n - 1) != 32)
					break;
				n--;
			}
			var keyname = COM.token.substring(0, n);
			data = COM.Parse(data);
			if (data == null)
				Sys.Error('ED.ParseEdict: EOF without closing brace');
			if (COM.token.charCodeAt(0) == 125)
				Sys.Error('ED.ParseEdict: closing brace without data');
			init = true;
			if (keyname.charCodeAt(0) == 95)
				continue;
			var key = FindField(keyname);
			if (key == null) {
				Console.Print('\'' + keyname + '\' is not a field\n');
				continue;
			}
			if (anglehack)
				COM.token = '0 ' + COM.token + ' 0';
			if (ParseEpair(ent.v, key, COM.token) != true)
				(untyped Host).Error('ED.ParseEdict: parse error');
		}
		if (!init)
			ent.free = true;
		return data;
	}

	static function LoadFromFile(data:String):Void {
		var ent, inhibit = 0;
		(untyped PR).globals_float[(untyped PR).globalvars.time] = (untyped SV).server.time;

		while (true) {
			data = COM.Parse(data);
			if (data == null)
				break;
			if (COM.token.charCodeAt(0) != 123)
				Sys.Error('ED.LoadFromFile: found ' + COM.token + ' when expecting {');

			if (ent == null)
				ent = (untyped SV).server.edicts[0];
			else
				ent = Alloc();
			data = ParseEdict(data, ent);

			var spawnflags = Std.int(ent.v_float[(untyped PR).entvars.spawnflags]);
			if ((untyped Host).deathmatch.value != 0) {
				if ((spawnflags & 2048) != 0) {
					Free(ent);
					++inhibit;
					continue;
				}
			}
			else if ((((untyped Host).current_skill == 0) && ((spawnflags & 256) != 0))
				|| (((untyped Host).current_skill == 1) && ((spawnflags & 512) != 0))
				|| (((untyped Host).current_skill >= 2) && ((spawnflags & 1024) != 0))) {
				Free(ent);
				++inhibit;
				continue;
			}

			if (ent.v_int[(untyped PR).entvars.classname] == 0) {
				Console.Print('No classname for:\n');
				Print(ent);
				Free(ent);
				continue;
			}

			var func = FindFunction((untyped PR).GetString(ent.v_int[(untyped PR).entvars.classname]));
			if (func == null) {
				Console.Print('No spawn function for:\n');
				Print(ent);
				Free(ent);
				continue;
			}

			(untyped PR).globals_int[(untyped PR).globalvars.self] = ent.num;
			(untyped PR).ExecuteProgram(func);
		}

		Console.DPrint(inhibit + ' entities inhibited\n');
	}

	static function Vector(e:Edict, o:Int):Vec {
		return [e.v_float[o], e.v_float[o + 1], e.v_float[o + 2]];
	}

	static function SetVector(e:Edict, o:Int, v:Vec):Void {
		e.v_float[o] = v[0];
		e.v_float[o + 1] = v[1];
		e.v_float[o + 2] = v[2];
	}
}
