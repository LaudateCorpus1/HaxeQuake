package quake;

import js.html.ArrayBuffer;
import js.html.Uint8Array;
import quake.CL.ClientCmd;
import quake.ED.Edict;
import quake.Mod.MModel;
import quake.NET.INETSocket;
import quake.PR.EType;
import quake.Protocol.SVC;
import quake.SV.MoveType;
using Tools;

@:publicFields
class HClient {
	var active:Bool;
	var spawned:Bool;
	var sendsignon:Bool;
	var dropasap:Bool;
	var message:MSG;
	var netconnection:INETSocket;
	var edict:Edict;
	var old_frags:Int;
	var num:Int;
	var colors:Int;
	var spawn_parms:Array<Float>;
	var last_message:Float;
	var cmd:ClientCmd;
	var wishdir:Vec;
	var ping_times:Array<Float>;
	var num_pings:Int;
	function new() {
		num = 0;
		message = new MSG(8000);
		message.allowoverflow = true;
		colors = 0;
		old_frags = 0;
	}
}

@:expose("Host")
@:publicFields
class Host {

	static var framerate:Cvar;
	static var speeds:Cvar;
	static var ticrate:Cvar;
	static var serverprofile:Cvar;
	static var fraglimit:Cvar;
	static var timelimit:Cvar;
	static var teamplay:Cvar;
	static var samelevel:Cvar;
	static var noexit:Cvar;
	static var skill:Cvar;
	static var developer:Cvar;
	static var deathmatch:Cvar;
	static var coop:Cvar;
	static var pausable:Cvar;
	static var temp1:Cvar;

static var framecount = 0;
static var current_skill:Int;

static function EndGame(message) {
	Console.DPrint('Host.EndGame: ' + message + '\n');
	if (CL.cls.demonum != -1)
		CL.NextDemo();
	else
		CL.Disconnect();
	throw 'Host.abortserver';
}

static var inerror = false;
static var noclip_anglehack = false;

static function Error(error) {
	if (Host.inerror)
		Sys.Error('Host.Error: recursively entered');
	Host.inerror = true;
	SCR.EndLoadingPlaque();
	Console.Print('Host.Error: ' + error + '\n');
	if (SV.server.active)
		Host.ShutdownServer(false);
	CL.Disconnect();
	CL.cls.demonum = -1;
	Host.inerror = false;
	throw new js.Error('Host.abortserver');
}

static function FindMaxClients() {
	SV.svs.maxclients = SV.svs.maxclientslimit = 1;
	CL.cls.state = CL.active.disconnected;
	SV.svs.clients = [new HClient()];
	Cvar.SetValue('deathmatch', 0);
}

static function InitLocal() {
	Host.InitCommands();
	Host.framerate = Cvar.RegisterVariable('host_framerate', '0');
	Host.speeds = Cvar.RegisterVariable('host_speeds', '0');
	Host.ticrate = Cvar.RegisterVariable('sys_ticrate', '0.05');
	Host.serverprofile = Cvar.RegisterVariable('serverprofile', '0');
	Host.fraglimit = Cvar.RegisterVariable('fraglimit', '0', false, true);
	Host.timelimit = Cvar.RegisterVariable('timelimit', '0', false, true);
	Host.teamplay = Cvar.RegisterVariable('teamplay', '0', false, true);
	Host.samelevel = Cvar.RegisterVariable('samelevel', '0');
	Host.noexit = Cvar.RegisterVariable('noexit', '0', false, true);
	Host.skill = Cvar.RegisterVariable('skill', '1');
	Host.developer = Cvar.RegisterVariable('developer', '0');
	Host.deathmatch = Cvar.RegisterVariable('deathmatch', '0');
	Host.coop = Cvar.RegisterVariable('coop', '0');
	Host.pausable = Cvar.RegisterVariable('pausable', '1');
	Host.temp1 = Cvar.RegisterVariable('temp1', '0');
	Host.FindMaxClients();
}

static function ClientPrint(string:String):Void {
	MSG.WriteByte(Host.client.message, SVC.print);
	MSG.WriteString(Host.client.message, string);
}

static function BroadcastPrint(string:String):Void {
	for (i in 0...SV.svs.maxclients) {
		var client = SV.svs.clients[i];
		if ((client.active != true) || (client.spawned != true))
			continue;
		MSG.WriteByte(client.message, SVC.print);
		MSG.WriteString(client.message, string);
	}
}

static function DropClient(crash:Bool):Void {
	var client = Host.client;
	if (!crash) {
		if (NET.CanSendMessage(client.netconnection)) {
			MSG.WriteByte(client.message, SVC.disconnect);
			NET.SendMessage(client.netconnection, client.message);
		}
		if ((client.edict != null) && (client.spawned)) {
			var saveSelf = PR.globals_int[PR.globalvars.self];
			PR.globals_int[PR.globalvars.self] = client.edict.num;
			PR.ExecuteProgram(PR.globals_int[PR.globalvars.ClientDisconnect]);
			PR.globals_int[PR.globalvars.self] = saveSelf;
		}
		Sys.Print('Client ' + SV.GetClientName(client) + ' removed\n');
	}
	NET.Close(client.netconnection);
	client.netconnection = null;
	client.active = false;
	SV.SetClientName(client, '');
	client.old_frags = -999999;
	--NET.activeconnections;
	var num = client.num;
	for (i in 0...SV.svs.maxclients) {
		var client = SV.svs.clients[i];
		if (!client.active)
			continue;
		MSG.WriteByte(client.message, SVC.updatename);
		MSG.WriteByte(client.message, num);
		MSG.WriteByte(client.message, 0);
		MSG.WriteByte(client.message, SVC.updatefrags);
		MSG.WriteByte(client.message, num);
		MSG.WriteShort(client.message, 0);
		MSG.WriteByte(client.message, SVC.updatecolors);
		MSG.WriteByte(client.message, num);
		MSG.WriteByte(client.message, 0);
	}
}

static var client:HClient;

static function ShutdownServer(crash) {
	if (SV.server.active != true)
		return;
	SV.server.active = false;
	if (CL.cls.state == CL.active.connected)
		CL.Disconnect();
	var start = Sys.FloatTime(), count = 0;
	do
	{
		for (i in 0...SV.svs.maxclients) {
			Host.client = SV.svs.clients[i];
			if ((Host.client.active != true) || (Host.client.message.cursize == 0))
				continue;
			if (NET.CanSendMessage(Host.client.netconnection)) {
				NET.SendMessage(Host.client.netconnection, Host.client.message);
				Host.client.message.cursize = 0;
				continue;
			}
			NET.GetMessage(Host.client.netconnection);
			++count;
		}
		if ((Sys.FloatTime() - start) > 3.0)
			break;
	} while (count != 0);
	var buf = new MSG(4, 1);
	(new Uint8Array(buf.data))[0] = SVC.disconnect;
	count = NET.SendToAll(buf);
	if (count != 0)
		Console.Print('Host.ShutdownServer: NET.SendToAll failed for ' + count + ' clients\n');
	for (i in 0...SV.svs.maxclients) {
		Host.client = SV.svs.clients[i];
		if (Host.client.active)
			Host.DropClient(crash);
	}
}

static function WriteConfiguration() {
	COM.WriteTextFile('config.cfg', Key.WriteBindings() + Cvar.WriteVariables());
}

static var frametime:Float;
static var realtime:Float;
static var oldrealtime:Float;

static function ServerFrame() {
	PR.globals_float[PR.globalvars.frametime] = Host.frametime;
	SV.server.datagram.cursize = 0;
	SV.CheckForNewClients();
	SV.RunClients();
	if ((SV.server.paused != true) && ((SV.svs.maxclients >= 2) || (Key.dest.value == Key.dest.game)))
		SV.Physics();
	SV.SendClientMessages();
}

static var time3 = 0.0;
static function _Frame() {
	Math.random();

	Host.realtime = Sys.FloatTime();
	Host.frametime = Host.realtime - Host.oldrealtime;
	Host.oldrealtime = Host.realtime;
	if (Host.framerate.value > 0)
		Host.frametime = Host.framerate.value;
	else {
		if (Host.frametime > 0.1)
			Host.frametime = 0.1;
		else if (Host.frametime < 0.001)
			Host.frametime = 0.001;
	}

	if (CL.cls.state == CL.active.connecting) {
		NET.CheckForResend();
		SCR.UpdateScreen();
		return;
	}

	var time1, time2, pass1, pass2, pass3, tot;

	Cmd.Execute();

	CL.SendCmd();
	if (SV.server.active)
		Host.ServerFrame();

	if (CL.cls.state == CL.active.connected)
		CL.ReadFromServer();

	if (Host.speeds.value != 0)
		time1 = Sys.FloatTime();
	SCR.UpdateScreen();
	if (Host.speeds.value != 0)
		time2 = Sys.FloatTime();

	if (CL.cls.signon == 4) {
		S.Update(R.refdef.vieworg, R.vpn, R.vright, R.vup);
		CL.DecayLights();
	}
	else
		S.Update(Vec.origin, Vec.origin, Vec.origin, Vec.origin);
	CDAudio.Update();

	if (Host.speeds.value != 0) {
		pass1 = (time1 - Host.time3) * 1000.0;
		Host.time3 = Sys.FloatTime();
		pass2 = (time2 - time1) * 1000.0;
		pass3 = (Host.time3 - time2) * 1000.0;
		tot = Math.floor(pass1 + pass2 + pass3);
		Console.Print((tot <= 99 ? (tot <= 9 ? '  ' : ' ') : '')
			+ tot + ' tot '
			+ (pass1 < 100.0 ? (pass1 < 10.0 ? '  ' : ' ') : '')
			+ Math.floor(pass1) + ' server '
			+ (pass2 < 100.0 ? (pass2 < 10.0 ? '  ' : ' ') : '')
			+ Math.floor(pass2) + ' gfx '
			+ (pass3 < 100.0 ? (pass3 < 10.0 ? '  ' : ' ') : '')
			+ Math.floor(pass3) + ' snd\n');
	}

	if (Host.startdemos) {
		CL.NextDemo();
		Host.startdemos = false;
	}

	++Host.framecount;
}

static var timetotal = 0.0;
static var timecount = 0;
static function Frame() {
	if (Host.serverprofile.value == 0) {
		Host._Frame();
		return;
	}
	var time1 = Sys.FloatTime();
	Host._Frame();
	Host.timetotal += Sys.FloatTime() - time1;
	if (++Host.timecount <= 999)
		return;
	var m = Std.int(Host.timetotal * 1000.0 / Host.timecount);
	Host.timecount = 0;
	Host.timetotal = 0.0;
	var c = 0;
	for (i in 0...SV.svs.maxclients) {
		if (SV.svs.clients[i].active)
			++c;
	}
	Console.Print('serverprofile: ' + (c <= 9 ? ' ' : '') + c + ' clients ' + (m <= 9 ? ' ' : '') + m + ' msec\n');
}

static function Init() {
	Host.oldrealtime = Sys.FloatTime();
	Cmd.Init();
	V.Init();
	Chase.Init();
	COM.Init();
	Host.InitLocal();
	W.LoadWadFile('gfx.wad');
	Key.Init();
	Console.Init();
	PR.Init();
	Mod.Init();
	NET.Init();
	SV.Init();
	Console.Print(Def.timedate);
	VID.Init();
	Draw.Init();
	SCR.Init();
	R.Init();
	S.Init();
	M.Init();
	CDAudio.Init();
	Sbar.Init();
	CL.Init();
	IN.Init();
	Cmd.text = 'exec quake.rc\n' + Cmd.text;
	Host.initialized = true;
	Sys.Print('======Quake Initialized======\n');
}

static var initialized = false;
static var isdown = false;

static function Shutdown() {
	if (Host.isdown) {
		Sys.Print('recursive shutdown\n');
		return;
	}
	Host.isdown = true;
	Host.WriteConfiguration();
	CDAudio.Stop();
	NET.Shutdown();
	S.StopAllSounds();
	IN.Shutdown();
}

// Commands

static function Quit_f() {
	if (Key.dest.value != Key.dest.console) {
		M.Menu_Quit_f();
		return;
	}
	Sys.Quit();
}

static function Status_f() {
	var print;
	if (Cmd.client != true) {
		if (SV.server.active != true) {
			Cmd.ForwardToServer();
			return;
		}
		print = Console.Print;
	}
	else
		print = (cast SV).ClientPrint;
	print('host:    ' + NET.hostname.string + '\n');
	print('version: 1.09\n');
	print('map:     ' + PR.GetString(PR.globals_int[PR.globalvars.mapname]) + '\n');
	print('players: ' + NET.activeconnections + ' active (' + SV.svs.maxclients + ' max)\n\n');
	for (i in 0...SV.svs.maxclients) {
		var client = SV.svs.clients[i];
		if (client.active != true)
			continue;
		var frags = client.edict.v_float[PR.entvars.frags].toFixed(0);
		if (frags.length == 1)
			frags = '  ' + frags;
		else if (frags.length == 2)
			frags = ' ' + frags;
		var seconds = Std.int(NET.time - client.netconnection.connecttime);
		var minutes = Std.int(seconds / 60);
		var hours;
		if (minutes != 0) {
			seconds -= minutes * 60;
			hours = Std.int(minutes / 60);
			if (hours != 0)
				minutes -= hours * 60;
		}
		else
			hours = 0;
		var str = '#' + (i + 1) + ' ';
		if (i <= 8)
			str += ' ';
		str += SV.GetClientName(client);
		while (str.length <= 21)
			str += ' ';
		str += frags + '  ';
		if (hours <= 9)
			str += ' ';
		str += hours + ':';
		if (minutes <= 9)
			str += '0';
		str += minutes + ':';
		if (seconds <= 9)
			str += '0';
		print(str + seconds + '\n');
		print('   ' + client.netconnection.address + '\n');
	}
}

static function God_f() {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	if (PR.globals_float[PR.globalvars.deathmatch] != 0)
		return;
	SV.player.flags = SV.player.flags ^ SV.fl.godmode;
	if ((SV.player.flags & SV.fl.godmode) == 0)
		Host.ClientPrint('godmode OFF\n');
	else
		Host.ClientPrint('godmode ON\n');
}

static function Notarget_f() {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	if (PR.globals_float[PR.globalvars.deathmatch] != 0)
		return;
	SV.player.flags = SV.player.flags ^ SV.fl.notarget;
	if ((SV.player.flags & SV.fl.notarget) == 0)
		Host.ClientPrint('notarget OFF\n');
	else
		Host.ClientPrint('notarget ON\n');
}

static function Noclip_f() {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	if (PR.globals_float[PR.globalvars.deathmatch] != 0)
		return;
	if (SV.player.v_float[PR.entvars.movetype] != MoveType.noclip) {
		Host.noclip_anglehack = true;
		SV.player.v_float[PR.entvars.movetype] = MoveType.noclip;
		Host.ClientPrint('noclip ON\n');
		return;
	}
	Host.noclip_anglehack = false;
	SV.player.v_float[PR.entvars.movetype] = MoveType.walk;
	Host.ClientPrint('noclip OFF\n');
}

static function Fly_f() {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	if (PR.globals_float[PR.globalvars.deathmatch] != 0)
		return;
	if (SV.player.v_float[PR.entvars.movetype] != MoveType.fly) {
		SV.player.v_float[PR.entvars.movetype] = MoveType.fly;
		Host.ClientPrint('flymode ON\n');
		return;
	}
	SV.player.v_float[PR.entvars.movetype] = MoveType.walk;
	Host.ClientPrint('flymode OFF\n');
}

static function Ping_f() {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	Host.ClientPrint('Client ping times:\n');
	for (i in 0...SV.svs.maxclients) {
		var client = SV.svs.clients[i];
		if (client.active != true)
			continue;
		var total = 0.0;
		for (j in 0...16)
			total += client.ping_times[j];
		var total = (total * 62.5).toFixed(0);
		if (total.length == 1)
			total = '   ' + total;
		else if (total.length == 2)
			total = '  ' + total;
		else if (total.length == 3)
			total = ' ' + total;
		Host.ClientPrint(total + ' ' + SV.GetClientName(client) + '\n');
	}
}

static function Map_f() {
	if (Cmd.argv.length <= 1) {
		Console.Print('USAGE: map <map>\n');
		return;
	}
	if (Cmd.client)
		return;
	CL.cls.demonum = -1;
	CL.Disconnect();
	Host.ShutdownServer(false);
	Key.dest.value = Key.dest.game;
	SCR.BeginLoadingPlaque();
	SV.svs.serverflags = 0;
	SV.SpawnServer(Cmd.argv[1]);
	if (SV.server.active != true)
		return;
	CL.cls.spawnparms = '';
	for (i in 2...Cmd.argv.length)
		CL.cls.spawnparms += Cmd.argv[i] + ' ';
	Cmd.ExecuteString('connect local');
}

static function Changelevel_f() {
	if (Cmd.argv.length != 2) {
		Console.Print('changelevel <levelname> : continue game on a new level\n');
		return;
	}
	if ((SV.server.active != true) || (CL.cls.demoplayback)) {
		Console.Print('Only the server may changelevel\n');
		return;
	}
	SV.SaveSpawnparms();
	SV.SpawnServer(Cmd.argv[1]);
}

static function Restart_f() {
	if ((CL.cls.demoplayback != true) && (SV.server.active) && (Cmd.client != true))
		SV.SpawnServer(PR.GetString(PR.globals_int[PR.globalvars.mapname]));
}

static function Reconnect_f() {
	SCR.BeginLoadingPlaque();
	CL.cls.signon = 0;
}

static function Connect_f() {
	CL.cls.demonum = -1;
	if (CL.cls.demoplayback) {
		CL.StopPlayback();
		CL.Disconnect();
	}
	CL.EstablishConnection(Cmd.argv[1]);
	CL.cls.signon = 0;
}

static function SavegameComment() {
	var text = ~/\s/gm.replace(CL.state.levelname, "_");
	for (i in CL.state.levelname.length...22)
		text += '_';

	text += 'kills:';
	var kills = Std.string(CL.state.stats[Def.stat.monsters]);
	if (kills.length == 2)
		text += '_';
	else if (kills.length == 1)
		text += '__';
	text += kills + '/';
	kills = Std.string(CL.state.stats[Def.stat.totalmonsters]);
	if (kills.length == 2)
		text += '_';
	else if (kills.length == 1)
		text += '__';
	text += kills;

	return text + '____';
}

static function Savegame_f() {
	if (Cmd.client)
		return;
	if (SV.server.active != true) {
		Console.Print('Not playing a local game.\n');
		return;
	}
	if (CL.state.intermission != 0) {
		Console.Print('Can\'t save in intermission.\n');
		return;
	}
	if (SV.svs.maxclients != 1) {
		Console.Print('Can\'t save multiplayer games.\n');
		return;
	}
	if (Cmd.argv.length != 2) {
		Console.Print('save <savename> : save a game\n');
		return;
	}
	if (Cmd.argv[1].indexOf('..') != -1) {
		Console.Print('Relative pathnames are not allowed.\n');
		return;
	}
	var client = SV.svs.clients[0];
	if (client.active) {
		if (client.edict.v_float[PR.entvars.health] <= 0.0) {
			Console.Print('Can\'t savegame with a dead player\n');
			return;
		}
	}
	var f = ['5\n' + Host.SavegameComment() + '\n'];
	for (i in 0...16)
		f[f.length] = client.spawn_parms[i].toFixed(6) + '\n';
	f[f.length] = Host.current_skill + '\n' + PR.GetString(PR.globals_int[PR.globalvars.mapname]) + '\n' + SV.server.time.toFixed(6) + '\n';
	for (i in 0...64) {
		if (SV.server.lightstyles[i].length != 0)
			f[f.length] = SV.server.lightstyles[i] + '\n';
		else
			f[f.length] = 'm\n';
	}
	f[f.length] = '{\n';
	for (def in PR.globaldefs) {
		var type = def.type;
		if ((type & 0x8000) == 0)
			continue;
		var type:EType = type & 0x7fff;
		if ((type != ev_string) && (type != ev_float) && (type != ev_entity))
			continue;
		f[f.length] = '"' + PR.GetString(def.name) + '" "' + PR.UglyValueString(cast type, PR.globals, def.ofs) + '"\n';
	}
	f[f.length] = '}\n';
	for (i in 0...SV.server.num_edicts) {
		var ed = SV.server.edicts[i];
		if (ed.free) {
			f[f.length] = '{\n}\n';
			continue;
		}
		f[f.length] = '{\n';
		for (def in PR.fielddefs) {
			var name = PR.GetString(def.name);
			if (name.charCodeAt(name.length - 2) == 95)
				continue;
			var type = def.type & 0x7fff;
			var v = def.ofs;
			if (ed.v_int[v] == 0) {
				if (type == 3) {
					if ((ed.v_int[v + 1] == 0) && (ed.v_int[v + 2] == 0))
						continue;
				}
				else
					continue;
			}
			f[f.length] = '"' + name + '" "' + PR.UglyValueString(type, ed.v, def.ofs) + '"\n';
		}
		f[f.length] = '}\n';
	}
	var name = COM.DefaultExtension(Cmd.argv[1], '.sav');
	Console.Print('Saving game to ' + name + '...\n');
	if (COM.WriteTextFile(name, f.join('')))
		Console.Print('done.\n');
	else
		Console.Print('ERROR: couldn\'t open.\n');
}

static function Loadgame_f() {
	if (Cmd.client)
		return;
	if (Cmd.argv.length != 2) {
		Console.Print('load <savename> : load a game\n');
		return;
	}
	CL.cls.demonum = -1;
	var name = COM.DefaultExtension(Cmd.argv[1], '.sav');
	Console.Print('Loading game from ' + name + '...\n');
	var f = COM.LoadTextFile(name);
	if (f == null) {
		Console.Print('ERROR: couldn\'t open.\n');
		return;
	}
	var f = f.split('\n');

	var tfloat = Std.parseFloat(f[0]);
	if (tfloat != 5) {
		Console.Print('Savegame is version ' + tfloat + ', not 5\n');
		return;
	}

	var spawn_parms = [];
	for (i in 0...16)
		spawn_parms[i] = Std.parseFloat(f[2 + i]);

	Host.current_skill = Std.int(Std.parseFloat(f[18]) + 0.1);
	Cvar.SetValue('skill', Host.current_skill);

	var time = Std.parseFloat(f[20]);
	CL.Disconnect();
	SV.SpawnServer(f[19]);
	if (SV.server.active != true) {
		Console.Print('Couldn\'t load map\n');
		return;
	}
	SV.server.paused = true;
	SV.server.loadgame = true;

	for (i in 0...64)
		SV.server.lightstyles[i] = f[21 + i];

	if (f[85] != '{')
		Sys.Error('First token isn\'t a brace');
	var i = 86;
	while (i < f.length) {
		if (f[i] == '}') {
			++i;
			break;
		}
		var token = f[i].split('"');
		var keyname = token[1];
		var key = ED.FindGlobal(keyname);
		i++;
		if (key == null) {
			Console.Print('\'' + keyname + '\' is not a global\n');
			continue;
		}
		if (ED.ParseEpair(PR.globals, key, token[3]) != true)
			Host.Error('Host.Loadgame_f: parse error');
	}

	f[f.length] = '';
	var entnum = 0;
	var data = f.slice(i).join('\n');
	while(true) {
		data = COM.Parse(data);
		if (data == null)
			break;
		if (COM.token.charCodeAt(0) != 123)
			Sys.Error('Host.Loadgame_f: found ' + COM.token + ' when expecting {');
		var ent:Edict = SV.server.edicts[entnum++];
		for (j in 0...PR.entityfields)
			ent.v_int[j] = 0;
		ent.free = false;
		data = ED.ParseEdict(data, ent);
		if (ent.free != true)
			SV.LinkEdict(ent, false);
	}
	SV.server.num_edicts = entnum;

	SV.server.time = time;
	var client = SV.svs.clients[0];
	client.spawn_parms = [];
	for (i in 0...16)
		client.spawn_parms[i] = spawn_parms[i];
	CL.EstablishConnection('local');
	Host.Reconnect_f();
}

static function Name_f() {
	if (Cmd.argv.length <= 1) {
		Console.Print('"name" is "' + CL.name.string + '"\n');
		return;
	}

	var newName;
	if (Cmd.argv.length == 2)
		newName = Cmd.argv[1].substring(0, 15);
	else
		newName = Cmd.args.substring(0, 15);

	if (Cmd.client != true) {
		Cvar.Set('_cl_name', newName);
		if (CL.cls.state == CL.active.connected)
			Cmd.ForwardToServer();
		return;
	}

	var name = SV.GetClientName(Host.client);
	if ((name.length != 0) && (name != 'unconnected') && (name != newName))
		Console.Print(name + ' renamed to ' + newName + '\n');
	SV.SetClientName(Host.client, newName);
	var msg = SV.server.reliable_datagram;
	MSG.WriteByte(msg, SVC.updatename);
	MSG.WriteByte(msg, Host.client.num);
	MSG.WriteString(msg, newName);
}

static function Version_f() {
	Console.Print('Version 1.09\n');
	Console.Print(Def.timedate);
}

static function Say(teamonly) {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	if (Cmd.argv.length <= 1)
		return;
	var save = Host.client;
	var p = Cmd.args;
	if (p.charCodeAt(0) == 34)
		p = p.substring(1, p.length - 1);
	var text = String.fromCharCode(1)+ SV.GetClientName(save) + ': ';
	var i = 62 - text.length;
	if (p.length > i)
		p = p.substring(0, i);
	text += p + '\n';
	for (i in 0...SV.svs.maxclients) {
		var client:HClient = SV.svs.clients[i];
		if ((client.active != true) || (client.spawned != true))
			continue;
		if ((Host.teamplay.value != 0) && (teamonly) && (client.edict.v_float[PR.entvars.team] != save.edict.v_float[PR.entvars.team]))
			continue;
		Host.client = client;
		Host.ClientPrint(text);
	}
	Host.client = save;
	Sys.Print(text.substring(1));
}

static function Say_Team_f() {
	Host.Say(true);
}

static function Tell_f() {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	if (Cmd.argv.length <= 2)
		return;
	var text = SV.GetClientName(Host.client) + ': ';
	var p = Cmd.args;
	if (p.charCodeAt(0) == 34)
		p = p.substring(1, p.length - 1);
	var i = 62 - text.length;
	if (p.length > i)
		 p = p.substring(0, i);
	text += p + '\n';
	var save = Host.client;
	for (i in 0...SV.svs.maxclients) {
		var client:HClient = SV.svs.clients[i];
		if ((client.active != true) || (client.spawned != true))
			continue;
		if (SV.GetClientName(client).toLowerCase() != Cmd.argv[1].toLowerCase())
			continue;
		Host.client = client;
		Host.ClientPrint(text);
		break;
	}
	Host.client = save;
}

static function Color_f() {
	if (Cmd.argv.length <= 1) {
		var col = Std.int(CL.color.value);
		Console.Print('"color" is "' + (col >> 4) + ' ' + (col & 15) + '"\ncolor <0-13> [0-13]\n');
		return;
	}

	var top, bottom;
	if (Cmd.argv.length == 2)
		top = bottom = (Q.atoi(Cmd.argv[1]) & 15) >>> 0;
	else {
		top = (Q.atoi(Cmd.argv[1]) & 15) >>> 0;
		bottom = (Q.atoi(Cmd.argv[2]) & 15) >>> 0;
	}
	if (top >= 14)
		top = 13;
	if (bottom >= 14)
		bottom = 13;
	var playercolor = (top << 4) + bottom;

	if (Cmd.client != true) {
		Cvar.SetValue('_cl_color', playercolor);
		if (CL.cls.state == CL.active.connected)
			Cmd.ForwardToServer();
		return;
	}

	Host.client.colors = playercolor;
	Host.client.edict.v_float[PR.entvars.team] = bottom + 1;
	var msg = SV.server.reliable_datagram;
	MSG.WriteByte(msg, SVC.updatecolors);
	MSG.WriteByte(msg, Host.client.num);
	MSG.WriteByte(msg, playercolor);
}

static function Kill_f() {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	if (SV.player.v_float[PR.entvars.health] <= 0.0) {
		Host.ClientPrint('Can\'t suicide -- allready dead!\n');
		return;
	}
	PR.globals_float[PR.globalvars.time] = SV.server.time;
	PR.globals_int[PR.globalvars.self] = SV.player.num;
	PR.ExecuteProgram(PR.globals_int[PR.globalvars.ClientKill]);
}

static function Pause_f() {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	if (Host.pausable.value == 0) {
		Host.ClientPrint('Pause not allowed.\n');
		return;
	}
	SV.server.paused = !SV.server.paused;
	Host.BroadcastPrint(SV.GetClientName(Host.client) + (SV.server.paused ? ' paused the game\n' : ' unpaused the game\n'));
	MSG.WriteByte(SV.server.reliable_datagram, SVC.setpause);
	MSG.WriteByte(SV.server.reliable_datagram, SV.server.paused ? 1 : 0);
}

static function PreSpawn_f() {
	if (Cmd.client != true) {
		Console.Print('prespawn is not valid from the console\n');
		return;
	}
	var client = Host.client;
	if (client.spawned) {
		Console.Print('prespawn not valid -- allready spawned\n');
		return;
	}
	SZ.Write(client.message, new Uint8Array(SV.server.signon.data), SV.server.signon.cursize);
	MSG.WriteByte(client.message, SVC.signonnum);
	MSG.WriteByte(client.message, 2);
	client.sendsignon = true;
}

static function Spawn_f() {
	if (Cmd.client != true) {
		Console.Print('spawn is not valid from the console\n');
		return;
	}
	var client = Host.client;
	if (client.spawned) {
		Console.Print('Spawn not valid -- allready spawned\n');
		return;
	}

	var ent = client.edict;
	if (SV.server.loadgame)
		SV.server.paused = false;
	else {
		for (i in 0...PR.entityfields)
			ent.v_int[i] = 0;
		ent.v_float[PR.entvars.colormap] = ent.num;
		ent.v_float[PR.entvars.team] = (client.colors & 15) + 1;
		ent.v_int[PR.entvars.netname] = PR.netnames + (client.num << 5);
		for (i in 0...16)
			PR.globals_float[PR.globalvars.parms + i] = client.spawn_parms[i];
		PR.globals_float[PR.globalvars.time] = SV.server.time;
		PR.globals_int[PR.globalvars.self] = ent.num;
		PR.ExecuteProgram(PR.globals_int[PR.globalvars.ClientConnect]);
		if ((Sys.FloatTime() - client.netconnection.connecttime) <= SV.server.time)
			Sys.Print(SV.GetClientName(client) + ' entered the game\n');
		PR.ExecuteProgram(PR.globals_int[PR.globalvars.PutClientInServer]);
	}

	var message = client.message;
	message.cursize = 0;
	MSG.WriteByte(message, SVC.time);
	MSG.WriteFloat(message, SV.server.time);
	for (i in 0...SV.svs.maxclients) {
		client = SV.svs.clients[i];
		MSG.WriteByte(message, SVC.updatename);
		MSG.WriteByte(message, i);
		MSG.WriteString(message, SV.GetClientName(client));
		MSG.WriteByte(message, SVC.updatefrags);
		MSG.WriteByte(message, i);
		MSG.WriteShort(message, client.old_frags);
		MSG.WriteByte(message, SVC.updatecolors);
		MSG.WriteByte(message, i);
		MSG.WriteByte(message, client.colors);
	}
	for (i in 0...64) {
		MSG.WriteByte(message, SVC.lightstyle);
		MSG.WriteByte(message, i);
		MSG.WriteString(message, SV.server.lightstyles[i]);
	}
	MSG.WriteByte(message, SVC.updatestat);
	MSG.WriteByte(message, Def.stat.totalsecrets);
	MSG.WriteLong(message, Std.int(PR.globals_float[PR.globalvars.total_secrets]));
	MSG.WriteByte(message, SVC.updatestat);
	MSG.WriteByte(message, Def.stat.totalmonsters);
	MSG.WriteLong(message, Std.int(PR.globals_float[PR.globalvars.total_monsters]));
	MSG.WriteByte(message, SVC.updatestat);
	MSG.WriteByte(message, Def.stat.secrets);
	MSG.WriteLong(message, Std.int(PR.globals_float[PR.globalvars.found_secrets]));
	MSG.WriteByte(message, SVC.updatestat);
	MSG.WriteByte(message, Def.stat.monsters);
	MSG.WriteLong(message, Std.int(PR.globals_float[PR.globalvars.killed_monsters]));
	MSG.WriteByte(message, SVC.setangle);
	MSG.WriteAngle(message, ent.v_float[PR.entvars.angles]);
	MSG.WriteAngle(message, ent.v_float[PR.entvars.angles1]);
	MSG.WriteAngle(message, 0.0);
	SV.WriteClientdataToMessage(ent, message);
	MSG.WriteByte(message, SVC.signonnum);
	MSG.WriteByte(message, 3);
	Host.client.sendsignon = true;
}

static function Begin_f() {
	if (Cmd.client != true) {
		Console.Print('begin is not valid from the console\n');
		return;
	}
	Host.client.spawned = true;
}

static function Kick_f() {
	if (Cmd.client != true) {
		if (SV.server.active != true) {
			Cmd.ForwardToServer();
			return;
		}
	}
	else if (PR.globals_float[PR.globalvars.deathmatch] != 0.0)
		return;
	var save = Host.client;
	var i, byNumber;
	if ((Cmd.argv.length >= 3) && (Cmd.argv[1] == '#')) {
		i = Q.atoi(Cmd.argv[2]) - 1;
		if ((i < 0) || (i >= SV.svs.maxclients))
			return;
		if (SV.svs.clients[i].active != true)
			return;
		Host.client = SV.svs.clients[i];
		byNumber = true;
	} else {
		i = 0;
		while (i < SV.svs.maxclients) {
			Host.client = SV.svs.clients[i];
			if (Host.client.active != true) {
				i++;
				continue;
			}
			if (SV.GetClientName(Host.client).toLowerCase() == Cmd.argv[1].toLowerCase())
				break;
			i++;
		}
	}
	if (i >= SV.svs.maxclients) {
		Host.client = save;
		return;
	}
	if (Host.client == save)
		return;
	var who;
	if (Cmd.client != true)
		who = CL.name.string;
	else {
		if (Host.client == save)
			return;
		who = SV.GetClientName(save);
	}
	var message;
	if (Cmd.argv.length >= 3)
		message = COM.Parse(Cmd.args);
	if (message != null) {
		var p = 0;
		if (byNumber) {
			++p;
			while (p < message.length) {
				if (message.charCodeAt(p) != 32)
					break;
				p++;
			}
			p += Cmd.argv[2].length;
		}
		while (p < message.length) {
			if (message.charCodeAt(p) != 32)
				break;
			p++;
		}
		Host.ClientPrint('Kicked by ' + who + ': ' + message.substring(p) + '\n');
	}
	else
		Host.ClientPrint('Kicked by ' + who + '\n');
	Host.DropClient(false);
	Host.client = save;
}

static function Give_f() {
	if (Cmd.client != true) {
		Cmd.ForwardToServer();
		return;
	}
	if (PR.globals_float[PR.globalvars.deathmatch] != 0)
		return;
	if (Cmd.argv.length <= 1)
		return;
	var t = Cmd.argv[1].charCodeAt(0);
	var ent = SV.player;

	if ((t >= 48) && (t <= 57)) {
		if (COM.hipnotic != true) {
			if (t >= 50)
				ent.items |= Def.it.shotgun << (t - 50);
			return;
		}
		if (t == 54) {
			if (Cmd.argv[1].charCodeAt(1) == 97)
				ent.items |= Def.hit.proximity_gun;
			else
				ent.items |= Def.it.grenade_launcher;
			return;
		}
		if (t == 57)
			ent.items |= Def.hit.laser_cannon;
		else if (t == 48)
			ent.items |= Def.hit.mjolnir;
		else if (t >= 50)
			ent.items |= Def.it.shotgun << (t - 50);
		return;
	}
	var v = Q.atoi(Cmd.argv[2]);
	if (t == 104) {
		ent.v_float[PR.entvars.health] = v;
		return;
	}
	if (COM.rogue != true) {
		switch (t) {
		case 115:
			ent.v_float[PR.entvars.ammo_shells] = v;
			return;
		case 110:
			ent.v_float[PR.entvars.ammo_nails] = v;
			return;
		case 114:
			ent.v_float[PR.entvars.ammo_rockets] = v;
			return;
		case 99:
			ent.v_float[PR.entvars.ammo_cells] = v;
		}
		return;
	}
	switch (t) {
	case 115:
		if (PR.entvars.ammo_shells1 != null)
			ent.v_float[PR.entvars.ammo_shells1] = v;
		ent.v_float[PR.entvars.ammo_shells] = v;
		return;
	case 110:
		if (PR.entvars.ammo_nails1 != null) {
			ent.v_float[PR.entvars.ammo_nails1] = v;
			if (ent.v_float[PR.entvars.weapon] <= Def.it.lightning)
				ent.v_float[PR.entvars.ammo_nails] = v;
		}
		return;
	case 108:
		if (PR.entvars.ammo_lava_nails != null) {
			ent.v_float[PR.entvars.ammo_lava_nails] = v;
			if (ent.v_float[PR.entvars.weapon] > Def.it.lightning)
				ent.v_float[PR.entvars.ammo_nails] = v;
		}
		return;
	case 114:
		if (PR.entvars.ammo_rockets1 != null) {
			ent.v_float[PR.entvars.ammo_rockets1] = v;
			if (ent.v_float[PR.entvars.weapon] <= Def.it.lightning)
				ent.v_float[PR.entvars.ammo_rockets] = v;
		}
		return;
	case 109:
		if (PR.entvars.ammo_multi_rockets != null) {
			ent.v_float[PR.entvars.ammo_multi_rockets] = v;
			if (ent.v_float[PR.entvars.weapon] > Def.it.lightning)
				ent.v_float[PR.entvars.ammo_rockets] = v;
		}
		return;
	case 99:
		if (PR.entvars.ammo_cells1 != null) {
			ent.v_float[PR.entvars.ammo_cells1] = v;
			if (ent.v_float[PR.entvars.weapon] <= Def.it.lightning)
				ent.v_float[PR.entvars.ammo_cells] = v;
		}
		return;
	case 112:
		if (PR.entvars.ammo_plasma != null) {
			ent.v_float[PR.entvars.ammo_plasma] = v;
			if (ent.v_float[PR.entvars.weapon] > Def.it.lightning)
				ent.v_float[PR.entvars.ammo_cells] = v;
		}
	}
}

static function FindViewthing():Edict {
	if (SV.server.active) {
		for (i in 0...SV.server.num_edicts) {
			var e:Edict = SV.server.edicts[i];
			if (PR.GetString(e.v_int[PR.entvars.classname]) == 'viewthing')
				return e;
		}
	}
	Console.Print('No viewthing on map\n');
	return null;
}

static function Viewmodel_f() {
	if (Cmd.argv.length != 2)
		return;
	var ent = Host.FindViewthing();
	if (ent == null)
		return;
	var m = Mod.ForName(Cmd.argv[1], false);
	if (m == null) {
		Console.Print('Can\'t load ' + Cmd.argv[1] + '\n');
		return;
	}
	ent.v_float[PR.entvars.frame] = 0.0;
	CL.state.model_precache[Std.int(ent.v_float[PR.entvars.modelindex])] = m;
}

static function Viewframe_f() {
	var ent = Host.FindViewthing();
	if (ent == null)
		return;
	var m:MModel = CL.state.model_precache[Std.int(ent.v_float[PR.entvars.modelindex])];
	var f = Q.atoi(Cmd.argv[1]);
	if (f >= m.frames.length)
		f = m.frames.length - 1;
	ent.v_float[PR.entvars.frame] = f;
}

static function Viewnext_f() {
	var ent = Host.FindViewthing();
	if (ent == null)
		return;
	var m:MModel = CL.state.model_precache[Std.int(ent.v_float[PR.entvars.modelindex])];
	var f = Std.int(ent.v_float[PR.entvars.frame]) + 1;
	if (f >= m.frames.length)
		f = m.frames.length - 1;
	ent.v_float[PR.entvars.frame] = f;
	Console.Print('frame ' + f + ': ' + m.frames[f].name + '\n');
}

static function Viewprev_f() {
	var ent = Host.FindViewthing();
	if (ent == null)
		return;
	var m:MModel = CL.state.model_precache[Std.int(ent.v_float[PR.entvars.modelindex])];
	var f = Std.int(ent.v_float[PR.entvars.frame]) - 1;
	if (f < 0)
		f = 0;
	ent.v_float[PR.entvars.frame] = f;
	Console.Print('frame ' + f + ': ' + m.frames[f].name + '\n');
}

static var startdemos:Bool;

static function Startdemos_f() {
	Console.Print((Cmd.argv.length - 1) + ' demo(s) in loop\n');
	CL.cls.demos = [];
	for (i in 1...Cmd.argv.length)
		CL.cls.demos[i - 1] = Cmd.argv[i];
	if ((CL.cls.demonum != -1) && (CL.cls.demoplayback != true)) {
		CL.cls.demonum = 0;
		if (Host.framecount != 0)
			CL.NextDemo();
		else
			Host.startdemos = true;
	}
	else
		CL.cls.demonum = -1;
}

static function Demos_f() {
	if (CL.cls.demonum == -1)
		CL.cls.demonum = 1;
	CL.Disconnect();
	CL.NextDemo();
}

static function Stopdemo_f() {
	if (CL.cls.demoplayback != true)
		return;
	CL.StopPlayback();
	CL.Disconnect();
}

static function InitCommands() {
	Cmd.AddCommand('status', Host.Status_f);
	Cmd.AddCommand('quit', Host.Quit_f);
	Cmd.AddCommand('god', Host.God_f);
	Cmd.AddCommand('notarget', Host.Notarget_f);
	Cmd.AddCommand('fly', Host.Fly_f);
	Cmd.AddCommand('map', Host.Map_f);
	Cmd.AddCommand('restart', Host.Restart_f);
	Cmd.AddCommand('changelevel', Host.Changelevel_f);
	Cmd.AddCommand('connect', Host.Connect_f);
	Cmd.AddCommand('reconnect', Host.Reconnect_f);
	Cmd.AddCommand('name', Host.Name_f);
	Cmd.AddCommand('noclip', Host.Noclip_f);
	Cmd.AddCommand('version', Host.Version_f);
	Cmd.AddCommand('say', Host.Say.bind(false));
	Cmd.AddCommand('say_team', Host.Say_Team_f);
	Cmd.AddCommand('tell', Host.Tell_f);
	Cmd.AddCommand('color', Host.Color_f);
	Cmd.AddCommand('kill', Host.Kill_f);
	Cmd.AddCommand('pause', Host.Pause_f);
	Cmd.AddCommand('spawn', Host.Spawn_f);
	Cmd.AddCommand('begin', Host.Begin_f);
	Cmd.AddCommand('prespawn', Host.PreSpawn_f);
	Cmd.AddCommand('kick', Host.Kick_f);
	Cmd.AddCommand('ping', Host.Ping_f);
	Cmd.AddCommand('load', Host.Loadgame_f);
	Cmd.AddCommand('save', Host.Savegame_f);
	Cmd.AddCommand('give', Host.Give_f);
	Cmd.AddCommand('startdemos', Host.Startdemos_f);
	Cmd.AddCommand('demos', Host.Demos_f);
	Cmd.AddCommand('stopdemo', Host.Stopdemo_f);
	Cmd.AddCommand('viewmodel', Host.Viewmodel_f);
	Cmd.AddCommand('viewframe', Host.Viewframe_f);
	Cmd.AddCommand('viewnext', Host.Viewnext_f);
	Cmd.AddCommand('viewprev', Host.Viewprev_f);
	Cmd.AddCommand('mcache', Mod.Print);
}

}
