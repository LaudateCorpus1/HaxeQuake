package quake;

import js.html.ArrayBuffer;
import js.html.Audio;
import js.html.DataView;
import js.html.Uint8Array;

@:publicFields
class Sfx {
	var name:String;
	var cache:SfxCache;

	function new(n) {
		name = n;
	}
}

@:publicFields
private class SfxCache {
	var loopstart:Float;
	var length:Float;
	var size:Int;
	var data:Audio;

	function new() {}
}

@:publicFields
private class Channel {
	var entnum:Int;
	var entchannel:Int;
	var sfx:Sfx;
	var end:Float;
	var origin:Vec;
	var master_vol:Float;
	var leftvol:Float;
	var rightvol:Float;
	var dist_mult:Float;
	var pos:Float;
	var audio:Audio;

	function new(?s) {
		sfx = s;
		end = 0.0;
		master_vol = 0.0;
	}
}

@:expose("S")
@:publicFields
class S {
	static var started = false;
	static var channels:Array<Channel> = [];
	static var static_channels:Array<Channel> = [];
	static var ambient_channels:Array<Channel> = [];
	static var listener_origin:Vec = [0.0, 0.0, 0.0];
	static var listener_forward:Vec = [0.0, 0.0, 0.0];
	static var listener_right:Vec = [0.0, 0.0, 0.0];
	static var listener_up:Vec = [0.0, 0.0, 0.0];
	static var known_sfx:Array<Sfx> = [];

	static var nosound:Cvar;
	static var volume:Cvar;
	static var precache:Cvar;
	static var bgmvolume:Cvar;
	static var ambient_level:Cvar;
	static var ambient_fade:Cvar;

	static function Init():Void {
		Console.Print('\nSound Initialization\n');
		Cmd.AddCommand('play', S.Play);
		Cmd.AddCommand('playvol', S.PlayVol);
		Cmd.AddCommand('stopsound', S.StopAllSounds);
		Cmd.AddCommand('soundlist', S.SoundList);
		S.nosound = Cvar.RegisterVariable('nosound', (COM.CheckParm('-nosound') != null) ? '1' : '0');
		S.volume = Cvar.RegisterVariable('volume', '0.7', true);
		S.precache = Cvar.RegisterVariable('precache', '1');
		S.bgmvolume = Cvar.RegisterVariable('bgmvolume', '1', true);
		S.ambient_level = Cvar.RegisterVariable('ambient_level', '0.3');
		S.ambient_fade = Cvar.RegisterVariable('ambient_fade', '100');

		S.started = true;

		var ambient_sfx = ['water1', 'wind2'];
		for (i in 0...ambient_sfx.length) {
			var ch = new Channel(PrecacheSound('ambience/' + ambient_sfx[i] + '.wav'));
			S.ambient_channels[i] = ch;
			if (!LoadSound(ch.sfx))
				continue;
			if (ch.sfx.cache.loopstart == null) {
				Console.Print('Sound ambience/' + ch.sfx.name + '.wav not looped\n');
				continue;
			}
			ch.audio = cast ch.sfx.cache.data.cloneNode();
		}

		Console.sfx_talk = S.PrecacheSound('misc/talk.wav');
	}

	static function PrecacheSound(name:String):Sfx {
		if (S.nosound.value != 0)
			return null;
		var sfx;
		for (s in known_sfx) {
			if (s.name == name) {
				sfx = s;
				break;
			}
		}
		if (sfx == null) {
			sfx = new Sfx(name);
			S.known_sfx.push(sfx);
		}
		if (S.precache.value != 0)
			S.LoadSound(sfx);
		return sfx;
	}

	static function PickChannel(entnum:Int, entchannel:Int):Channel {
		var i, channel;

		if (entchannel != 0) {
			i = 0;
			while (i < S.channels.length) {
				channel = S.channels[i++];
				if (channel == null)
					continue;
				if ((channel.entnum == entnum) && ((channel.entchannel == entchannel) || (entchannel == -1))) {
					channel.sfx = null;
					if (channel.audio != null) {
						channel.audio.pause();
						channel.audio = null;
					}
					break;
				}
			}
		}

		if ((entchannel == 0) || (i == S.channels.length)) {
			i = 0;
			while (i < S.channels.length) {
				channel = S.channels[i++];
				if (channel == null)
					break;
				if (channel.sfx == null)
					break;
			}
		}

		if (i == S.channels.length) {
			channel = new Channel();
			S.channels.push(channel);
		}
		return channel;
	}

