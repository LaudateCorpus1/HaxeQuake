package quake;

import js.html.Audio;
import js.html.XMLHttpRequest;

@:expose("CDAudio")
@:publicFields
class CDAudio {
    static var initialized:Bool;
    static var enabled:Bool;
    static var playTrack:Int;
    static var cd:Audio;
    static var cdvolume:Float;
    static var known = [];

    static function Play(track:Int, looping:Bool):Void {
        if (!initialized || !enabled)
            return;
        track -= 2;
        if (CDAudio.playTrack == track) {
            if (CDAudio.cd != null) {
                CDAudio.cd.loop = looping;
                if ((looping) && (CDAudio.cd.paused))
                    CDAudio.cd.play();
            }
            return;
        }
        if (track < 0 || track >= CDAudio.known.length) {
            Console.DPrint('CDAudio.Play: Bad track number ' + (track + 2) + '.\n');
            return;
        }
        CDAudio.Stop();
        CDAudio.playTrack = track;
        CDAudio.cd = new Audio(CDAudio.known[track]);
        CDAudio.cd.loop = looping;
        CDAudio.cd.volume = CDAudio.cdvolume;
        CDAudio.cd.play();
    }

    static function Stop():Void {
        if (!initialized || !enabled)
            return;
        if (CDAudio.cd != null)
            CDAudio.cd.pause();
        CDAudio.playTrack = null;
        CDAudio.cd = null;
    }

    static function Pause():Void {
        if (!initialized || !enabled)
            return;
        if (CDAudio.cd != null)
            CDAudio.cd.pause();
    }

    static function Resume():Void {
        if (!initialized || !enabled)
            return;
        if (CDAudio.cd != null)
            CDAudio.cd.play();
    }

    static function CD_f():Void {
        if (!initialized || (Cmd.argv.length <= 1))
            return;
        var command = Cmd.argv[1].toLowerCase();
        switch (command) {
            case 'on':
                enabled = true;
            case 'off':
                CDAudio.Stop();
                enabled = false;
            case 'play':
                CDAudio.Play(Q.atoi(Cmd.argv[2]), false);
            case 'loop':
                CDAudio.Play(Q.atoi(Cmd.argv[2]), true);
            case 'stop':
                CDAudio.Stop();
            case 'pause':
                CDAudio.Pause();
            case 'resume':
                CDAudio.Resume();
            case 'info':
                Console.Print(CDAudio.known.length + ' tracks\n');
                if (CDAudio.cd != null) {
                    if (!CDAudio.cd.paused)
                        Console.Print('Currently ' + (CDAudio.cd.loop ? 'looping' : 'playing') + ' track ' + (CDAudio.playTrack + 2) + '\n');
                }
                Console.Print('Volume is ' + CDAudio.cdvolume + '\n');
            }
    }

    static function Update():Void {
        if (!initialized || !enabled)
            return;
        if (S.bgmvolume.value == CDAudio.cdvolume)
            return;
        if (S.bgmvolume.value < 0.0)
            Cvar.SetValue('bgmvolume', 0.0);
        else if (S.bgmvolume.value > 1.0)
            Cvar.SetValue('bgmvolume', 1.0);
        CDAudio.cdvolume = S.bgmvolume.value;
        if (CDAudio.cd != null)
            CDAudio.cd.volume = CDAudio.cdvolume;
    }

    static function Init():Void {
        Cmd.AddCommand('cd', CDAudio.CD_f);
        if (COM.CheckParm('-nocdaudio') != null)
            return;
        var xhr = new XMLHttpRequest();
        for (i in 1...100) {
            var track = '/media/quake' + (i <= 9 ? '0' : '') + i + '.ogg';
            var j = COM.searchpaths.length - 1;
            while (j >= 0) {
                xhr.open('HEAD', COM.searchpaths[j].filename + track, false);
                xhr.send();
                if (xhr.status >= 200 && xhr.status <= 299) {
                    CDAudio.known[i - 1] = COM.searchpaths[j].filename + track;
                    break;
                }
                j--;
            }
            if (j < 0)
                break;
        }
        if (CDAudio.known.length == 0)
            return;
        initialized = enabled = true;
        CDAudio.Update();
        Console.Print('CD Audio Initialized\n');
    }
}
