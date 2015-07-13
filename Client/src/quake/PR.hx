package quake;

import js.html.ArrayBuffer;
import js.html.DataView;
import js.html.Uint8Array;
import js.html.Float32Array;
import js.html.Int32Array;
import quake.PRMacro.SetEntVarField;
using Tools;

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

@:enum abstract PROp(Int) from Int to Int {
	var done = 0;
	var mul_f = 1;
    var mul_v = 2;
    var mul_fv = 3;
    var mul_vf = 4;
	var div_f = 5;
	var add_f = 6;
    var add_v = 7;
	var sub_f = 8;
    var sub_v = 9;
	var eq_f = 10;
    var eq_v = 11;
    var eq_s = 12;
    var eq_e = 13;
    var eq_fnc = 14;
	var ne_f = 15;
    var ne_v = 16;
    var ne_s = 17;
    var ne_e = 18;
    var ne_fnc = 19;
	var le = 20;
    var ge = 21;
    var lt = 22;
    var gt = 23;
	var load_f = 24;
    var load_v = 25;
    var load_s = 26;
    var load_ent = 27;
    var load_fld = 28;
    var load_fnc = 29;
	var address = 30;
	var store_f = 31;
    var store_v = 32;
    var store_s = 33;
    var store_ent = 34;
    var store_fld = 35;
    var store_fnc = 36;
	var storep_f = 37;
    var storep_v = 38;
    var storep_s = 39;
    var storep_ent = 40;
    var storep_fld = 41;
    var storep_fnc = 42;
	var ret = 43;
	var not_f = 44;
    var not_v = 45;
    var not_s = 46;
    var not_ent = 47;
    var not_fnc = 48;
	var jnz = 49;
    var jz = 50;
	var call0 = 51;
    var call1 = 52;
    var call2 = 53;
    var call3 = 54;
    var call4 = 55;
    var call5 = 56;
    var call6 = 57;
    var call7 = 58;
    var call8 = 59;
	var state = 60;
	var jump = 61;
	var and = 62;
    var or = 63;
	var bitand = 64;
    var bitor = 65;

	@:op(a>b) static function _(a:PROp, b:PROp):Bool;
	@:op(a<b) static function _(a:PROp, b:PROp):Bool;
	@:op(a>=b) static function _(a:PROp, b:PROp):Bool;
	@:op(a<=b) static function _(a:PROp, b:PROp):Bool;
}

@:publicFields
class PRDef {
	var type:Int;
	var ofs:Int;
	var name:Int;

	function new(view:DataView, ofs:Int) {
		this.type = view.getUint16(ofs, true);
		this.ofs = view.getUint16(ofs + 2, true);
		this.name = view.getUint32(ofs + 4, true);
	}
}

@:publicFields
private class PRFunction {
	var first_statement:Int;
	var parm_start:Int;
	var locals:Int;
	var profile:Int;
	var name:Int;
	var file:Int;
	var numparms:Int;
	var parm_size:Array<Int>;

	function new(view:DataView, ofs:Int) {
		first_statement = view.getInt32(ofs, true);
		parm_start = view.getUint32(ofs + 4, true);
		locals = view.getUint32(ofs + 8, true);
		profile = view.getUint32(ofs + 12, true);
		name = view.getUint32(ofs + 16, true);
		file = view.getUint32(ofs + 20, true);
		numparms = view.getUint32(ofs + 24, true);
		parm_size = [
			view.getUint8(ofs + 28), view.getUint8(ofs + 29),
			view.getUint8(ofs + 30), view.getUint8(ofs + 31),
			view.getUint8(ofs + 32), view.getUint8(ofs + 33),
			view.getUint8(ofs + 34), view.getUint8(ofs + 35),
		];
	}
}

@:publicFields
private class PRStatement {
	var op:PROp;
	var a:Int;
	var b:Int;
	var c:Int;

	function new(view:DataView, ofs:Int) {
		op = view.getUint16(ofs, true);
		a = view.getInt16(ofs + 2, true);
		b = view.getInt16(ofs + 4, true);
		c = view.getInt16(ofs + 6, true);
	}
}

@:publicFields
private class PRStackItem {
	var stmt:Int;
	var func:PRFunction;
	function new(s, f) {
		this.stmt = s;
		this.func = f;
	}
}