	static function Spatialize(ch:Channel):Void {
		if (ch.entnum == CL.state.viewentity) {
			ch.leftvol = ch.master_vol;
			ch.rightvol = ch.master_vol;
			return;
		}

		var source = [
			ch.origin[0] - S.listener_origin[0],
			ch.origin[1] - S.listener_origin[1],
			ch.origin[2] - S.listener_origin[2]
		];
		var dist = Math.sqrt(source[0] * source[0] + source[1] * source[1] + source[2] * source[2]);
		if (dist != 0.0) {
			source[0] /= dist;
			source[1] /= dist;
			source[2] /= dist;
		}
		dist *= ch.dist_mult;
		var dot = S.listener_right[0] * source[0]
			+ S.listener_right[1] * source[1]
			+ S.listener_right[2] * source[2];

		ch.rightvol = ch.master_vol * (1.0 - dist) * (1.0 + dot);
		if (ch.rightvol < 0.0)
			ch.rightvol = 0.0;
		ch.leftvol = ch.master_vol * (1.0 - dist) * (1.0 - dot);
		if (ch.leftvol < 0.0)
			ch.leftvol = 0.0;
	}

	static function StartSound(entnum:Int, entchannel:Int, sfx:Sfx, origin:Vec, vol:Float, attenuation:Float):Void {
		if ((S.nosound.value != 0) || (sfx == null))
			return;

		var target_chan = S.PickChannel(entnum, entchannel);
		target_chan.origin = [origin[0], origin[1], origin[2]];
		target_chan.dist_mult = attenuation * 0.001;
		target_chan.master_vol = vol;
		target_chan.entnum = entnum;
		target_chan.entchannel = entchannel;
		S.Spatialize(target_chan);
		if ((target_chan.leftvol == 0.0) && (target_chan.rightvol == 0.0))
			return;

		if (!S.LoadSound(sfx)) {
			target_chan.sfx = null;
			return;
		}

		target_chan.sfx = sfx;
		target_chan.pos = 0.0;
		target_chan.end = Host.realtime + sfx.cache.length;
		target_chan.audio = cast sfx.cache.data.cloneNode();
		var volume = (target_chan.leftvol + target_chan.rightvol) * 0.5;
		if (volume > 1.0)
			volume = 1.0;
		target_chan.audio.volume = volume * S.volume.value;
		target_chan.audio.play();
	}

	static function StopSound(entnum:Int, entchannel:Int):Void {
		if (S.nosound.value != 0)
			return;
		for (ch in S.channels) {
			if (ch == null)
				continue;
			if (ch.entnum == entnum && ch.entchannel == entchannel) {
				ch.end = 0.0;
				ch.sfx = null;
				if (ch.audio != null) {
					ch.audio.pause();
					ch.audio = null;
				}
				return;
			}
		}
	}

	static function StopAllSounds():Void {
		if (S.nosound.value != 0)
			return;

		for (ch in S.ambient_channels) {
			ch.master_vol = 0.0;
			if (ch.audio != null)
				ch.audio.pause();
		}

		for (ch in S.channels) {
			if (ch == null)
				continue;
			if (ch.audio != null)
				ch.audio.pause();
		}
		S.channels = [];

		for (ch in S.static_channels)
			ch.audio.pause();
		S.static_channels = [];
	}

	static function StaticSound(sfx:Sfx, origin:Vec, vol:Float, attenuation:Float):Void {
		if ((S.nosound.value != 0) || (sfx == null))
			return;
		if (S.LoadSound(sfx) != true)
			return;
		if (sfx.cache.loopstart == null) {
			Console.Print('Sound ' + sfx.name + ' not looped\n');
			return;
		}
		var ss = new Channel(sfx);
		ss.origin = [origin[0], origin[1], origin[2]];
		ss.master_vol = vol;
		ss.dist_mult = attenuation * 0.000015625;
		ss.end = Host.realtime + sfx.cache.length;
		S.static_channels.push(ss);
		ss.audio = cast sfx.cache.data.cloneNode();
		ss.audio.pause();
	}

	static function SoundList():Void {
		var total = 0;
		for (sfx in S.known_sfx) {
			var sc = sfx.cache;
			if (sc == null)
				continue;
			var size = Std.string(sc.size);
			total += sc.size;
			while (size.length <= 5)
				size = ' ' + size;
			if (sc.loopstart != null)
				size = 'L' + size;
			else
				size = ' ' + size;
			Console.Print(size + ' : ' + sfx.name + '\n');
		}
		Console.Print('Total resident: ' + total + '\n');
	}

	static inline function LocalSound(sound:Sfx):Void {
		StartSound(CL.state.viewentity, -1, sound, Vec.origin, 1.0, 1.0);
	}

