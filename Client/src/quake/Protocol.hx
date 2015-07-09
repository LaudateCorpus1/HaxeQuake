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


@:publicFields
class Protocol {
	static var version = 15;

	static var u = {
		morebits: 1,
		origin1: 1 << 1,
		origin2: 1 << 2,
		origin3: 1 << 3,
		angle2: 1 << 4,
		nolerp: 1 << 5,
		frame: 1 << 6,
		signal: 1 << 7,

		angle1: 1 << 8,
		angle3: 1 << 9,
		model: 1 << 10,
		colormap: 1 << 11,
		skin: 1 << 12,
		effects: 1 << 13,
		longentity: 1 << 14
	};

	static var su = {
		viewheight: 1,
		idealpitch: 1 << 1,
		punch1: 1 << 2,
		punch2: 1 << 3,
		punch3: 1 << 4,
		velocity1: 1 << 5,
		velocity2: 1 << 6,
		velocity3: 1 << 7,
		items: 1 << 9,
		onground: 1 << 10,
		inwater: 1 << 11,
		weaponframe: 1 << 12,
		armor: 1 << 13,
		weapon: 1 << 14
	};

	static var default_viewheight = 22;

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