@:enum abstract PROffset(Int) to Int {
	var OFS_NULL     = 0;
	var OFS_RETURN   = 1;
	var OFS_PARM0    = 4;		// leave 3 ofs for each parm to hold vectors
	var OFS_PARM1    = 7;
	var OFS_PARM2    = 10;
	var OFS_PARM3    = 13;
	var OFS_PARM4    = 16;
	var OFS_PARM5    = 19;
	var OFS_PARM6    = 22;
	var OFS_PARM7    = 25;
	var RESERVED_OFS = 28;
}


@:publicFields
class PR {

	static inline var version = 6;


	static inline var progheader_crc = 5927;

	static var strings:Uint8Array;
	static var functions:Array<PRFunction>;
	static var statements:Array<PRStatement>;
	static var globaldefs:Array<PRDef>;
	static var fielddefs:Array<PRDef>;
	static var globals:GlobalVars;
	static var _globals:ArrayBuffer;
	static var _globals_float:Float32Array;
	static var _globals_int:Int32Array;
	static var crc:Int;
	static var trace:Bool;
	static var entityfields:Int;
	static var edict_size:Int;

	static var string_temp:Int;
	static var netnames:Int;
	static var depth:Int;
	static var xstatement:Int;
	static var xfunction:PRFunction;
	static var stack:Array<PRStackItem>;
	static var argc:Int;
	static var localstack:Array<Int>;
	static var localstack_used:Int;

	// cmds

	static function CheckEmptyString(s:String):Void {
		var c = s.charCodeAt(0);
		if (c == null || (c <= 32))
			PR.RunError('Bad string');
	}

	// edict

	static function ValueString(type:Int, val:ArrayBuffer, ofs:Int):String {
		var val_float = new Float32Array(val);
		var val_int = new Int32Array(val);
		var type:EType = type & 0x7fff;
		switch (type) {
			case ev_string:
				return PR.GetString(val_int[ofs]);
			case ev_entity:
				return 'entity ' + val_int[ofs];
			case ev_function:
				return PR.GetString(PR.functions[val_int[ofs]].name) + '()';
			case ev_field:
				var def = ED.FieldAtOfs(val_int[ofs]);
				if (def != null)
					return '.' + PR.GetString(def.name);
				return '.';
			case ev_void:
				return 'void';
			case ev_float:
				return val_float[ofs].toFixed(1);
			case ev_vector:
				return '\'' + val_float[ofs].toFixed(1) +
				' ' + val_float[ofs + 1].toFixed(1) +
				' ' + val_float[ofs + 2].toFixed(1) + '\'';
			case ev_pointer:
				return 'pointer';
			default:
				return 'bad type ' + type;
		}
	}

	static function UglyValueString(type:Int, val:ArrayBuffer, ofs:Int):String {
		var val_float = new Float32Array(val);
		var val_int = new Int32Array(val);
		var type:EType = type & 0x7fff;
		switch (type) {
			case ev_string:
				return PR.GetString(val_int[ofs]);
			case ev_entity:
				return Std.string(val_int[ofs]);
			case ev_function:
				return PR.GetString(PR.functions[val_int[ofs]].name);
			case ev_field:
				var def = ED.FieldAtOfs(val_int[ofs]);
				if (def != null)
					return PR.GetString(def.name);
				return '';
			case ev_void:
				return 'void';
			case ev_float:
				return val_float[ofs].toFixed(6);
			case ev_vector:
				return val_float[ofs].toFixed(6) +
				' ' + val_float[ofs + 1].toFixed(6) +
				' ' + val_float[ofs + 2].toFixed(6);
			default:
				return 'bad type ' + type;
		}
	}

	static function GlobalString(ofs:Int):String {
		var def = ED.GlobalAtOfs(ofs);
		var line;
		if (def != null)
			line = ofs + '(' + PR.GetString(def.name) + ')' + PR.ValueString(def.type, PR._globals, ofs);
		else
			line = ofs + '(???)';
		while (line.length <= 20)
			line += ' ';
		return line;
	}