	static function UpdateAmbientSounds():Void {
		if (CL.state.worldmodel == null)
			return;

		var l = Mod.PointInLeaf(S.listener_origin, CL.state.worldmodel);
		if ((l == null) || (S.ambient_level.value == 0)) {
			for (ch in S.ambient_channels) {
				ch.master_vol = 0.0;
				if (ch.audio != null) {
					if (ch.audio.paused != true)
						ch.audio.pause();
				}
			}
			return;
		}

		for (i in 0...S.ambient_channels.length) {
			var ch = S.ambient_channels[i];
			if (ch.audio == null)
				continue;
			var vol = S.ambient_level.value * l.ambient_level[i];
			if (vol < 8.0)
				vol = 0.0;
			vol /= 255.0;
			if (ch.master_vol < vol) {
				ch.master_vol += (Host.frametime * S.ambient_fade.value) / 255.0;
				if (ch.master_vol > vol)
					ch.master_vol = vol;
			}
			else if (ch.master_vol > vol) {
				ch.master_vol -= (Host.frametime * S.ambient_fade.value) / 255.0;
				if (ch.master_vol < vol)
					ch.master_vol = vol;
			}

			if (ch.master_vol == 0.0) {
				if (ch.audio.paused != true)
					ch.audio.pause();
				continue;
			}
			if (ch.master_vol > 1.0)
				ch.master_vol = 1.0;
			ch.audio.volume = ch.master_vol * S.volume.value;
			var sc = ch.sfx.cache;
			if (ch.audio.paused) {
				ch.audio.play();
				ch.end = Host.realtime + sc.length;
				continue;
			}
			if (Host.realtime >= ch.end) {
				try {
					ch.audio.currentTime = sc.loopstart;
				} catch (e:Dynamic) {
					ch.end = Host.realtime;
					continue;
				}
				ch.end = Host.realtime + sc.length - sc.loopstart;
			}
		}
	}

	static function UpdateDynamicSounds():Void {
		for (ch in S.channels) {
			if (ch == null)
				continue;
			if (ch.sfx == null)
				continue;
			if (Host.realtime >= ch.end) {
				var sc = ch.sfx.cache;
				if (sc.loopstart != null) {
					try {
						ch.audio.currentTime = sc.loopstart;
					} catch (e:Dynamic) {
						ch.end = Host.realtime;
						continue;
					}
					ch.end = Host.realtime + sc.length - sc.loopstart;
				} else {
					ch.sfx = null;
					ch.audio = null;
					continue;
				}
			}
			S.Spatialize(ch);
			var volume = (ch.leftvol + ch.rightvol) * 0.5;
			if (volume > 1.0)
				volume = 1.0;
			ch.audio.volume = volume * S.volume.value;
		}
	}

	static function UpdateStaticSounds():Void {
		for (ch in S.static_channels)
			Spatialize(ch);

		for (i in 0...S.static_channels.length) {
			var ch = S.static_channels[i];
			if (ch.leftvol == 0.0 && ch.rightvol == 0.0)
				continue;
			var sfx = ch.sfx;
			for (j in i + 1...S.static_channels.length) {
				var ch2 = S.static_channels[j];
				if (sfx == ch2.sfx) {
					ch.leftvol += ch2.leftvol;
					ch.rightvol += ch2.rightvol;
					ch2.leftvol = 0.0;
					ch2.rightvol = 0.0;
				}
			}
		}

		for (ch in S.static_channels) {
			var volume = (ch.leftvol + ch.rightvol) * 0.5;
			if (volume > 1.0)
				volume = 1.0;
			if (volume == 0.0) {
				if (ch.audio.paused != true)
					ch.audio.pause();
				continue;
			}
			ch.audio.volume = volume * S.volume.value;
			var sc = ch.sfx.cache;
			if (ch.audio.paused) {
				ch.audio.play();
				ch.end = Host.realtime + sc.length;
				continue;
			}
			if (Host.realtime >= ch.end) {
				try
				{
					ch.audio.currentTime = sc.loopstart;
				}
				catch (e:Dynamic) {
					ch.end = Host.realtime;
					continue;
				}
			}
		}
	}

	static function Update(origin:Vec, forward:Vec, right:Vec, up:Vec):Void {
		if (S.nosound.value != 0)
			return;

		S.listener_origin[0] = origin[0];
		S.listener_origin[1] = origin[1];
		S.listener_origin[2] = origin[2];
		S.listener_forward[0] = forward[0];
		S.listener_forward[1] = forward[1];
		S.listener_forward[2] = forward[2];
		S.listener_right[0] = right[0];
		S.listener_right[1] = right[1];
		S.listener_right[2] = right[2];
		S.listener_up[0] = up[0];
		S.listener_up[1] = up[1];
		S.listener_up[2] = up[2];

		if (S.volume.value < 0.0)
			Cvar.SetValue('volume', 0.0);
		else if (S.volume.value > 1.0)
			Cvar.SetValue('volume', 1.0);

		S.UpdateAmbientSounds();
		S.UpdateDynamicSounds();
		S.UpdateStaticSounds();
	}

