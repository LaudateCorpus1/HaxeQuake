package quake;

@:enum abstract TEType(Int) to Int {
	var spike = 0;
	var superspike = 1;
	var gunshot = 2;
	var explosion = 3;
	var tarexplosion = 4;
	var lightning1 = 5;
	var lightning2 = 6;
	var wizspike = 7;
	var knightspike = 8;
	var lightning3 = 9;
	var lavasplash = 10;
	var teleport = 11;
	var explosion2 = 12;
	var beam = 13;
}

@:enum abstract SVC(Int) to Int {
	var nop = 1;
	var disconnect = 2;
	var updatestat = 3;
	var version = 4;
	var setview = 5;
	var sound = 6;
	var time = 7;
	var print = 8;
	var stufftext = 9;
	var setangle = 10;
	var serverinfo = 11;
	var lightstyle = 12;
	var updatename = 13;
	var updatefrags = 14;
	var clientdata = 15;
	var stopsound = 16;
	var updatecolors = 17;
	var particle = 18;
	var damage = 19;
	var spawnstatic = 20;
	var spawnbaseline = 22;
	var temp_entity = 23;
	var setpause = 24;
	var signonnum = 25;
	var centerprint = 26;
	var killedmonster = 27;
	var foundsecret = 28;
	var spawnstaticsound = 29;
	var intermission = 30;
	var finale = 31;
	var cdtrack = 32;
	var sellscreen = 33;
	var cutscene = 34;
}

@:enum abstract U(Int) to Int {
	var morebits   = 1 << 0;
	var origin1    = 1 << 1;
	var origin2    = 1 << 2;
	var origin3    = 1 << 3;
	var angle2     = 1 << 4;
	var nolerp     = 1 << 5;
	var frame      = 1 << 6;
	var signal     = 1 << 7;

	var angle1     = 1 << 8;
	var angle3     = 1 << 9;
	var model      = 1 << 10;
	var colormap   = 1 << 11;
	var skin       = 1 << 12;
	var effects    = 1 << 13;
	var longentity = 1 << 14;
}


@:enum abstract SU(Int) to Int {
	var viewheight  = 1 << 0;
	var idealpitch  = 1 << 1;
	var punch1      = 1 << 2;
	var punch2      = 1 << 3;
	var punch3      = 1 << 4;
	var velocity1   = 1 << 5;
	var velocity2   = 1 << 6;
	var velocity3   = 1 << 7;
	var items       = 1 << 9;
	var onground    = 1 << 10;
	var inwater     = 1 << 11;
	var weaponframe = 1 << 12;
	var armor       = 1 << 13;
	var weapon      = 1 << 14;

	@:op(a+b) static function _(a:SU, b:SU):SU;
}

@:publicFields
class Protocol {
	static inline var version = 15;
	static inline var default_viewheight = 22;

	static var svc = {
		nop: 1,
		disconnect: 2,
		updatestat: 3,
		version: 4,
		setview: 5,
		sound: 6,
		time: 7,
		print: 8,
		stufftext: 9,
		setangle: 10,
		serverinfo: 11,
		lightstyle: 12,
		updatename: 13,
		updatefrags: 14,
		clientdata: 15,
		stopsound: 16,
		updatecolors: 17,
		particle: 18,
		damage: 19,
		spawnstatic: 20,
		spawnbaseline: 22,
		temp_entity: 23,
		setpause: 24,
		signonnum: 25,
		centerprint: 26,
		killedmonster: 27,
		foundsecret: 28,
		spawnstaticsound: 29,
		intermission: 30,
		finale: 31,
		cdtrack: 32,
		sellscreen: 33,
		cutscene: 34
	};

	static var clc = {
		nop: 1,
		disconnect: 2,
		move: 3,
		stringcmd: 4
	};
}