	static function GlobalStringNoContents(ofs:Int):String {
		var def = ED.GlobalAtOfs(ofs);
		var line;
		if (def != null)
			line = ofs + '(' + PR.GetString(def.name) + ')';
		else
			line = ofs + '(???)';
		while (line.length <= 20)
			line += ' ';
		return line;
	}

	static function LoadProgs():Void {
		var progs = COM.LoadFile('progs.dat');
		if (progs == null)
			Sys.Error('PR.LoadProgs: couldn\'t load progs.dat');
		Console.DPrint('Programs occupy ' + (progs.byteLength >> 10) + 'K.\n');
		var view = new DataView(progs);

		var i = view.getUint32(0, true);
		if (i != PR.version)
			Sys.Error('progs.dat has wrong version number (' + i + ' should be ' + PR.version + ')');
		if (view.getUint32(4, true) != PR.progheader_crc)
			Sys.Error('progs.dat system vars have been modified, PR.js is out of date');

		PR.crc = CRC.Block(new Uint8Array(progs));

		PR.stack = [];
		PR.depth = 0;

		PR.localstack = [];
		for (i in 0...PR.localstack_size)
			PR.localstack.push(0);
		PR.localstack_used = 0;

		var ofs, num;

		ofs = view.getUint32(8, true);
		num = view.getUint32(12, true);
		PR.statements = [];
		for (i in 0...num) {
			PR.statements.push(new PRStatement(view, ofs));
			ofs += 8;
		}

		ofs = view.getUint32(16, true);
		num = view.getUint32(20, true);
		PR.globaldefs = [];
		for (i in 0...num) {
			PR.globaldefs.push(new PRDef(view, ofs));
			ofs += 8;
		}

		ofs = view.getUint32(24, true);
		num = view.getUint32(28, true);
		PR.fielddefs = [];
		for (i in 0...num) {
			PR.fielddefs.push(new PRDef(view, ofs));
			ofs += 8;
		}

		ofs = view.getUint32(32, true);
		num = view.getUint32(36, true);
		PR.functions = [];
		for (i in 0...num) {
			PR.functions.push(new PRFunction(view, ofs));
			ofs += 36;
		}

		ofs = view.getUint32(40, true);
		num = view.getUint32(44, true);

		PR.strings = new Uint8Array(num);
		PR.strings.set(new Uint8Array(progs, ofs, num));
		PR.string_temp = PR.NewString('', 128);
		PR.netnames = PR.NewString('', SV.svs.maxclients << 5);

		ofs = view.getUint32(48, true);
		num = view.getUint32(52, true);
		PR._globals = new ArrayBuffer(num << 2);
		PR._globals_float = new Float32Array(PR._globals);
		PR._globals_int = new Int32Array(PR._globals);
		for (i in 0...num)
			PR._globals_int[i] = view.getInt32(ofs + (i << 2), true);

		PR.entityfields = view.getUint32(56, true);
		PR.edict_size = 96 + (PR.entityfields << 2);

		SetEntVarField('ammo_shells1');
		SetEntVarField('ammo_nails1');
		SetEntVarField('ammo_lava_nails');
		SetEntVarField('ammo_rockets1');
		SetEntVarField('ammo_multi_rockets');
		SetEntVarField('ammo_cells1');
		SetEntVarField('ammo_plasma');
		SetEntVarField('gravity');
		SetEntVarField('items2');
	}

	static function Init():Void {
		Cmd.AddCommand('edict', ED.PrintEdict_f);
		Cmd.AddCommand('edicts', ED.PrintEdicts);
		Cmd.AddCommand('edictcount', ED.Count);
		Cmd.AddCommand('profile', PR.Profile_f);
		Cvar.RegisterVariable('nomonsters', '0');
		Cvar.RegisterVariable('gamecfg', '0');
		Cvar.RegisterVariable('scratch1', '0');
		Cvar.RegisterVariable('scratch2', '0');
		Cvar.RegisterVariable('scratch3', '0');
		Cvar.RegisterVariable('scratch4', '0');
		Cvar.RegisterVariable('savedgamecfg', '0', true);
		Cvar.RegisterVariable('saved1', '0', true);
		Cvar.RegisterVariable('saved2', '0', true);
		Cvar.RegisterVariable('saved3', '0', true);
		Cvar.RegisterVariable('saved4', '0', true);
	}

	// exec

	static var localstack_size = 2048;