	static function Play():Void {
		if (S.nosound.value != 0)
			return;
		for (i in 1...Cmd.argv.length) {
			var sfx = S.PrecacheSound(COM.DefaultExtension(Cmd.argv[i], '.wav'));
			if (sfx != null)
				S.StartSound(CL.state.viewentity, 0, sfx, S.listener_origin, 1.0, 1.0);
		}
	}

	static function PlayVol():Void {
		if (S.nosound.value != 0)
			return;
		var i = 1;
		while (i < Cmd.argv.length) {
			var sfx = S.PrecacheSound(COM.DefaultExtension(Cmd.argv[i], '.wav'));
			if (sfx != null)
				S.StartSound(CL.state.viewentity, 0, sfx, S.listener_origin, Q.atof(Cmd.argv[i + 1]), 1.0);
			i += 2;
		}
	}

	static function LoadSound(s:Sfx):Bool {
		if (S.nosound.value != 0)
			return false;
		if (s.cache != null)
			return true;

		var sc = new SfxCache();

		var data = COM.LoadFile('sound/' + s.name);
		if (data == null) {
			Console.Print('Couldn\'t load sound/' + s.name + '\n');
			return false;
		}

		var view = new DataView(data);
		if ((view.getUint32(0, true) != 0x46464952) || (view.getUint32(8, true) != 0x45564157)) {
			Console.Print('Missing RIFF/WAVE chunks\n');
			return false;
		}
		var p = 12, fmt, dataofs, datalen, cue, loopstart, samples;
		while (p < data.byteLength) {
			switch (view.getUint32(p, true)) {
			case 0x20746d66: // fmt
				if (view.getInt16(p + 8, true) != 1) {
					Console.Print('Microsoft PCM format only\n');
					return false;
				}
				fmt = {
					channels: view.getUint16(p + 10, true),
					samplesPerSec: view.getUint32(p + 12, true),
					avgBytesPerSec: view.getUint32(p + 16, true),
					blockAlign: view.getUint16(p + 20, true),
					bitsPerSample: view.getUint16(p + 22, true)
				};
			case 0x61746164: // data
				dataofs = p + 8;
				datalen = view.getUint32(p + 4, true);
			case 0x20657563: // cue
				cue = true;
				loopstart = view.getUint32(p + 32, true);
			case 0x5453494c: // LIST
				if (cue) {
					cue = false;
					if (view.getUint32(p + 28, true) == 0x6b72616d)
						samples = loopstart + view.getUint32(p + 24, true);
				}
			}
			p += view.getUint32(p + 4, true) + 8;
			if ((p & 1) != 0)
				++p;
		}

		if (fmt == null) {
			Console.Print('Missing fmt chunk\n');
			return false;
		}
		if (dataofs == null) {
			Console.Print('Missing data chunk\n');
			return false;
		}
		if (loopstart != null)
			sc.loopstart = loopstart * fmt.blockAlign / fmt.samplesPerSec;
		if (samples != null)
			sc.length = samples / fmt.samplesPerSec;
		else
			sc.length = datalen / fmt.avgBytesPerSec;

		sc.size = datalen + 44;
		if ((sc.size & 1) != 0)
			++sc.size;
		var out = new ArrayBuffer(sc.size);
		view = new DataView(out);
		view.setUint32(0, 0x46464952, true); // RIFF
		view.setUint32(4, cast sc.size - 8, true);
		view.setUint32(8, 0x45564157, true); // WAVE
		view.setUint32(12, 0x20746d66, true); // fmt
		view.setUint32(16, 16, true);
		view.setUint16(20, 1, true);
		view.setUint16(22, fmt.channels, true);
		view.setUint32(24, fmt.samplesPerSec, true);
		view.setUint32(28, fmt.avgBytesPerSec, true);
		view.setUint16(32, fmt.blockAlign, true);
		view.setUint16(34, fmt.bitsPerSample, true);
		view.setUint32(36, 0x61746164, true); // data
		view.setUint32(40, datalen, true);
		(new Uint8Array(out, 44, datalen)).set(new Uint8Array(data, dataofs, datalen));
		sc.data = new Audio('data:audio/wav;base64,' + Q.btoa(new Uint8Array(out)));
		s.cache = sc;
		return true;
	}
}