	static var opnames = [
		'DONE',
		'MUL_F', 'MUL_V', 'MUL_FV', 'MUL_VF',
		'DIV',
		'ADD_F', 'ADD_V',
		'SUB_F', 'SUB_V',
		'EQ_F', 'EQ_V', 'EQ_S', 'EQ_E', 'EQ_FNC',
		'NE_F', 'NE_V', 'NE_S', 'NE_E', 'NE_FNC',
		'LE', 'GE', 'LT', 'GT',
		'INDIRECT', 'INDIRECT', 'INDIRECT', 'INDIRECT', 'INDIRECT', 'INDIRECT',
		'ADDRESS',
		'STORE_F', 'STORE_V', 'STORE_S', 'STORE_ENT', 'STORE_FLD', 'STORE_FNC',
		'STOREP_F', 'STOREP_V', 'STOREP_S', 'STOREP_ENT', 'STOREP_FLD', 'STOREP_FNC',
		'RETURN',
		'NOT_F', 'NOT_V', 'NOT_S', 'NOT_ENT', 'NOT_FNC',
		'IF', 'IFNOT',
		'CALL0', 'CALL1', 'CALL2', 'CALL3', 'CALL4', 'CALL5', 'CALL6', 'CALL7', 'CALL8',
		'STATE',
		'GOTO',
		'AND', 'OR',
		'BITAND', 'BITOR'
	];

	static function PrintStatement(s:PRStatement):Void {
		var text;
		if (s.op < PR.opnames.length) {
			text = PR.opnames[s.op] + ' ';
			while (text.length <= 9)
				text += ' ';
		} else
			text = '';
		if ((s.op == PROp.jnz) || (s.op == PROp.jz))
			text += PR.GlobalString(s.a) + 'branch ' + s.b;
		else if (s.op == PROp.jump)
			text += 'branch ' + s.a;
		else if ((s.op >= PROp.store_f) && (s.op <= PROp.store_fnc))
			text += PR.GlobalString(s.a) + PR.GlobalStringNoContents(s.b);
		else {
			if (s.a != 0)
				text += PR.GlobalString(s.a);
			if (s.b != 0)
				text += PR.GlobalString(s.b);
			if (s.c != 0)
				text += PR.GlobalStringNoContents(s.c);
		}
		Console.Print(text + '\n');
	}

	static function StackTrace():Void {
		if (PR.depth == 0) {
			Console.Print('<NO STACK>\n');
			return;
		}
		PR.stack[PR.depth] = new PRStackItem(xstatement, xfunction);
		while (PR.depth >= 0) {
			var f = PR.stack[PR.depth--].func;
			if (f == null) {
				Console.Print('<NO FUNCTION>\n');
				continue;
			}
			var file = PR.GetString(f.file);
			while (file.length <= 11)
				file += ' ';
			Console.Print(file + ' : ' + PR.GetString(f.name) + '\n');
		}
		PR.depth = 0;
	}

	static function Profile_f():Void {
		if (!SV.server.active)
			return;
		var num = 0;
		while (true) {
			var max = 0;
			var best = null;
			for (f in PR.functions) {
				if (f.profile > max) {
					max = f.profile;
					best = f;
				}
			}
			if (best == null)
				return;
			if (num < 10) {
				var profile = Std.string(best.profile);
				while (profile.length <= 6)
					profile = ' ' + profile;
				Console.Print(profile + ' ' + PR.GetString(best.name) + '\n');
			}
			++num;
			best.profile = 0;
		}
	}

	static function RunError(error:String):Void {
		PrintStatement(statements[xstatement]);
		StackTrace();
		Console.Print(error + '\n');
		Host.Error('Program error');
	}

	static function EnterFunction(f:PRFunction):Int {
		PR.stack[PR.depth++] = new PRStackItem(xstatement, xfunction);
		var c = f.locals;
		if ((PR.localstack_used + c) > PR.localstack_size)
			PR.RunError('PR.EnterFunction: locals stack overflow\n');
		for (i in 0...c)
			PR.localstack[PR.localstack_used + i] = PR._globals_int[f.parm_start + i];
		PR.localstack_used += c;
		var o = f.parm_start;
		for (i in 0...f.numparms) {
			for (j in 0...f.parm_size[i])
				PR._globals_int[o++] = PR._globals_int[4 + i * 3 + j];
		}
		PR.xfunction = f;
		return f.first_statement - 1;
	}

	static function LeaveFunction():Int {
		if (PR.depth <= 0)
			Sys.Error('prog stack underflow');
		var c = PR.xfunction.locals;
		PR.localstack_used -= c;
		if (PR.localstack_used < 0)
			PR.RunError('PR.LeaveFunction: locals stack underflow\n');
		c--;
		while (c >= 0) {
			PR._globals_int[PR.xfunction.parm_start + c] = PR.localstack[PR.localstack_used + c];
			c--;
		}
		PR.xfunction = PR.stack[--PR.depth].func;
		return PR.stack[PR.depth].stmt;
	}

	static function ExecuteProgram(fnum:Int):Void {
		if ((fnum == 0) || (fnum >= PR.functions.length)) {
			if (PR.globals.self != 0)
				ED.Print(SV.server.edicts[PR.globals.self]);
			Host.Error('PR.ExecuteProgram: NULL function');
		}
		var runaway = 100000;
		PR.trace = false;
		var exitdepth = PR.depth;
		var s = PR.EnterFunction(PR.functions[fnum]);

		while (true) {
			++s;
			var st = PR.statements[s];
			if (--runaway == 0)
				PR.RunError('runaway loop error');
			++PR.xfunction.profile;
			PR.xstatement = s;
			if (PR.trace)
				PR.PrintStatement(st);
			switch (st.op) {
				case PROp.add_f:
					PR._globals_float[st.c] = PR._globals_float[st.a] + PR._globals_float[st.b];
				case PROp.add_v:
					PR._globals_float[st.c] = PR._globals_float[st.a] + PR._globals_float[st.b];
					PR._globals_float[st.c + 1] = PR._globals_float[st.a + 1] + PR._globals_float[st.b + 1];
					PR._globals_float[st.c + 2] = PR._globals_float[st.a + 2] + PR._globals_float[st.b + 2];
				case PROp.sub_f:
					PR._globals_float[st.c] = PR._globals_float[st.a] - PR._globals_float[st.b];
				case PROp.sub_v:
					PR._globals_float[st.c] = PR._globals_float[st.a] - PR._globals_float[st.b];
					PR._globals_float[st.c + 1] = PR._globals_float[st.a + 1] - PR._globals_float[st.b + 1];
					PR._globals_float[st.c + 2] = PR._globals_float[st.a + 2] - PR._globals_float[st.b + 2];
				case PROp.mul_f:
					PR._globals_float[st.c] = PR._globals_float[st.a] * PR._globals_float[st.b];
				case PROp.mul_v:
					PR._globals_float[st.c] = PR._globals_float[st.a] * PR._globals_float[st.b] +
						PR._globals_float[st.a + 1] * PR._globals_float[st.b + 1] +
						PR._globals_float[st.a + 2] * PR._globals_float[st.b + 2];
				case PROp.mul_fv:
					PR._globals_float[st.c] = PR._globals_float[st.a] * PR._globals_float[st.b];
					PR._globals_float[st.c + 1] = PR._globals_float[st.a] * PR._globals_float[st.b + 1];
					PR._globals_float[st.c + 2] = PR._globals_float[st.a] * PR._globals_float[st.b + 2];
				case PROp.mul_vf:
					PR._globals_float[st.c] = PR._globals_float[st.b] * PR._globals_float[st.a];
					PR._globals_float[st.c + 1] = PR._globals_float[st.b] * PR._globals_float[st.a + 1];
					PR._globals_float[st.c + 2] = PR._globals_float[st.b] * PR._globals_float[st.a + 2];
				case PROp.div_f:
					PR._globals_float[st.c] = PR._globals_float[st.a] / PR._globals_float[st.b];
				case PROp.bitand:
					PR._globals_float[st.c] = Std.int(PR._globals_float[st.a]) & Std.int(PR._globals_float[st.b]);
				case PROp.bitor:
					PR._globals_float[st.c] = Std.int(PR._globals_float[st.a]) | Std.int(PR._globals_float[st.b]);
				case PROp.ge:
					PR._globals_float[st.c] = (PR._globals_float[st.a] >= PR._globals_float[st.b]) ? 1.0 : 0.0;
				case PROp.le:
					PR._globals_float[st.c] = (PR._globals_float[st.a] <= PR._globals_float[st.b]) ? 1.0 : 0.0;
				case PROp.gt:
					PR._globals_float[st.c] = (PR._globals_float[st.a] > PR._globals_float[st.b]) ? 1.0 : 0.0;
				case PROp.lt:
					PR._globals_float[st.c] = (PR._globals_float[st.a] < PR._globals_float[st.b]) ? 1.0 : 0.0;
				case PROp.and:
					PR._globals_float[st.c] = ((PR._globals_float[st.a] != 0.0) && (PR._globals_float[st.b] != 0.0)) ? 1.0 : 0.0;
				case PROp.or:
					PR._globals_float[st.c] = ((PR._globals_float[st.a] != 0.0) || (PR._globals_float[st.b] != 0.0)) ? 1.0 : 0.0;
				case PROp.not_f:
					PR._globals_float[st.c] = (PR._globals_float[st.a] == 0.0) ? 1.0 : 0.0;
				case PROp.not_v:
					PR._globals_float[st.c] = ((PR._globals_float[st.a] == 0.0) &&
						(PR._globals_float[st.a + 1] == 0.0) &&
						(PR._globals_float[st.a + 2] == 0.0)) ? 1.0 : 0.0;
				case PROp.not_s:
					if (PR._globals_int[st.a] != 0)
						PR._globals_float[st.c] = (PR.strings[PR._globals_int[st.a]] == 0) ? 1.0 : 0.0;
					else
						PR._globals_float[st.c] = 1.0;
				case PROp.not_fnc | PROp.not_ent:
					PR._globals_float[st.c] = (PR._globals_int[st.a] == 0) ? 1.0 : 0.0;
				case PROp.eq_f:
					PR._globals_float[st.c] = (PR._globals_float[st.a] == PR._globals_float[st.b]) ? 1.0 : 0.0;
				case PROp.eq_v:
					PR._globals_float[st.c] = ((PR._globals_float[st.a] == PR._globals_float[st.b])
						&& (PR._globals_float[st.a + 1] == PR._globals_float[st.b + 1])
						&& (PR._globals_float[st.a + 2] == PR._globals_float[st.b + 2])) ? 1.0 : 0.0;
				case PROp.eq_s:
					PR._globals_float[st.c] = (PR.GetString(PR._globals_int[st.a]) == PR.GetString(PR._globals_int[st.b])) ? 1.0 : 0.0;
				case PROp.eq_e | PROp.eq_fnc:
					PR._globals_float[st.c] = (PR._globals_int[st.a] == PR._globals_int[st.b]) ? 1.0 : 0.0;
				case PROp.ne_f:
					PR._globals_float[st.c] = (PR._globals_float[st.a] != PR._globals_float[st.b]) ? 1.0 : 0.0;
				case PROp.ne_v:
					PR._globals_float[st.c] = ((PR._globals_float[st.a] != PR._globals_float[st.b])
						|| (PR._globals_float[st.a + 1] != PR._globals_float[st.b + 1])
						|| (PR._globals_float[st.a + 2] != PR._globals_float[st.b + 2])) ? 1.0 : 0.0;
				case PROp.ne_s:
					PR._globals_float[st.c] = (PR.GetString(PR._globals_int[st.a]) != PR.GetString(PR._globals_int[st.b])) ? 1.0 : 0.0;
				case PROp.ne_e | PROp.ne_fnc:
					PR._globals_float[st.c] = (PR._globals_int[st.a] != PR._globals_int[st.b]) ? 1.0 : 0.0;
				case PROp.store_f | PROp.store_ent | PROp.store_fld | PROp.store_s |PROp.store_fnc:
					PR._globals_int[st.b] = PR._globals_int[st.a];
				case PROp.store_v:
					PR._globals_int[st.b] = PR._globals_int[st.a];
					PR._globals_int[st.b + 1] = PR._globals_int[st.a + 1];
					PR._globals_int[st.b + 2] = PR._globals_int[st.a + 2];
				case PROp.storep_f | PROp.storep_ent | PROp.storep_fld | PROp.storep_s | PROp.storep_fnc:
					var ptr = PR._globals_int[st.b];
					SV.server.edicts[Math.floor(ptr / PR.edict_size)]._v_int[((ptr % PR.edict_size) - 96) >> 2] = PR._globals_int[st.a];
				case PROp.storep_v:
					var ed:Edict = SV.server.edicts[Math.floor(PR._globals_int[st.b] / PR.edict_size)];
					var ptr = ((PR._globals_int[st.b] % PR.edict_size) - 96) >> 2;
					ed._v_int[ptr] = PR._globals_int[st.a];
					ed._v_int[ptr + 1] = PR._globals_int[st.a + 1];
					ed._v_int[ptr + 2] = PR._globals_int[st.a + 2];
				case PROp.address:
					var ed = PR._globals_int[st.a];
					if (ed == 0 && !SV.server.loading)
						PR.RunError('assignment to world entity');
					PR._globals_int[st.c] = ed * PR.edict_size + 96 + (PR._globals_int[st.b] << 2);
				case PROp.load_f | PROp.load_fld | PROp.load_ent | PROp.load_s | PROp.load_fnc:
					PR._globals_int[st.c] = SV.server.edicts[PR._globals_int[st.a]]._v_int[PR._globals_int[st.b]];
				case PROp.load_v:
					var ed:Edict = SV.server.edicts[PR._globals_int[st.a]];
					var ptr = PR._globals_int[st.b];
					PR._globals_int[st.c] = ed._v_int[ptr];
					PR._globals_int[st.c + 1] = ed._v_int[ptr + 1];
					PR._globals_int[st.c + 2] = ed._v_int[ptr + 2];
				case PROp.jz:
					if (PR._globals_int[st.a] == 0)
						s += st.b - 1;
				case PROp.jnz:
					if (PR._globals_int[st.a] != 0)
						s += st.b - 1;
				case PROp.jump:
					s += st.a - 1;
				case PROp.call0 | PROp.call1 | PROp.call2 | PROp.call3 | PROp.call4 | PROp.call5 | PROp.call6 | PROp.call7 | PROp.call8:
					PR.argc = st.op - PROp.call0;
					if (PR._globals_int[st.a] == 0)
						PR.RunError('NULL function');
					var newf = PR.functions[PR._globals_int[st.a]];
					if (newf.first_statement < 0) {
						var ptr = -newf.first_statement;
						if (ptr >= PF.builtin.length)
							PR.RunError('Bad builtin call number');
						PF.builtin[ptr]();
						continue;
					}
					s = PR.EnterFunction(newf);
				case PROp.done | PROp.ret:
					PR._globals_int[OFS_RETURN] = PR._globals_int[st.a];
					PR._globals_int[OFS_RETURN + 1] = PR._globals_int[st.a + 1];
					PR._globals_int[OFS_RETURN + 2] = PR._globals_int[st.a + 2];
					s = PR.LeaveFunction();
					if (PR.depth == exitdepth)
						return;
				case PROp.state:
					var ed:Edict = SV.server.edicts[PR.globals.self];
					ed.v.nextthink = PR.globals.time + 0.1;
					ed.v.frame = PR._globals_float[st.a];
					ed.v.think = PR._globals_int[st.b];
				default:
					PR.RunError('Bad opcode ' + st.op);
			}
		}
	}

	static function GetString(num:Int):String {
		var buf = new StringBuf();
		for (num in num...PR.strings.length) {
			if (PR.strings[num] == 0)
				break;
			buf.addChar(PR.strings[num]);
		}
		return buf.toString();
	}

	static function NewString(s:String, length:Int):Int {
		var ofs = PR.strings.length;
		var old_strings = PR.strings;
		PR.strings = new Uint8Array(ofs + length);
		PR.strings.set(old_strings);
		var end = if (s.length >= length) length - 1 else s.length;
		for (i in 0...end)
			PR.strings[ofs + i] = s.charCodeAt(i);
		return ofs;
	}

	static function TempString(string:String):Void {
		if (string.length > 127)
			string = string.substring(0, 127);
		for (i in 0...string.length)
			PR.strings[PR.string_temp + i] = string.charCodeAt(i);
		PR.strings[PR.string_temp + string.length] = 0;
	}
}
