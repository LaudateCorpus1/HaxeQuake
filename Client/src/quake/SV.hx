package quake;

import js.html.ArrayBuffer;
import js.html.Float32Array;
import js.html.Int32Array;
import js.html.Uint8Array;
import quake.CL.ClientCmd;
import quake.Host.HClient;
import quake.Mod;
import quake.R.REntityState;
import quake.Protocol;
import quake.PR.GlobalVarOfs;

@:publicFields
private class ServerStatic {
    var maxclients:Int;
    var maxclientslimit:Int;
    var clients:Array<HClient>;
    var serverflags:Int;
    var changelevel_issued:Bool;
    function new() {}
}

@:publicFields
private class ServerState {
    var num_edicts = 0;
    var datagram = new MSG(1024);
    var reliable_datagram = new MSG(1024);
    var signon = new MSG(8192);
    var sound_precache:Array<String>;
    var model_precache:Array<String>;
    var edicts:Array<Edict>;
    var loadgame:Bool;
    var worldmodel:MModel;
    var models:Array<MModel>;
    var time:Float;
    var active:Bool;
    var loading:Bool;
    var paused:Bool;
    var lastcheck:Int;
    var lastchecktime:Float;
    var modelname:String;
    var lightstyles:Array<String>;

    function new() {}
}

@:enum abstract MoveType(Int) to Int {
    var none = 0;
    var anglenoclip = 1;
    var angleclip = 2;
    var walk = 3;
    var step = 4;
    var fly = 5;
    var toss = 6;
    var push = 7;
    var noclip = 8;
    var flymissile = 9;
    var bounce = 10;
}

@:enum abstract EntFlag(Int) to Int {
    var fly = 1;
    var swim = 2;
    var conveyor = 4;
    var client = 8;
    var inwater = 16;
    var monster = 32;
    var godmode = 64;
    var notarget = 128;
    var item = 256;
    var onground = 512;
    var partialground = 1024;
    var waterjump = 2048;
    var jumpreleased = 4096;

    @:op(a+b) static function _(a:EntFlag, b:EntFlag):EntFlag;
    @:op(a|b) static function _(a:EntFlag, b:EntFlag):EntFlag;
    @:op(a&b) static function _(a:EntFlag, b:EntFlag):EntFlag;
    @:op(a^b) static function _(a:EntFlag, b:EntFlag):EntFlag;
    @:op(~a) static function _(a:EntFlag):EntFlag;
}

@:enum abstract DamageType(Int) to Int {
    var no = 0;
    var yes = 1;
    var aim = 2;
}

@:enum abstract SolidType(Int) to Int {
    var not = 0;
    var trigger = 1;
    var bbox = 2;
    var slidebox = 3;
    var bsp = 4;
}

@:enum abstract ClipType(Int) to Int {
    var normal = 0;
    var nomonsters = 1;
    var missile = 2;
}

@:publicFields
class SV {
    // main

    static var server = new ServerState();
    static var svs = new ServerStatic();

    static var maxvelocity:Cvar;
    static var gravity:Cvar;
    static var friction:Cvar;
    static var edgefriction:Cvar;
    static var stopspeed:Cvar;
    static var maxspeed:Cvar;
    static var accelerate:Cvar;
    static var idealpitchscale:Cvar;
    static var aim:Cvar;
    static var nostep:Cvar;

    static var nop:MSG;
    static var reconnect:MSG;

    static function Init() {
        SV.maxvelocity = Cvar.RegisterVariable('sv_maxvelocity', '2000');
        SV.gravity = Cvar.RegisterVariable('sv_gravity', '800', false, true);
        SV.friction = Cvar.RegisterVariable('sv_friction', '4', false, true);
        SV.edgefriction = Cvar.RegisterVariable('edgefriction', '2');
        SV.stopspeed = Cvar.RegisterVariable('sv_stopspeed', '100');
        SV.maxspeed = Cvar.RegisterVariable('sv_maxspeed', '320', false, true);
        SV.accelerate = Cvar.RegisterVariable('sv_accelerate', '10');
        SV.idealpitchscale = Cvar.RegisterVariable('sv_idealpitchscale', '0.8');
        SV.aim = Cvar.RegisterVariable('sv_aim', '0.93');
        SV.nostep = Cvar.RegisterVariable('sv_nostep', '0');

        SV.nop = new MSG(4, 1);
        (new Uint8Array(SV.nop.data))[0] = SVC.nop;
        SV.reconnect = new MSG(128);
        SV.reconnect.WriteByte(SVC.stufftext);
        SV.reconnect.WriteString('reconnect\n');

        SV.InitBoxHull();
    }

    static function StartParticle(org:Vec, dir:Vec, color:Int, count:Int):Void {
        var datagram = SV.server.datagram;
        if (datagram.cursize >= 1009)
            return;
        datagram.WriteByte(SVC.particle);
        datagram.WriteCoord(org[0]);
        datagram.WriteCoord(org[1]);
        datagram.WriteCoord(org[2]);
        for (i in 0...3) {
            var v = Std.int(dir[i] * 16.0);
            if (v > 127)
                v = 127;
            else if (v < -128)
                v = -128;
            datagram.WriteChar(v);
        }
        datagram.WriteByte(count);
        datagram.WriteByte(color);
    }

    static function StartSound(entity:Edict, channel:Int, sample:String, volume:Int, attenuation:Float):Void {
        if ((volume < 0) || (volume > 255))
            Sys.Error('SV.StartSound: volume = ' + volume);
        if ((attenuation < 0.0) || (attenuation > 4.0))
            Sys.Error('SV.StartSound: attenuation = ' + attenuation);
        if ((channel < 0) || (channel > 7))
            Sys.Error('SV.StartSound: channel = ' + channel);

        var datagram = SV.server.datagram;
        if (datagram.cursize >= 1009)
            return;

        var i = 1;
        while (i < SV.server.sound_precache.length) {
            if (sample == SV.server.sound_precache[i])
                break;
            i++;
        }
        if (i >= SV.server.sound_precache.length) {
            Console.Print('SV.StartSound: ' + sample + ' not precached\n');
            return;
        }

        var field_mask = 0;
        if (volume != 255)
            field_mask += 1;
        if (attenuation != 1.0)
            field_mask += 2;

        datagram.WriteByte(SVC.sound);
        datagram.WriteByte(field_mask);
        if ((field_mask & 1) != 0)
            datagram.WriteByte(volume);
        if ((field_mask & 2) != 0)
            datagram.WriteByte(Math.floor(attenuation * 64.0));
        datagram.WriteShort((entity.num << 3) + channel);
        datagram.WriteByte(i);
        datagram.WriteCoord(entity.v.origin + 0.5 *
            (entity.v.mins + entity.v.maxs));
        datagram.WriteCoord(entity.v.origin1 + 0.5 *
            (entity.v.mins1 + entity.v.maxs1));
        datagram.WriteCoord(entity.v.origin2 + 0.5 *
            (entity.v.mins2 + entity.v.maxs2));
    }

    static function SendServerinfo(client:HClient) {
        var message = client.message;
        message.WriteByte(SVC.print);
        message.WriteString(String.fromCharCode(2) + '\nVERSION 1.09 SERVER (' + PR.crc + ' CRC)');
        message.WriteByte(SVC.serverinfo);
        message.WriteLong(Protocol.version);
        message.WriteByte(SV.svs.maxclients);
        message.WriteByte(((Host.coop.value == 0) && (Host.deathmatch.value != 0)) ? 1 : 0);
        message.WriteString(PR.GetString(SV.server.edicts[0].v.message));
        for (i in 1...SV.server.model_precache.length)
            message.WriteString(SV.server.model_precache[i]);
        message.WriteByte(0);
        for (i in 1...SV.server.sound_precache.length)
            message.WriteString(SV.server.sound_precache[i]);
        message.WriteByte(0);
        message.WriteByte(SVC.cdtrack);
        message.WriteByte(Std.int(SV.server.edicts[0].v.sounds));
        message.WriteByte(Std.int(SV.server.edicts[0].v.sounds));
        message.WriteByte(SVC.setview);
        message.WriteShort(client.edict.num);
        message.WriteByte(SVC.signonnum);
        message.WriteByte(1);
        client.sendsignon = true;
        client.spawned = false;
    }

    static function ConnectClient(clientnum:Int):Void {
        var client = SV.svs.clients[clientnum];
        var spawn_parms;
        if (SV.server.loadgame) {
            spawn_parms = [];
            if (client.spawn_parms == null) {
                client.spawn_parms = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
            }
            for (i in 0...16)
                spawn_parms[i] = client.spawn_parms[i];
        }
        Console.DPrint('Client ' + client.netconnection.address + ' connected\n');
        client.active = true;
        client.dropasap = false;
        client.last_message = 0.0;
        client.cmd = new ClientCmd();
        client.wishdir = new Vec();
        client.message.cursize = 0;
        client.edict = SV.server.edicts[clientnum + 1];
        client.edict.v.netname = PR.netnames + (clientnum << 5);
        SV.SetClientName(client, 'unconnected');
        client.colors = 0;
        client.ping_times = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        client.num_pings = 0;
        if (!SV.server.loadgame) {
            client.spawn_parms = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        }
        client.old_frags = 0;
        if (SV.server.loadgame) {
            for (i in 0...16)
                client.spawn_parms[i] = spawn_parms[i];
        } else {
            PR.ExecuteProgram(PR.globals_int[GlobalVarOfs.SetNewParms]);
            for (i in 0...16)
                client.spawn_parms[i] = PR.globals_float[GlobalVarOfs.parms + i];
        }
        SV.SendServerinfo(client);
    }

    static var fatpvs = [];

    static function CheckForNewClients() {
        while (true) {
            var ret = NET.CheckNewConnections();
            if (ret == null)
                return;
            var i = 0;
            while (i < SV.svs.maxclients) {
                if (!SV.svs.clients[i].active)
                    break;
                i++;
            }
            if (i == SV.svs.maxclients)
                Sys.Error('SV.CheckForNewClients: no free clients');
            SV.svs.clients[i].netconnection = ret;
            SV.ConnectClient(i);
            ++NET.activeconnections;
        }
    }

    static function AddToFatPVS(org:Vec, node:MNode):Void {
        while (true) {
            if (node.contents < 0) {
                if (node.contents != ModContents.solid) {
                    var pvs = Mod.LeafPVS(cast node, SV.server.worldmodel);
                    for (i in 0...SV.fatbytes)
                        SV.fatpvs[i] |= pvs[i];
                }
                return;
            }
            var normal = node.plane.normal;
            var d = org[0] * normal[0] + org[1] * normal[1] + org[2] * normal[2] - node.plane.dist;
            if (d > 8.0)
                node = node.children[0];
            else {
                if (d >= -8.0)
                    SV.AddToFatPVS(org, node.children[0]);
                node = node.children[1];
            }
        }
    }

    static var fatbytes:Int;

    static function FatPVS(org:Vec):Void {
        SV.fatbytes = (SV.server.worldmodel.leafs.length + 31) >> 3;
        for (i in 0...SV.fatbytes)
            SV.fatpvs[i] = 0;
        SV.AddToFatPVS(org, SV.server.worldmodel.nodes[0]);
    }

    static function WriteEntitiesToClient(clent:Edict, msg:MSG):Void {
        SV.FatPVS(Vec.of(
            clent.v.origin + clent.v.view_ofs,
            clent.v.origin1 + clent.v.view_ofs1,
            clent.v.origin2 + clent.v.view_ofs2
        ));
        var pvs = SV.fatpvs;
        for (e in 1...SV.server.num_edicts) {
            var ent = SV.server.edicts[e];
            if (ent != clent) {
                if (ent.v.modelindex == 0.0 || PR.strings[ent.v.model] == 0)
                    continue;
                var i = 0;
                while (i < ent.leafnums.length) {
                    if ((pvs[ent.leafnums[i] >> 3] & (1 << (ent.leafnums[i] & 7))) != 0)
                        break;
                    i++;
                }
                if (i == ent.leafnums.length)
                    continue;
            }
            if ((msg.data.byteLength - msg.cursize) < 16) {
                Console.Print('packet overflow\n');
                return;
            }

            var bits = 0;
            for (i in 0...3) {
                var miss = ent._v_float[EdictVarOfs.origin + i] - ent.baseline.origin[i];
                if ((miss < -0.1) || (miss > 0.1))
                    bits += U.origin1 << i;
            }
            if (ent.v.angles != ent.baseline.angles[0])
                bits += U.angle1;
            if (ent.v.angles1 != ent.baseline.angles[1])
                bits += U.angle2;
            if (ent.v.angles2 != ent.baseline.angles[2])
                bits += U.angle3;
            if (ent.v.movetype == MoveType.step)
                bits += U.nolerp;
            if (ent.baseline.colormap != ent.v.colormap)
                bits += U.colormap;
            if (ent.baseline.skin != ent.v.skin)
                bits += U.skin;
            if (ent.baseline.frame != ent.v.frame)
                bits += U.frame;
            if (ent.baseline.effects != ent.v.effects)
                bits += U.effects;
            if (ent.baseline.modelindex != ent.v.modelindex)
                bits += U.model;
            if (e >= 256)
                bits += U.longentity;
            if (bits >= 256)
                bits += U.morebits;

            msg.WriteByte(bits + U.signal);
            if ((bits & U.morebits) != 0)
                msg.WriteByte(bits >> 8);
            if ((bits & U.longentity) != 0)
                msg.WriteShort(e);
            else
                msg.WriteByte(e);
            if ((bits & U.model) != 0)
                msg.WriteByte(Std.int(ent.v.modelindex));
            if ((bits & U.frame) != 0)
                msg.WriteByte(Std.int(ent.v.frame));
            if ((bits & U.colormap) != 0)
                msg.WriteByte(Std.int(ent.v.colormap));
            if ((bits & U.skin) != 0)
                msg.WriteByte(Std.int(ent.v.skin));
            if ((bits & U.effects) != 0)
                msg.WriteByte(Std.int(ent.v.effects));
            if ((bits & U.origin1) != 0)
                msg.WriteCoord(Std.int(ent.v.origin));
            if ((bits & U.angle1) != 0)
                msg.WriteAngle(Std.int(ent.v.angles));
            if ((bits & U.origin2) != 0)
                msg.WriteCoord(Std.int(ent.v.origin1));
            if ((bits & U.angle2) != 0)
                msg.WriteAngle(Std.int(ent.v.angles1));
            if ((bits & U.origin3) != 0)
                msg.WriteCoord(Std.int(ent.v.origin2));
            if ((bits & U.angle3) != 0)
                msg.WriteAngle(Std.int(ent.v.angles2));
        }
    }

    static function WriteClientdataToMessage(ent:Edict, msg:MSG):Void {
        if ((ent.v.dmg_take != 0.0) || (ent.v.dmg_save != 0.0)) {
            var other = SV.server.edicts[ent.v.dmg_inflictor];
            msg.WriteByte(SVC.damage);
            msg.WriteByte(Std.int(ent.v.dmg_save));
            msg.WriteByte(Std.int(ent.v.dmg_take));
            msg.WriteCoord(other.v.origin + 0.5 * (other.v.mins + other.v.maxs));
            msg.WriteCoord(other.v.origin1 + 0.5 * (other.v.mins1 + other.v.maxs1));
            msg.WriteCoord(other.v.origin2 + 0.5 * (other.v.mins2 + other.v.maxs2));
            ent.v.dmg_take = 0.0;
            ent.v.dmg_save = 0.0;
        }

        SV.SetIdealPitch();

        if (ent.v.fixangle != 0.0) {
            msg.WriteByte(SVC.setangle);
            msg.WriteAngle(ent.v.angles);
            msg.WriteAngle(ent.v.angles1);
            msg.WriteAngle(ent.v.angles2);
            ent.v.fixangle = 0.0;
        };

        var bits = SU.items + SU.weapon;
        if (ent.v.view_ofs2 != Protocol.default_viewheight)
            bits += SU.viewheight;
        if (ent.v.idealpitch != 0.0)
            bits += SU.idealpitch;

        var val = EdictVarOfs.items2, items;
        if (val != null) {
            if (ent._v_float[val] != 0.0)
                items = Std.int(ent.items) + ((Std.int(ent._v_float[val]) << 23) >>> 0);
            else
                items = Std.int(ent.items) + ((Std.int(PR.globals_float[GlobalVarOfs.serverflags]) << 28) >>> 0);
        } else
            items = Std.int(ent.items) + ((Std.int(PR.globals_float[GlobalVarOfs.serverflags]) << 28) >>> 0);

        if ((ent.flags & EntFlag.onground) != 0)
            bits += SU.onground;
        if (ent.v.waterlevel >= 2.0)
            bits += SU.inwater;

        if (ent.v.punchangle != 0.0)
            bits += SU.punch1;
        if (ent.v.velocity != 0.0)
            bits += SU.velocity1;
        if (ent.v.punchangle1 != 0.0)
            bits += SU.punch2;
        if (ent.v.velocity1 != 0.0)
            bits += SU.velocity2;
        if (ent.v.punchangle2 != 0.0)
            bits += SU.punch3;
        if (ent.v.velocity2 != 0.0)
            bits += SU.velocity3;

        if (ent.v.weaponframe != 0.0)
            bits += SU.weaponframe;
        if (ent.v.armorvalue != 0.0)
            bits += SU.armor;

        msg.WriteByte(SVC.clientdata);
        msg.WriteShort(bits);
        if ((bits & SU.viewheight) != 0)
            msg.WriteChar(Std.int(ent.v.view_ofs2));
        if ((bits & SU.idealpitch) != 0)
            msg.WriteChar(Std.int(ent.v.idealpitch));

        if ((bits & SU.punch1) != 0)
            msg.WriteChar(Std.int(ent.v.punchangle));
        if ((bits & SU.velocity1) != 0)
            msg.WriteChar(Std.int(ent.v.velocity * 0.0625));
        if ((bits & SU.punch2) != 0)
            msg.WriteChar(Std.int(ent.v.punchangle1));
        if ((bits & SU.velocity2) != 0)
            msg.WriteChar(Std.int(ent.v.velocity1 * 0.0625));
        if ((bits & SU.punch3) != 0)
            msg.WriteChar(Std.int(ent.v.punchangle2));
        if ((bits & SU.velocity3) != 0)
            msg.WriteChar(Std.int(ent.v.velocity2 * 0.0625));

        msg.WriteLong(items);
        if ((bits & SU.weaponframe) != 0)
            msg.WriteByte(Std.int(ent.v.weaponframe));
        if ((bits & SU.armor) != 0)
            msg.WriteByte(Std.int(ent.v.armorvalue));
        msg.WriteByte(SV.ModelIndex(PR.GetString(ent.v.weaponmodel)));
        msg.WriteShort(Std.int(ent.v.health));
        msg.WriteByte(Std.int(ent.v.currentammo));
        msg.WriteByte(Std.int(ent.v.ammo_shells));
        msg.WriteByte(Std.int(ent.v.ammo_nails));
        msg.WriteByte(Std.int(ent.v.ammo_rockets));
        msg.WriteByte(Std.int(ent.v.ammo_cells));
        if (COM.standard_quake)
            msg.WriteByte(Std.int(ent.v.weapon));
        else {
            var weapon = Std.int(ent.v.weapon);
            for (i in 0...32) {
                if ((weapon & (1 << i)) != 0) {
                    msg.WriteByte(i);
                    break;
                }
            }
        }
    }

    static var clientdatagram = new MSG(1024);
    static function SendClientDatagram():Bool {
        var client = Host.client;
        var msg = SV.clientdatagram;
        msg.cursize = 0;
        msg.WriteByte(SVC.time);
        msg.WriteFloat(SV.server.time);
        SV.WriteClientdataToMessage(client.edict, msg);
        SV.WriteEntitiesToClient(client.edict, msg);
        if ((msg.cursize + SV.server.datagram.cursize) < msg.data.byteLength)
            msg.Write(new Uint8Array(SV.server.datagram.data), SV.server.datagram.cursize);
        if (NET.SendUnreliableMessage(client.netconnection, msg) == -1) {
            Host.DropClient(true);
            return false;
        }
        return true;
    }

    static function UpdateToReliableMessages() {

        for (i in 0...SV.svs.maxclients) {
            Host.client = SV.svs.clients[i];
            Host.client.edict.v.frags = Std.int(Host.client.edict.v.frags) >> 0;
            var frags = Std.int(Host.client.edict.v.frags);
            if (Host.client.old_frags == frags)
                continue;
            for (j in 0...SV.svs.maxclients) {
                var client = SV.svs.clients[j];
                if (!client.active)
                    continue;
                client.message.WriteByte(SVC.updatefrags);
                client.message.WriteByte(i);
                client.message.WriteShort(frags);
            }
            Host.client.old_frags = frags;
        }

        for (i in 0...SV.svs.maxclients) {
            var client = SV.svs.clients[i];
            if (client.active)
                client.message.Write(new Uint8Array(SV.server.reliable_datagram.data), SV.server.reliable_datagram.cursize);
        }

        SV.server.reliable_datagram.cursize = 0;
    }

    static function SendClientMessages():Void {
        SV.UpdateToReliableMessages();
        for (i in 0...SV.svs.maxclients) {
            var client = Host.client = SV.svs.clients[i];
            if (!client.active)
                continue;
            if (client.spawned) {
                if (!SV.SendClientDatagram())
                    continue;
            } else if (!client.sendsignon) {
                if ((Host.realtime - client.last_message) > 5.0) {
                    if (NET.SendUnreliableMessage(client.netconnection, SV.nop) == -1)
                        Host.DropClient(true);
                    client.last_message = Host.realtime;
                }
                continue;
            }
            if (client.message.overflowed) {
                Host.DropClient(true);
                client.message.overflowed = false;
                continue;
            }
            if (client.dropasap) {
                if (NET.CanSendMessage(client.netconnection))
                    Host.DropClient(false);
            } else if (client.message.cursize != 0) {
                if (!NET.CanSendMessage(client.netconnection))
                    continue;
                if (NET.SendMessage(client.netconnection, client.message) == -1)
                    Host.DropClient(true);
                client.message.cursize = 0;
                client.last_message = Host.realtime;
                client.sendsignon = false;
            }
        }

        for (i in 1...SV.server.num_edicts)
            SV.server.edicts[i].v.effects = Std.int(SV.server.edicts[i].v.effects) & (~EntEffect.muzzleflash >>> 0);
    }

    static function ModelIndex(name:String):Int {
        if (name == null)
            return 0;
        if (name.length == 0)
            return 0;
        for (i in 0...SV.server.model_precache.length) {
            if (SV.server.model_precache[i] == name)
                return i;
        }
        Sys.Error('SV.ModelIndex: model ' + name + ' not precached');
        return null;
    }

    static function CreateBaseline():Void {
        var player = SV.ModelIndex('progs/player.mdl');
        var signon = SV.server.signon;
        for (i in 0...SV.server.num_edicts) {
            var svent = SV.server.edicts[i];
            if (svent.free)
                continue;
            if ((i > SV.svs.maxclients) && (svent.v.modelindex == 0))
                continue;
            var baseline = svent.baseline;
            baseline.origin = ED.Vector(svent, EdictVarOfs.origin);
            baseline.angles = ED.Vector(svent, EdictVarOfs.angles);
            baseline.frame = Std.int(svent.v.frame);
            baseline.skin = Std.int(svent.v.skin);
            if ((i > 0) && (i <= SV.svs.maxclients)) {
                baseline.colormap = i;
                baseline.modelindex = player;
            } else {
                baseline.colormap = 0;
                baseline.modelindex = SV.ModelIndex(PR.GetString(svent.v.model));
            }
            signon.WriteByte(SVC.spawnbaseline);
            signon.WriteShort(i);
            signon.WriteByte(baseline.modelindex);
            signon.WriteByte(baseline.frame);
            signon.WriteByte(baseline.colormap);
            signon.WriteByte(baseline.skin);
            signon.WriteCoord(baseline.origin[0]);
            signon.WriteAngle(baseline.angles[0]);
            signon.WriteCoord(baseline.origin[1]);
            signon.WriteAngle(baseline.angles[1]);
            signon.WriteCoord(baseline.origin[2]);
            signon.WriteAngle(baseline.angles[2]);
        }
    }

    static function SaveSpawnparms():Void {
        SV.svs.serverflags = Std.int(PR.globals_float[GlobalVarOfs.serverflags]);
        for (i in 0...SV.svs.maxclients) {
            Host.client = SV.svs.clients[i];
            if (!Host.client.active)
                continue;
            PR.globals_int[GlobalVarOfs.self] = Host.client.edict.num;
            PR.ExecuteProgram(PR.globals_int[GlobalVarOfs.SetChangeParms]);
            for (j in 0...16)
                Host.client.spawn_parms[j] = PR.globals_float[GlobalVarOfs.parms + j];
        }
    }

    static function SpawnServer(server) {
        if (NET.hostname.string.length == 0)
            NET.hostname.set('UNNAMED');

        SCR.centertime_off = 0.0;

        Console.DPrint('SpawnServer: ' + server + '\n');
        SV.svs.changelevel_issued = false;

        if (SV.server.active) {
            NET.SendToAll(SV.reconnect);
            Cmd.ExecuteString('reconnect\n');
        }

        if (Host.coop.value != 0)
            Host.deathmatch.setValue(0);
        Host.current_skill = Math.floor(Host.skill.value + 0.5);
        if (Host.current_skill < 0)
            Host.current_skill = 0;
        else if (Host.current_skill > 3)
            Host.current_skill = 3;
        Host.skill.setValue(Host.current_skill);

        Console.DPrint('Clearing memory\n');
        Mod.ClearAll();

        PR.LoadProgs();

        SV.server.edicts = [];
        for (i in 0...Def.max_edicts)
            SV.server.edicts.push(new Edict(i));

        SV.server.datagram.cursize = 0;
        SV.server.reliable_datagram.cursize = 0;
        SV.server.signon.cursize = 0;
        SV.server.num_edicts = SV.svs.maxclients + 1;
        for (i in 0...SV.svs.maxclients)
            SV.svs.clients[i].edict = SV.server.edicts[i + 1];
        SV.server.loading = true;
        SV.server.paused = false;
        SV.server.loadgame = false;
        SV.server.time = 1.0;
        SV.server.lastcheck = 0;
        SV.server.lastchecktime = 0.0;
        SV.server.modelname = 'maps/' + server + '.bsp';
        SV.server.worldmodel = Mod.ForName(SV.server.modelname, false);
        if (SV.server.worldmodel == null) {
            Console.Print('Couldn\'t spawn server ' + SV.server.modelname + '\n');
            SV.server.active = false;
            return;
        }
        SV.server.models = [];
        SV.server.models[1] = SV.server.worldmodel;

        SV.areanodes = [];
        SV.CreateAreaNode(0, SV.server.worldmodel.mins, SV.server.worldmodel.maxs);

        SV.server.sound_precache = [''];
        SV.server.model_precache = ['', SV.server.modelname];
        for (i in 1...SV.server.worldmodel.submodels.length + 1) {
            SV.server.model_precache[i + 1] = '*' + i;
            SV.server.models[i + 1] = Mod.ForName('*' + i, false);
        }

        SV.server.lightstyles = [];
        for (i in 0...64)
            SV.server.lightstyles[i] = '';

        var ent = SV.server.edicts[0];
        ent.v.model = PR.NewString(SV.server.modelname, 64);
        ent.v.modelindex = 1.0;
        ent.v.solid = SolidType.bsp;
        ent.v.movetype = MoveType.push;

        if (Host.coop.value != 0)
            PR.globals_float[GlobalVarOfs.coop] = Host.coop.value;
        else
            PR.globals_float[GlobalVarOfs.deathmatch] = Host.deathmatch.value;

        PR.globals_int[GlobalVarOfs.mapname] = PR.NewString(server, 64);
        PR.globals_float[GlobalVarOfs.serverflags] = SV.svs.serverflags;
        ED.LoadFromFile(SV.server.worldmodel.entities);
        SV.server.active = true;
        SV.server.loading = false;
        Host.frametime = 0.1;
        SV.Physics();
        SV.Physics();
        SV.CreateBaseline();
        for (i in 0...SV.svs.maxclients) {
            Host.client = SV.svs.clients[i];
            if (!Host.client.active)
                continue;
            Host.client.edict.v.netname = PR.netnames + (i << 5);
            SV.SendServerinfo(Host.client);
        }
        Console.DPrint('Server spawned.\n');
    }

    static inline function GetClientName(client:HClient):String {
        return PR.GetString(PR.netnames + (client.num << 5));
    }

    static function SetClientName(client:HClient, name:String):Void {
        var ofs = PR.netnames + (client.num << 5);
        var i = 0;
        while (i < name.length) {
            PR.strings[ofs + i] = name.charCodeAt(i);
            i++;
        }
        PR.strings[ofs + i] = 0;
    }

    // move

    static function CheckBottom(ent:Edict):Bool {
        var mins = [
            ent.v.origin + ent.v.mins,
            ent.v.origin1 + ent.v.mins1,
            ent.v.origin2 + ent.v.mins2
        ];
        var maxs = [
            ent.v.origin + ent.v.maxs,
            ent.v.origin1 + ent.v.maxs1,
            ent.v.origin2 + ent.v.maxs2
        ];
        while (true) {
            if (SV.PointContents(Vec.of(mins[0], mins[1], mins[2] - 1.0)) != ModContents.solid)
                break;
            if (SV.PointContents(Vec.of(mins[0], maxs[1], mins[2] - 1.0)) != ModContents.solid)
                break;
            if (SV.PointContents(Vec.of(maxs[0], mins[1], mins[2] - 1.0)) != ModContents.solid)
                break;
            if (SV.PointContents(Vec.of(maxs[0], maxs[1], mins[2] - 1.0)) != ModContents.solid)
                break;
            return true;
        }
        var start = Vec.of((mins[0] + maxs[0]) * 0.5, (mins[1] + maxs[1]) * 0.5, mins[2]);
        var stop = Vec.of(start[0], start[1], start[2] - 36.0);
        var trace = SV.Move(start, Vec.origin, Vec.origin, stop, 1, ent);
        if (trace.fraction == 1.0)
            return false;
        var mid, bottom;
        mid = bottom = trace.endpos[2];
        for (x in 0...2) {
            for (y in 0...2) {
                start[0] = stop[0] = (x != 0) ? maxs[0] : mins[0];
                start[1] = stop[1] = (y != 0) ? maxs[1] : mins[1];
                trace = SV.Move(start, Vec.origin, Vec.origin, stop, 1, ent);
                if ((trace.fraction != 1.0) && (trace.endpos[2] > bottom))
                    bottom = trace.endpos[2];
                if ((trace.fraction == 1.0) || ((mid - trace.endpos[2]) > 18.0))
                    return false;
            }
        }
        return true;
    }

    static function movestep(ent:Edict, move:Vec, relink:Bool):Bool {
        var oldorg = ED.Vector(ent, EdictVarOfs.origin);
        var neworg = new Vec();
        var mins = ED.Vector(ent, EdictVarOfs.mins), maxs = ED.Vector(ent, EdictVarOfs.maxs);
        var trace;
        if ((ent.flags & (EntFlag.swim + EntFlag.fly)) != 0) {
            var enemy = ent.v.enemy;
            for (i in 0...2) {
                neworg[0] = ent.v.origin + move[0];
                neworg[1] = ent.v.origin1 + move[1];
                neworg[2] = ent.v.origin2;
                if ((i == 0) && (enemy != 0)) {
                    var dz = ent.v.origin2 - SV.server.edicts[enemy].v.origin2;
                    if (dz > 40.0)
                        neworg[2] -= 8.0;
                    else if (dz < 30.0)
                        neworg[2] += 8.0;
                }
                trace = SV.Move(ED.Vector(ent, EdictVarOfs.origin), mins, maxs, neworg, 0, ent);
                if (trace.fraction == 1.0) {
                    if (((ent.flags & EntFlag.swim) != 0) && (SV.PointContents(trace.endpos) == ModContents.empty))
                        return false;
                    ent.v.origin = trace.endpos[0];
                    ent.v.origin1 = trace.endpos[1];
                    ent.v.origin2 = trace.endpos[2];
                    if (relink)
                        SV.LinkEdict(ent, true);
                    return true;
                }
                if (enemy == 0)
                    return false;
            }
            return false;
        }
        neworg[0] = ent.v.origin + move[0];
        neworg[1] = ent.v.origin1 + move[1];
        neworg[2] = ent.v.origin2 + 18.0;
        var end = Vec.of(neworg[0], neworg[1], neworg[2] - 36.0);
        trace = SV.Move(neworg, mins, maxs, end, 0, ent);
        if (trace.allsolid)
            return false;
        if (trace.startsolid) {
            neworg[2] -= 18.0;
            trace = SV.Move(neworg, mins, maxs, end, 0, ent);
            if ((trace.allsolid) || (trace.startsolid))
                return false;
        }
        if (trace.fraction == 1.0) {
            if ((ent.flags & EntFlag.partialground) == 0)
                return false;
            ent.v.origin += move[0];
            ent.v.origin1 += move[1];
            if (relink)
                SV.LinkEdict(ent, true);
            ent.flags = ent.flags & ~EntFlag.onground;
            return true;
        }
        ent.v.origin = trace.endpos[0];
        ent.v.origin1 = trace.endpos[1];
        ent.v.origin2 = trace.endpos[2];
        if (!SV.CheckBottom(ent)) {
            if ((ent.flags & EntFlag.partialground) != 0) {
                if (relink)
                    SV.LinkEdict(ent, true);
                return true;
            }
            ent.v.origin = oldorg[0];
            ent.v.origin1 = oldorg[1];
            ent.v.origin2 = oldorg[2];
            return false;
        }
        ent.flags = ent.flags & ~EntFlag.partialground;
        ent.v.groundentity = trace.ent.num;
        if (relink)
            SV.LinkEdict(ent, true);
        return true;
    }

    static function StepDirection(ent:Edict, yaw:Float, dist:Float):Bool {
        ent.v.ideal_yaw = yaw;
        PF.changeyaw();
        yaw *= Math.PI / 180.0;
        var oldorigin = ED.Vector(ent, EdictVarOfs.origin);
        if (SV.movestep(ent, Vec.of(Math.cos(yaw) * dist, Math.sin(yaw) * dist, 0), false)) {
            var delta = ent.v.angles1 - ent.v.ideal_yaw;
            if ((delta > 45.0) && (delta < 315.0))
                ED.SetVector(ent, EdictVarOfs.origin, oldorigin);
            SV.LinkEdict(ent, true);
            return true;
        }
        SV.LinkEdict(ent, true);
        return false;
    }

    static function NewChaseDir(actor:Edict, enemy:Edict, dist:Float):Void {
        var olddir = Vec.Anglemod(Std.int(actor.v.ideal_yaw / 45.0) * 45.0);
        var turnaround = Vec.Anglemod(olddir - 180.0);
        var deltax = enemy.v.origin - actor.v.origin;
        var deltay = enemy.v.origin1 - actor.v.origin1;
        var dx, dy;
        if (deltax > 10.0)
            dx = 0.0;
        else if (deltax < -10.0)
            dx = 180.0;
        else
            dx = -1;
        if (deltay < -10.0)
            dy = 270.0;
        else if (deltay > 10.0)
            dy = 90.0;
        else
            dy = -1;
        var tdir;
        if ((dx != -1) && (dy != -1)) {
            if (dx == 0.0)
                tdir = (dy == 90.0) ? 45.0 : 315.0;
            else
                tdir = (dy == 90.0) ? 135.0 : 215.0;
            if ((tdir != turnaround) && (SV.StepDirection(actor, tdir, dist)))
                return;
        }
        if ((Math.random() >= 0.25) || (Math.abs(deltay) > Math.abs(deltax))) {
            tdir = dx;
            dx = dy;
            dy = tdir;
        }
        if ((dx != -1) && (dx != turnaround) && (SV.StepDirection(actor, dx, dist)))
            return;
        if ((dy != -1) && (dy != turnaround) && (SV.StepDirection(actor, dy, dist)))
            return;
        if ((olddir != -1) && (SV.StepDirection(actor, olddir, dist)))
            return;
        if (Math.random() >= 0.5) {
            tdir = 0.0;
            while (tdir <= 315.0) {
                if (tdir != turnaround && SV.StepDirection(actor, tdir, dist))
                    return;
                tdir += 45.0;
            }
        } else {
            tdir = 315.0;
            while (tdir >= 0.0) {
                if (tdir != turnaround && SV.StepDirection(actor, tdir, dist))
                    return;
                tdir -= 45.0;
            }
        }
        if (turnaround != -1 && SV.StepDirection(actor, turnaround, dist))
            return;
        actor.v.ideal_yaw = olddir;
        if (!SV.CheckBottom(actor))
            actor.flags = actor.flags | EntFlag.partialground;
    }

    static function CloseEnough(ent:Edict, goal:Edict, dist:Float):Bool {
        for (i in 0...3) {
            if (goal._v_float[EdictVarOfs.absmin + i] > (ent._v_float[EdictVarOfs.absmax + i] + dist))
                return false;
            if (goal._v_float[EdictVarOfs.absmax + i] < (ent._v_float[EdictVarOfs.absmin + i] - dist))
                return false;
        }
        return true;
    }

    // phys

    static function CheckAllEnts() {
        for (e in 1...SV.server.num_edicts) {
            var check = SV.server.edicts[e];
            if (check.free)
                continue;
            switch (check.v.movetype) {
                case MoveType.push | MoveType.none | MoveType.noclip:
                    continue;
            }
            if (SV.TestEntityPosition(check))
                Console.Print('entity in invalid position\n');
        }
    }

    static function CheckVelocity(ent:Edict) {
        for (i in 0...3) {
            var velocity = ent._v_float[EdictVarOfs.velocity + i];
            if (Math.isNaN(velocity)) {
                Console.Print('Got a NaN velocity on ' + PR.GetString(ent.v.classname) + '\n');
                velocity = 0.0;
            }
            if (Math.isNaN(ent._v_float[EdictVarOfs.origin + i])) {
                Console.Print('Got a NaN origin on ' + PR.GetString(ent.v.classname) + '\n');
                ent._v_float[EdictVarOfs.origin + i] = 0.0;
            }
            if (velocity > SV.maxvelocity.value)
                velocity = SV.maxvelocity.value;
            else if (velocity < -SV.maxvelocity.value)
                velocity = -SV.maxvelocity.value;
            ent._v_float[EdictVarOfs.velocity + i] = velocity;
        }
    }

    static function RunThink(ent:Edict) {
        var thinktime = ent.v.nextthink;
        if ((thinktime <= 0.0) || (thinktime > (SV.server.time + Host.frametime)))
            return true;
        if (thinktime < SV.server.time)
            thinktime = SV.server.time;
        ent.v.nextthink = 0.0;
        PR.globals_float[GlobalVarOfs.time] = thinktime;
        PR.globals_int[GlobalVarOfs.self] = ent.num;
        PR.globals_int[GlobalVarOfs.other] = 0;
        PR.ExecuteProgram(ent.v.think);
        return !ent.free;
    }

    static function Impact(e1:Edict, e2:Edict):Void {
        var old_self = PR.globals_int[GlobalVarOfs.self];
        var old_other = PR.globals_int[GlobalVarOfs.other];
        PR.globals_float[GlobalVarOfs.time] = SV.server.time;

        if ((e1.v.touch != 0) && (e1.v.solid != SolidType.not)) {
            PR.globals_int[GlobalVarOfs.self] = e1.num;
            PR.globals_int[GlobalVarOfs.other] = e2.num;
            PR.ExecuteProgram(e1.v.touch);
        }
        if ((e2.v.touch != 0) && (e2.v.solid != SolidType.not)) {
            PR.globals_int[GlobalVarOfs.self] = e2.num;
            PR.globals_int[GlobalVarOfs.other] = e1.num;
            PR.ExecuteProgram(e2.v.touch);
        }

        PR.globals_int[GlobalVarOfs.self] = old_self;
        PR.globals_int[GlobalVarOfs.other] = old_other;
    }

    static function ClipVelocity(vec:Vec, normal:Vec, out:Vec, overbounce:Float):Void {
        var backoff = (vec[0] * normal[0] + vec[1] * normal[1] + vec[2] * normal[2]) * overbounce;

        out[0] = vec[0] - normal[0] * backoff;
        if ((out[0] > -0.1) && (out[0] < 0.1))
            out[0] = 0.0;
        out[1] = vec[1] - normal[1] * backoff;
        if ((out[1] > -0.1) && (out[1] < 0.1))
            out[1] = 0.0;
        out[2] = vec[2] - normal[2] * backoff;
        if ((out[2] > -0.1) && (out[2] < 0.1))
            out[2] = 0.0;
    }

    static var steptrace:MTrace;

    static function FlyMove(ent:Edict, time:Float):Int {
        var numplanes = 0;
        var dir, d;
        var planes = new Array<Vec>(), plane;
        var primal_velocity = ED.Vector(ent, EdictVarOfs.velocity);
        var original_velocity = ED.Vector(ent, EdictVarOfs.velocity);
        var new_velocity = new Vec();
        var i, j;
        var trace;
        var end = new Vec();
        var time_left = time;
        var blocked = 0;
        for (bumpcount in 0...4) {
            if ((ent.v.velocity == 0.0) &&
                (ent.v.velocity1 == 0.0) &&
                (ent.v.velocity2 == 0.0))
                break;
            end[0] = ent.v.origin + time_left * ent.v.velocity;
            end[1] = ent.v.origin1 + time_left * ent.v.velocity1;
            end[2] = ent.v.origin2 + time_left * ent.v.velocity2;
            trace = SV.Move(ED.Vector(ent, EdictVarOfs.origin), ED.Vector(ent, EdictVarOfs.mins), ED.Vector(ent, EdictVarOfs.maxs), end, 0, ent);
            if (trace.allsolid) {
                ED.SetVector(ent, EdictVarOfs.velocity, Vec.origin);
                return 3;
            }
            if (trace.fraction > 0.0) {
                ED.SetVector(ent, EdictVarOfs.origin, trace.endpos);
                original_velocity = ED.Vector(ent, EdictVarOfs.velocity);
                numplanes = 0;
                if (trace.fraction == 1.0)
                    break;
            }
            if (trace.ent == null)
                Sys.Error('SV.FlyMove: !trace.ent');
            if (trace.plane.normal[2] > 0.7) {
                blocked |= 1;
                if (trace.ent.v.solid == SolidType.bsp) {
                    ent.flags = ent.flags | EntFlag.onground;
                    ent.v.groundentity = trace.ent.num;
                }
            } else if (trace.plane.normal[2] == 0.0) {
                blocked |= 2;
                SV.steptrace = trace;
            }
            SV.Impact(ent, trace.ent);
            if (ent.free)
                break;
            time_left -= time_left * trace.fraction;
            if (numplanes >= 5) {
                ED.SetVector(ent, EdictVarOfs.velocity, Vec.origin);
                return 3;
            }
            planes[numplanes++] = Vec.of(trace.plane.normal[0], trace.plane.normal[1], trace.plane.normal[2]);
            var i = 0;
            while (i < numplanes) {
                SV.ClipVelocity(original_velocity, planes[i], new_velocity, 1.0);
                var j = 0;
                while (j < numplanes) {
                    if (j != i) {
                        plane = planes[j];
                        if ((new_velocity[0] * plane[0] + new_velocity[1] * plane[1] + new_velocity[2] * plane[2]) < 0.0)
                            break;
                    }
                    j++;
                }
                if (j == numplanes)
                    break;
                i++;
            }
            if (i != numplanes)
                ED.SetVector(ent, EdictVarOfs.velocity, new_velocity);
            else {
                if (numplanes != 2) {
                    ED.SetVector(ent, EdictVarOfs.velocity, Vec.origin);
                    return 7;
                }
                dir = Vec.CrossProduct(planes[0], planes[1]);
                d = dir[0] * ent.v.velocity +
                    dir[1] * ent.v.velocity1 +
                    dir[2] * ent.v.velocity2;
                ent.v.velocity = dir[0] * d;
                ent.v.velocity1 = dir[1] * d;
                ent.v.velocity2 = dir[2] * d;
            }
            if ((ent.v.velocity * primal_velocity[0] +
                ent.v.velocity1 * primal_velocity[1] +
                ent.v.velocity2 * primal_velocity[2]) <= 0.0) {
                ED.SetVector(ent, EdictVarOfs.velocity, Vec.origin);
                return blocked;
            }
        }
        return blocked;
    }

    static function AddGravity(ent:Edict) {
        var val = EdictVarOfs.gravity, ent_gravity;
        if (val != null)
            ent_gravity = (ent._v_float[val] != 0.0) ? ent._v_float[val] : 1.0;
        else
            ent_gravity = 1.0;
        ent.v.velocity2 -= ent_gravity * SV.gravity.value * Host.frametime;
    }

    static function PushEntity(ent:Edict, push) {
        var end = Vec.of(
            ent.v.origin + push[0],
            ent.v.origin1 + push[1],
            ent.v.origin2 + push[2]
        );
        var nomonsters;
        var solid = ent.v.solid;
        if (ent.v.movetype == MoveType.flymissile)
            nomonsters = ClipType.missile;
        else if ((solid == SolidType.trigger) || (solid == SolidType.not))
            nomonsters = ClipType.nomonsters
        else
            nomonsters = ClipType.normal;
        var trace = SV.Move(ED.Vector(ent, EdictVarOfs.origin), ED.Vector(ent, EdictVarOfs.mins),
            ED.Vector(ent, EdictVarOfs.maxs), end, nomonsters, ent);
        ED.SetVector(ent, EdictVarOfs.origin, trace.endpos);
        SV.LinkEdict(ent, true);
        if (trace.ent != null)
            SV.Impact(ent, trace.ent);
        return trace;
    }

    static function PushMove(pusher:Edict, movetime:Float):Void {
        if ((pusher.v.velocity == 0.0) &&
            (pusher.v.velocity1 == 0.0) &&
            (pusher.v.velocity2 == 0.0)) {
            pusher.v.ltime += movetime;
            return;
        }
        var move = [
            pusher.v.velocity * movetime,
            pusher.v.velocity1 * movetime,
            pusher.v.velocity2 * movetime
        ];
        var mins = [
            pusher.v.absmin + move[0],
            pusher.v.absmin1 + move[1],
            pusher.v.absmin2 + move[2]
        ];
        var maxs = [
            pusher.v.absmax + move[0],
            pusher.v.absmax1 + move[1],
            pusher.v.absmax2 + move[2]
        ];
        var pushorig = ED.Vector(pusher, EdictVarOfs.origin);
        pusher.v.origin += move[0];
        pusher.v.origin1 += move[1];
        pusher.v.origin2 += move[2];
        pusher.v.ltime += movetime;
        SV.LinkEdict(pusher, false);
        var moved:Array<Dynamic> = [];
        for (e in 1...SV.server.num_edicts) {
            var check = SV.server.edicts[e];
            if (check.free)
                continue;
            var movetype = check.v.movetype;
            if ((movetype == MoveType.push)
                || (movetype == MoveType.none)
                || (movetype == MoveType.noclip))
                continue;
            if (((check.flags & EntFlag.onground) == 0) ||
                (check.v.groundentity != pusher.num)) {
                if ((check.v.absmin >= maxs[0])
                    || (check.v.absmin1 >= maxs[1])
                    || (check.v.absmin2 >= maxs[2])
                    || (check.v.absmax <= mins[0])
                    || (check.v.absmax1 <= mins[1])
                    || (check.v.absmax2 <= mins[2]))
                    continue;
                if (!SV.TestEntityPosition(check))
                    continue;
            }
            if (movetype != MoveType.walk)
                check.flags = check.flags & ~EntFlag.onground;
            var entorig = ED.Vector(check, EdictVarOfs.origin);
            moved[moved.length] = [entorig[0], entorig[1], entorig[2], check];
            pusher.v.solid = SolidType.not;
            SV.PushEntity(check, move);
            pusher.v.solid = SolidType.bsp;
            if (SV.TestEntityPosition(check)) {
                if (check.v.mins == check.v.maxs)
                    continue;
                if ((check.v.solid == SolidType.not) || (check.v.solid == SolidType.trigger)) {
                    check.v.mins = check.v.maxs = 0.0;
                    check.v.mins1 = check.v.maxs1 = 0.0;
                    check.v.maxs2 = check.v.mins2;
                    continue;
                }
                check.v.origin = entorig[0];
                check.v.origin1 = entorig[1];
                check.v.origin2 = entorig[2];
                SV.LinkEdict(check, true);
                pusher.v.origin = pushorig[0];
                pusher.v.origin1 = pushorig[1];
                pusher.v.origin2 = pushorig[2];
                SV.LinkEdict(pusher, false);
                pusher.v.ltime -= movetime;
                if (pusher.v.blocked != 0) {
                    PR.globals_int[GlobalVarOfs.self] = pusher.num;
                    PR.globals_int[GlobalVarOfs.other] = check.num;
                    PR.ExecuteProgram(pusher.v.blocked);
                }
                for (moved_edict in moved) {
                    (moved_edict[3] : Edict).v.origin = moved_edict[0];
                    (moved_edict[3] : Edict).v.origin1 = moved_edict[1];
                    (moved_edict[3] : Edict).v.origin2 = moved_edict[2];
                    SV.LinkEdict(moved_edict[3], false);
                }
                return;
            }
        }
    }

    static function Physics_Pusher(ent:Edict) {
        var oldltime = ent.v.ltime;
        var thinktime = ent.v.nextthink;
        var movetime;
        if (thinktime < (oldltime + Host.frametime)) {
            movetime = thinktime - oldltime;
            if (movetime < 0.0)
                movetime = 0.0;
        } else
            movetime = Host.frametime;
        if (movetime != 0.0)
            SV.PushMove(ent, movetime);
        if ((thinktime <= oldltime) || (thinktime > ent.v.ltime))
            return;
        ent.v.nextthink = 0.0;
        PR.globals_float[GlobalVarOfs.time] = SV.server.time;
        PR.globals_int[GlobalVarOfs.self] = ent.num;
        PR.globals_int[GlobalVarOfs.other] = 0;
        PR.ExecuteProgram(ent.v.think);
    }

    static function CheckStuck(ent:Edict) {
        if (!SV.TestEntityPosition(ent)) {
            ent.v.oldorigin = ent.v.origin;
            ent.v.oldorigin1 = ent.v.origin1;
            ent.v.oldorigin2 = ent.v.origin2;
            return;
        }
        var org = ED.Vector(ent, EdictVarOfs.origin);
        ent.v.origin = ent.v.oldorigin;
        ent.v.origin1 = ent.v.oldorigin1;
        ent.v.origin2 = ent.v.oldorigin2;
        if (!SV.TestEntityPosition(ent)) {
            Console.DPrint('Unstuck.\n');
            SV.LinkEdict(ent, true);
            return;
        }
        for (z in 0...18) {
            for (i in -1...2) {
                for (j in -1...2) {
                    ent.v.origin = org[0] + i;
                    ent.v.origin1 = org[1] + j;
                    ent.v.origin2 = org[2] + z;
                    if (!SV.TestEntityPosition(ent)) {
                        Console.DPrint('Unstuck.\n');
                        SV.LinkEdict(ent, true);
                        return;
                    }
                }
            }
        }
        ED.SetVector(ent, EdictVarOfs.origin, org);
        Console.DPrint('player is stuck.\n');
    }

    static function CheckWater(ent:Edict):Bool {
        var point = Vec.of(
            ent.v.origin,
            ent.v.origin1,
            ent.v.origin2 + ent.v.mins2 + 1.0
        );
        ent.v.waterlevel = 0.0;
        ent.v.watertype = ModContents.empty;
        var cont = SV.PointContents(point);
        if (cont > ModContents.water)
            return false;
        ent.v.watertype = cont;
        ent.v.waterlevel = 1.0;
        point[2] = ent.v.origin2 + (ent.v.mins2 + ent.v.maxs2) * 0.5;
        cont = SV.PointContents(point);
        if (cont <= ModContents.water) {
            ent.v.waterlevel = 2.0;
            point[2] = ent.v.origin2 + ent.v.view_ofs2;
            cont = SV.PointContents(point);
            if (cont <= ModContents.water)
                ent.v.waterlevel = 3.0;
        }
        return ent.v.waterlevel > 1.0;
    }

    static function WallFriction(ent:Edict, trace:MTrace):Void {
        var forward = new Vec();
        Vec.AngleVectors(ED.Vector(ent, EdictVarOfs.v_angle), forward);
        var normal = trace.plane.normal;
        var d = normal[0] * forward[0] + normal[1] * forward[1] + normal[2] * forward[2] + 0.5;
        if (d >= 0.0)
            return;
        d += 1.0;
        var i = normal[0] * ent.v.velocity
            + normal[1] * ent.v.velocity1
            + normal[2] * ent.v.velocity2;
        ent.v.velocity = (ent.v.velocity - normal[0] * i) * d; 
        ent.v.velocity1 = (ent.v.velocity1 - normal[1] * i) * d; 
    }

    static function TryUnstick(ent:Edict, oldvel:Vec):Int {
        var oldorg = ED.Vector(ent, EdictVarOfs.origin);
        var dir = [2.0, 0.0, 0.0];
        for (i in 0...8) {
            switch (i) {
                case 1: dir[0] = 0.0; dir[1] = 2.0;
                case 2: dir[0] = -2.0; dir[1] = 0.0;
                case 3: dir[0] = 0.0; dir[1] = -2.0;
                case 4: dir[0] = 2.0; dir[1] = 2.0;
                case 5: dir[0] = -2.0; dir[1] = 2.0;
                case 6: dir[0] = 2.0; dir[1] = -2.0;
                case 7: dir[0] = -2.0; dir[1] = -2.0;
            }
            SV.PushEntity(ent, dir);
            ent.v.velocity = oldvel[0];
            ent.v.velocity1 = oldvel[1];
            ent.v.velocity2 = 0.0;
            var clip = SV.FlyMove(ent, 0.1);
            if ((Math.abs(oldorg[1] - ent.v.origin1) > 4.0)
                || (Math.abs(oldorg[0] - ent.v.origin) > 4.0))
                return clip;
            ED.SetVector(ent, EdictVarOfs.origin, oldorg);
        }
        ED.SetVector(ent, EdictVarOfs.velocity, Vec.origin);
        return 7;
    }

    static function WalkMove(ent:Edict) {
        var oldonground = ent.flags & EntFlag.onground;
        ent.flags = ent.flags ^ oldonground;
        var oldorg = ED.Vector(ent, EdictVarOfs.origin);
        var oldvel = ED.Vector(ent, EdictVarOfs.velocity);
        var clip = SV.FlyMove(ent, Host.frametime);
        if ((clip & 2) == 0)
            return;
        if ((oldonground == 0) && (ent.v.waterlevel == 0.0))
            return;
        if (ent.v.movetype != MoveType.walk)
            return;
        if (SV.nostep.value != 0)
            return;
        if ((SV.player.flags & EntFlag.waterjump) != 0)
            return;
        var nosteporg = ED.Vector(ent, EdictVarOfs.origin);
        var nostepvel = ED.Vector(ent, EdictVarOfs.velocity);
        ED.SetVector(ent, EdictVarOfs.origin, oldorg);
        SV.PushEntity(ent, [0.0, 0.0, 18.0]);
        ent.v.velocity = oldvel[0];
        ent.v.velocity1 = oldvel[1];
        ent.v.velocity2 = 0.0;
        clip = SV.FlyMove(ent, Host.frametime);
        if (clip != 0) {
            if ((Math.abs(oldorg[1] - ent.v.origin1) < 0.03125)
                && (Math.abs(oldorg[0] - ent.v.origin) < 0.03125))
                clip = SV.TryUnstick(ent, oldvel);
            if ((clip & 2) != 0)
                SV.WallFriction(ent, SV.steptrace);
        }
        var downtrace = SV.PushEntity(ent, [0.0, 0.0, oldvel[2] * Host.frametime - 18.0]);
        if (downtrace.plane.normal[2] > 0.7) {
            if (ent.v.solid == SolidType.bsp) {
                ent.flags = ent.flags | EntFlag.onground;
                ent.v.groundentity = downtrace.ent.num;
            }
            return;
        }
        ED.SetVector(ent, EdictVarOfs.origin, nosteporg);
        ED.SetVector(ent, EdictVarOfs.velocity, nostepvel);
    }

    static function Physics_Client(ent:Edict) {
        if (!SV.svs.clients[ent.num - 1].active)
            return;
        PR.globals_float[GlobalVarOfs.time] = SV.server.time;
        PR.globals_int[GlobalVarOfs.self] = ent.num;
        PR.ExecuteProgram(PR.globals_int[GlobalVarOfs.PlayerPreThink]);
        SV.CheckVelocity(ent);
        var movetype = Std.int(ent.v.movetype);
        if (movetype == MoveType.toss || movetype == MoveType.bounce) {
            SV.Physics_Toss(ent);
        } else {
            if (!SV.RunThink(ent))
                return;
            switch (movetype) {
                case MoveType.none:
                case MoveType.walk:
                    if (!SV.CheckWater(ent) && (ent.flags & EntFlag.waterjump) == 0)
                        SV.AddGravity(ent);
                    SV.CheckStuck(ent);
                    SV.WalkMove(ent);
                case MoveType.fly:
                    SV.FlyMove(ent, Host.frametime);
                case MoveType.noclip:
                    ent.v.origin += Host.frametime * ent.v.velocity;
                    ent.v.origin1 += Host.frametime * ent.v.velocity1;
                    ent.v.origin2 += Host.frametime * ent.v.velocity2;
                default:
                    Sys.Error('SV.Physics_Client: bad movetype ' + movetype);
            }
        }
        SV.LinkEdict(ent, true);
        PR.globals_float[GlobalVarOfs.time] = SV.server.time;
        PR.globals_int[GlobalVarOfs.self] = ent.num;
        PR.ExecuteProgram(PR.globals_int[GlobalVarOfs.PlayerPostThink]);
    }

    static function Physics_Noclip(ent:Edict) {
        if (!SV.RunThink(ent))
            return;
        ent.v.angles += Host.frametime * ent.v.avelocity;
        ent.v.angles1 += Host.frametime * ent.v.avelocity1;
        ent.v.angles2 += Host.frametime * ent.v.avelocity2;
        ent.v.origin += Host.frametime * ent.v.velocity;
        ent.v.origin1 += Host.frametime * ent.v.velocity1;
        ent.v.origin2 += Host.frametime * ent.v.velocity2;
        SV.LinkEdict(ent, false);
    }

    static function CheckWaterTransition(ent:Edict) {
        var cont = SV.PointContents(ED.Vector(ent, EdictVarOfs.origin));
        if (ent.v.watertype == 0.0) {
            ent.v.watertype = cont;
            ent.v.waterlevel = 1.0;
            return;
        }
        if (cont <= ModContents.water) {
            if (ent.v.watertype == ModContents.empty)
                SV.StartSound(ent, 0, 'misc/h2ohit1.wav', 255, 1.0);
            ent.v.watertype = cont;
            ent.v.waterlevel = 1.0;
            return;
        }
        if (ent.v.watertype != ModContents.empty)
            SV.StartSound(ent, 0, 'misc/h2ohit1.wav', 255, 1.0);
        ent.v.watertype = ModContents.empty;
        ent.v.waterlevel = cont;
    }

    static function Physics_Toss(ent:Edict) {
        if (!SV.RunThink(ent))
            return;
        if ((ent.flags & EntFlag.onground) != 0)
            return;
        SV.CheckVelocity(ent);
        var movetype = ent.v.movetype;
        if ((movetype != MoveType.fly) && (movetype != MoveType.flymissile))
            SV.AddGravity(ent);
        ent.v.angles += Host.frametime * ent.v.avelocity;
        ent.v.angles1 += Host.frametime * ent.v.avelocity1;
        ent.v.angles2 += Host.frametime * ent.v.avelocity2;
        var trace = SV.PushEntity(ent,
            [
                ent.v.velocity * Host.frametime,
                ent.v.velocity1 * Host.frametime,
                ent.v.velocity2 * Host.frametime
            ]);
        if ((trace.fraction == 1.0) || (ent.free))
            return;
        var velocity = new Vec();
        SV.ClipVelocity(ED.Vector(ent, EdictVarOfs.velocity), trace.plane.normal, velocity, (movetype == MoveType.bounce) ? 1.5 : 1.0);
        ED.SetVector(ent, EdictVarOfs.velocity, velocity);
        if (trace.plane.normal[2] > 0.7) {
            if ((ent.v.velocity2 < 60.0) || (movetype != MoveType.bounce)) {
                ent.flags = ent.flags | EntFlag.onground;
                ent.v.groundentity = trace.ent.num;
                ent.v.velocity = ent.v.velocity1 = ent.v.velocity2 = 0.0;
                ent.v.avelocity = ent.v.avelocity1 = ent.v.avelocity2 = 0.0;
            }
        }
        SV.CheckWaterTransition(ent);
    }

    static function Physics_Step(ent:Edict):Void {
        if ((ent.flags & (EntFlag.onground + EntFlag.fly + EntFlag.swim)) == 0) {
            var hitsound = (ent.v.velocity2 < (SV.gravity.value * -0.1));
            SV.AddGravity(ent);
            SV.CheckVelocity(ent);
            SV.FlyMove(ent, Host.frametime);
            SV.LinkEdict(ent, true);
            if (((ent.flags & EntFlag.onground) != 0) && (hitsound))
                SV.StartSound(ent, 0, 'demon/dland2.wav', 255, 1.0);
        }
        SV.RunThink(ent);
        SV.CheckWaterTransition(ent);
    }

    static function Physics() {
        PR.globals_int[GlobalVarOfs.self] = 0;
        PR.globals_int[GlobalVarOfs.other] = 0;
        PR.globals_float[GlobalVarOfs.time] = SV.server.time;
        PR.ExecuteProgram(PR.globals_int[GlobalVarOfs.StartFrame]);
        for (i in 0...SV.server.num_edicts) {
            var ent = SV.server.edicts[i];
            if (ent.free)
                continue;
            if (PR.globals_float[GlobalVarOfs.force_retouch] != 0.0)
                SV.LinkEdict(ent, true);
            if (i > 0 && i <= SV.svs.maxclients) {
                SV.Physics_Client(ent);
                continue;
            }
            switch (ent.v.movetype) {
                case MoveType.push:
                    SV.Physics_Pusher(ent);
                case MoveType.none:
                    SV.RunThink(ent);
                case MoveType.noclip:
                    SV.RunThink(ent);
                case MoveType.step:
                    SV.Physics_Step(ent);
                case MoveType.toss | MoveType.bounce | MoveType.fly | MoveType.flymissile:
                    SV.Physics_Toss(ent);
                default:
                    Sys.Error('SV.Physics: bad movetype ' + Std.int(ent.v.movetype));
            }
        }
        if (PR.globals_float[GlobalVarOfs.force_retouch] != 0.0)
            --PR.globals_float[GlobalVarOfs.force_retouch];
        SV.server.time += Host.frametime;
    }

    // user

    static var player:Edict;

    static function SetIdealPitch() {
        var ent = SV.player;
        if ((ent.flags & EntFlag.onground) == 0)
            return;
        var angleval = ent.v.angles1 * (Math.PI / 180.0);
        var sinval = Math.sin(angleval);
        var cosval = Math.cos(angleval);
        var top = Vec.of(0.0, 0.0, ent.v.origin2 + ent.v.view_ofs2);
        var bottom = Vec.of(0.0, 0.0, top[2] - 160.0);
        var z = [];
        for (i in 0...6) {
            top[0] = bottom[0] = ent.v.origin + cosval * (i + 3) * 12.0;
            top[1] = bottom[1] = ent.v.origin1 + sinval * (i + 3) * 12.0;
            var tr = SV.Move(top, Vec.origin, Vec.origin, bottom, 1, ent);
            if ((tr.allsolid) || (tr.fraction == 1.0))
                return;
            z[i] = top[2] - tr.fraction * 160.0;
        }
        var dir = 0.0, steps = 0;
        for (i in 1...6) {
            var step = z[i] - z[i - 1];
            if ((step > -0.1) && (step < 0.1))
                continue;
            if ((dir != 0.0) && (((step - dir) > 0.1) || ((step - dir) < -0.1)))
                return;
            ++steps;
            dir = step;
        }
        if (dir == 0.0) {
            ent.v.idealpitch = 0.0;
            return;
        }
        if (steps >= 2)
            ent.v.idealpitch = -dir * SV.idealpitchscale.value;
    }

    static function UserFriction() {
        var ent = SV.player;
        var vel0 = ent.v.velocity, vel1 = ent.v.velocity1;
        var speed = Math.sqrt(vel0 * vel0 + vel1 * vel1);
        if (speed == 0.0)
            return;
        var start = Vec.of(
            ent.v.origin + vel0 / speed * 16.0,
            ent.v.origin1 + vel1 / speed * 16.0,
            ent.v.origin2 + ent.v.mins2
        );
        var friction = SV.friction.value;
        if (SV.Move(start, Vec.origin, Vec.origin, Vec.of(start[0], start[1], start[2] - 34.0), 1, ent).fraction == 1.0)
            friction *= SV.edgefriction.value;
        var newspeed = speed - Host.frametime * (speed < SV.stopspeed.value ? SV.stopspeed.value : speed) * friction;
        if (newspeed < 0.0)
            newspeed = 0.0;
        newspeed /= speed;
        ent.v.velocity *= newspeed;
        ent.v.velocity1 *= newspeed;
        ent.v.velocity2 *= newspeed;
    }

    static function Accelerate(wishvel:Vec, air:Bool) {
        var ent = SV.player;
        var wishdir = wishvel.copy();
        var wishspeed = Vec.Normalize(wishdir);
        if ((air) && (wishspeed > 30.0))
            wishspeed = 30.0;
        var addspeed = wishspeed - (ent.v.velocity * wishdir[0]
            + ent.v.velocity1 * wishdir[1]
            + ent.v.velocity2 * wishdir[2]
        );
        if (addspeed <= 0.0)
            return;
        var accelspeed = SV.accelerate.value * Host.frametime * wishspeed;
        if (accelspeed > addspeed)
            accelspeed = addspeed;
        ent.v.velocity += accelspeed * wishdir[0];
        ent.v.velocity1 += accelspeed * wishdir[1];
        ent.v.velocity2 += accelspeed * wishdir[2];
    }

    static function WaterMove() {
        var ent = SV.player, cmd = Host.client.cmd;
        var forward = new Vec(), right = new Vec();
        Vec.AngleVectors(ED.Vector(ent, EdictVarOfs.v_angle), forward, right);
        var wishvel = [
            forward[0] * cmd.forwardmove + right[0] * cmd.sidemove,
            forward[1] * cmd.forwardmove + right[1] * cmd.sidemove,
            forward[2] * cmd.forwardmove + right[2] * cmd.sidemove
        ];
        if ((cmd.forwardmove == 0.0) && (cmd.sidemove == 0.0) && (cmd.upmove == 0.0))
            wishvel[2] -= 60.0;
        else
            wishvel[2] += cmd.upmove;
        var wishspeed = Math.sqrt(wishvel[0] * wishvel[0] + wishvel[1] * wishvel[1] + wishvel[2] * wishvel[2]);
        var scale;
        if (wishspeed > SV.maxspeed.value) {
            scale = SV.maxspeed.value / wishspeed;
            wishvel[0] *= scale;
            wishvel[1] *= scale;
            wishvel[2] *= scale;
            wishspeed = SV.maxspeed.value;
        }
        wishspeed *= 0.7;
        var speed = Math.sqrt(ent.v.velocity * ent.v.velocity
            + ent.v.velocity1 * ent.v.velocity1
            + ent.v.velocity2 * ent.v.velocity2
        ), newspeed;
        if (speed != 0.0) {
            newspeed = speed - Host.frametime * speed * SV.friction.value;
            if (newspeed < 0.0)
                newspeed = 0.0;
            scale = newspeed / speed;
            ent.v.velocity *= scale;
            ent.v.velocity1 *= scale;
            ent.v.velocity2 *= scale;
        } else
            newspeed = 0.0;
        if (wishspeed == 0.0)
            return;
        var addspeed = wishspeed - newspeed;
        if (addspeed <= 0.0)
            return;
        var accelspeed = SV.accelerate.value * wishspeed * Host.frametime;
        if (accelspeed > addspeed)
            accelspeed = addspeed;
        ent.v.velocity += accelspeed * (wishvel[0] / wishspeed);
        ent.v.velocity1 += accelspeed * (wishvel[1] / wishspeed);
        ent.v.velocity2 += accelspeed * (wishvel[2] / wishspeed);
    }

    static function WaterJump() {
        var ent = SV.player;
        if ((SV.server.time > ent.v.teleport_time) || (ent.v.waterlevel == 0.0)) {
            ent.flags = ent.flags & ~EntFlag.waterjump;
            ent.v.teleport_time = 0.0;
        }
        ent.v.velocity = ent.v.movedir;
        ent.v.velocity1 = ent.v.movedir1;
    }

    static function AirMove() {
        var ent = SV.player;
        var cmd = Host.client.cmd;
        var forward = new Vec(), right = new Vec();
        Vec.AngleVectors(ED.Vector(ent, EdictVarOfs.angles), forward, right);
        var fmove = cmd.forwardmove;
        var smove = cmd.sidemove;
        if ((SV.server.time < ent.v.teleport_time) && (fmove < 0.0))
            fmove = 0.0;
        var wishvel = Vec.of(
            forward[0] * fmove + right[0] * smove,
            forward[1] * fmove + right[1] * smove,
            (Std.int(ent.v.movetype) != MoveType.walk) ? cmd.upmove : 0.0
        );
        var wishdir = wishvel.copy();
        if (Vec.Normalize(wishdir) > SV.maxspeed.value) {
            wishvel[0] = wishdir[0] * SV.maxspeed.value;
            wishvel[1] = wishdir[1] * SV.maxspeed.value;
            wishvel[2] = wishdir[2] * SV.maxspeed.value;
        }
        if (ent.v.movetype == MoveType.noclip)
            ED.SetVector(ent, EdictVarOfs.velocity, wishvel);
        else if ((ent.flags & EntFlag.onground) != 0) {
            SV.UserFriction();
            SV.Accelerate(wishvel, false);
        } else
            SV.Accelerate(wishvel, true);
    }

    static function ClientThink() {
        var ent = SV.player;

        if (ent.v.movetype == MoveType.none)
            return;

        var punchangle = ED.Vector(ent, EdictVarOfs.punchangle);
        var len = Vec.Normalize(punchangle) - 10.0 * Host.frametime;
        if (len < 0.0)
            len = 0.0;
        ent.v.punchangle = punchangle[0] * len;
        ent.v.punchangle1 = punchangle[1] * len;
        ent.v.punchangle2 = punchangle[2] * len;

        if (ent.v.health <= 0.0)
            return;

        ent.v.angles2 = V.CalcRoll(ED.Vector(ent, EdictVarOfs.angles), ED.Vector(ent, EdictVarOfs.velocity)) * 4.0;
        if (SV.player.v.fixangle == 0.0) {
            ent.v.angles = (ent.v.v_angle + ent.v.punchangle) / -3.0;
            ent.v.angles1 = ent.v.v_angle1 + ent.v.punchangle1;
        }

        if ((ent.flags & EntFlag.waterjump) != 0)
            SV.WaterJump();
        else if ((ent.v.waterlevel >= 2.0) && (ent.v.movetype != MoveType.noclip))
            SV.WaterMove();
        else
            SV.AirMove();
    }

    static function ReadClientMove() {
        var client = Host.client;
        client.ping_times[client.num_pings++ & 15] = SV.server.time - MSG.ReadFloat();
        client.edict.v.v_angle = MSG.ReadAngle();
        client.edict.v.v_angle1 = MSG.ReadAngle();
        client.edict.v.v_angle2 = MSG.ReadAngle();
        client.cmd.forwardmove = MSG.ReadShort();
        client.cmd.sidemove = MSG.ReadShort();
        client.cmd.upmove = MSG.ReadShort();
        var i = MSG.ReadByte();
        client.edict.v.button0 = i & 1;
        client.edict.v.button2 = (i & 2) >> 1;
        i = MSG.ReadByte();
        if (i != 0)
            client.edict.v.impulse = i;
    }

    static function ReadClientMessage():Bool {
        var ret;
        var cmds = [
            'status',
            'god', 
            'notarget',
            'fly',
            'name',
            'noclip',
            'say',
            'say_team',
            'tell',
            'color',
            'kill',
            'pause',
            'spawn',
            'begin',
            'prespawn',
            'kick',
            'ping',
            'give',
            'ban'
        ];
        do
        {
            ret = NET.GetMessage(Host.client.netconnection);
            if (ret == -1) {
                Sys.Print('SV.ReadClientMessage: NET.GetMessage failed\n');
                return false;
            }
            if (ret == 0)
                return true;
            MSG.BeginReading();
            while (true) {
                if (!Host.client.active)
                    return false;
                if (MSG.badread) {
                    Sys.Print('SV.ReadClientMessage: badread\n');
                    return false;
                }
                var cmd = MSG.ReadChar();
                if (cmd == -1) {
                    ret = 1;
                    break;
                }
                if (cmd == CLC.nop)
                    continue;
                if (cmd == CLC.stringcmd) {
                    var s = MSG.ReadString();
                    var i = 0;
                    while (i < cmds.length) {
                        if (s.substring(0, cmds[i].length).toLowerCase() != cmds[i]) {
                            i++;
                            continue;
                        }
                        Cmd.ExecuteString(s, true);
                        break;
                    }
                    if (i == cmds.length)
                        Console.DPrint(SV.GetClientName(Host.client) + ' tried to ' + s);
                } else if (cmd == CLC.disconnect)
                    return false;
                else if (cmd == CLC.move)
                    SV.ReadClientMove();
                else {
                    Sys.Print('SV.ReadClientMessage: unknown command char\n');
                    return false;
                }
            }
        } while (ret == 1);
        return false;
    }

    static function RunClients() {
        for (i in 0...SV.svs.maxclients) {
            Host.client = SV.svs.clients[i];
            if (!Host.client.active)
                continue;
            SV.player = Host.client.edict;
            if (!SV.ReadClientMessage()) {
                Host.DropClient(false);
                continue;
            }
            if (!Host.client.spawned) {
                Host.client.cmd.forwardmove = 0.0;
                Host.client.cmd.sidemove = 0.0;
                Host.client.cmd.upmove = 0.0;
                continue;
            }
            SV.ClientThink();
        }
    }

    // world

    static var box_clipnodes:Array<MClipNode>;
    static var box_planes:Array<Plane>;
    static var box_hull:MHull;

    static function InitBoxHull():Void {
        box_clipnodes = [];
        box_planes = [];
        box_hull = new MHull();

        box_hull.clipnodes = box_clipnodes;
        box_hull.planes = box_planes;
        box_hull.firstclipnode = 0;
        box_hull.lastclipnode = 5;

        for (i in 0...6) {
            var side = i & 1;

            var node = new MClipNode();
            node.planenum = i;
            node.children = [];
            node.children[side] = empty;
            if (i != 5)
                node.children[side ^ 1] = i + 1;
            else
                node.children[side ^ 1] = solid;
            box_clipnodes.push(node);

            var plane = new Plane();
            plane.type = i >> 1;
            plane.normal = new Vec();
            plane.normal[i >> 1] = 1.0;
            plane.dist = 0.0;
            box_planes.push(plane);
        }
    }

    static function HullForEntity(ent:Edict, mins:Vec, maxs:Vec, offset:Vec):MHull {
        if (ent.v.solid != SolidType.bsp) {
            SV.box_planes[0].dist = ent.v.maxs - mins[0];
            SV.box_planes[1].dist = ent.v.mins - maxs[0];
            SV.box_planes[2].dist = ent.v.maxs1 - mins[1];
            SV.box_planes[3].dist = ent.v.mins1 - maxs[1];
            SV.box_planes[4].dist = ent.v.maxs2 - mins[2];
            SV.box_planes[5].dist = ent.v.mins2 - maxs[2];
            offset[0] = ent.v.origin;
            offset[1] = ent.v.origin1;
            offset[2] = ent.v.origin2;
            return SV.box_hull;
        }
        if (ent.v.movetype != MoveType.push)
            Sys.Error('SOLID_BSP without MOVETYPE_PUSH');
        var model = SV.server.models[Std.int(ent.v.modelindex)];
        if (model == null)
            Sys.Error('MOVETYPE_PUSH with a non bsp model');
        if (model.type != brush)
            Sys.Error('MOVETYPE_PUSH with a non bsp model');
        var size = maxs[0] - mins[0];
        var hull;
        if (size < 3.0)
            hull = model.hulls[0];
        else if (size <= 32.0)
            hull = model.hulls[1];
        else
            hull = model.hulls[2];
        offset[0] = hull.clip_mins[0] - mins[0] + ent.v.origin;
        offset[1] = hull.clip_mins[1] - mins[1] + ent.v.origin1;
        offset[2] = hull.clip_mins[2] - mins[2] + ent.v.origin2;
        return hull;
    }

    static function CreateAreaNode(depth:Int, mins:Vec, maxs:Vec):MAreaNode {
        var anode = new MAreaNode();
        SV.areanodes.push(anode);

        anode.trigger_edicts = new MLink();
        anode.trigger_edicts.prev = anode.trigger_edicts.next = anode.trigger_edicts;
        anode.solid_edicts = new MLink();
        anode.solid_edicts.prev = anode.solid_edicts.next = anode.solid_edicts;

        if (depth == 4) {
            anode.axis = -1;
            anode.children = [];
            return anode;
        }

        anode.axis = (maxs[0] - mins[0]) > (maxs[1] - mins[1]) ? 0 : 1;
        anode.dist = 0.5 * (maxs[anode.axis] + mins[anode.axis]);

        var maxs1 = maxs.copy();
        var mins2 = mins.copy();
        maxs1[anode.axis] = mins2[anode.axis] = anode.dist;
        anode.children = [SV.CreateAreaNode(depth + 1, mins2, maxs), SV.CreateAreaNode(depth + 1, mins, maxs1)];
        return anode;
    }

    static function UnlinkEdict(ent:Edict) {
        if (ent.area.prev != null)
            ent.area.prev.next = ent.area.next;
        if (ent.area.next != null)
            ent.area.next.prev = ent.area.prev;
        ent.area.prev = ent.area.next = null;
    }

    static function TouchLinks(ent:Edict, node:MAreaNode):Void {
        var l = node.trigger_edicts.next;
        while (l != node.trigger_edicts) {
            var touch = l.ent;
            l = l.next;
            if (touch == ent)
                continue;
            if (touch.v.touch == 0 || touch.v.solid != SolidType.trigger)
                continue;
            if (ent.v.absmin > touch.v.absmax || ent.v.absmin1 > touch.v.absmax1 || ent.v.absmin2 > touch.v.absmax2 ||
                ent.v.absmax < touch.v.absmin || ent.v.absmax1 < touch.v.absmin1 || ent.v.absmax2 < touch.v.absmin2)
                continue;
            var old_self = PR.globals_int[GlobalVarOfs.self];
            var old_other = PR.globals_int[GlobalVarOfs.other];
            PR.globals_int[GlobalVarOfs.self] = touch.num;
            PR.globals_int[GlobalVarOfs.other] = ent.num;
            PR.globals_float[GlobalVarOfs.time] = server.time;
            PR.ExecuteProgram(touch.v.touch);
            PR.globals_int[GlobalVarOfs.self] = old_self;
            PR.globals_int[GlobalVarOfs.other] = old_other;
        }
        if (node.axis == -1)
            return;
        if (ent._v_float[EdictVarOfs.absmax + node.axis] > node.dist)
            TouchLinks(ent, node.children[0]);
        if (ent._v_float[EdictVarOfs.absmin + node.axis] < node.dist)
            TouchLinks(ent, node.children[1]);
    }

    static function FindTouchedLeafs(ent:Edict, node:MNode):Void {
        if (node.contents == ModContents.solid)
            return;

        if (node.contents < 0) {
            if (ent.leafnums.length == 16)
                return;
            ent.leafnums[ent.leafnums.length] = node.num - 1;
            return;
        }

        var sides = Vec.BoxOnPlaneSide(Vec.of(ent.v.absmin, ent.v.absmin1, ent.v.absmin2),
            Vec.of(ent.v.absmax, ent.v.absmax1, ent.v.absmax2), node.plane);
        if ((sides & 1) != 0)
            SV.FindTouchedLeafs(ent, node.children[0]);
        if ((sides & 2) != 0)
            SV.FindTouchedLeafs(ent, node.children[1]);
    }

    static function LinkEdict(ent:Edict, touch_triggers:Bool):Void {
        if (ent.free || ent == server.edicts[0])
            return;

        UnlinkEdict(ent);

        ent.v.absmin = ent.v.origin + ent.v.mins - 1.0;
        ent.v.absmin1 = ent.v.origin1 + ent.v.mins1 - 1.0;
        ent.v.absmin2 = ent.v.origin2 + ent.v.mins2;
        ent.v.absmax = ent.v.origin + ent.v.maxs + 1.0;
        ent.v.absmax1 = ent.v.origin1 + ent.v.maxs1 + 1.0;
        ent.v.absmax2 = ent.v.origin2 + ent.v.maxs2;

        if ((ent.flags & EntFlag.item) != 0) {
            ent.v.absmin -= 14.0;
            ent.v.absmin1 -= 14.0;
            ent.v.absmax += 14.0;
            ent.v.absmax1 += 14.0;
        } else {
            ent.v.absmin2 -= 1.0;
            ent.v.absmax2 += 1.0;
        }

        ent.leafnums = [];
        if (ent.v.modelindex != 0)
            FindTouchedLeafs(ent, server.worldmodel.nodes[0]);

        if (ent.v.solid == SolidType.not)
            return;

        var node = areanodes[0];
        while (true) {
            if (node.axis == -1)
                break;
            if (ent._v_float[EdictVarOfs.absmin + node.axis] > node.dist)
                node = node.children[0];
            else if (ent._v_float[EdictVarOfs.absmax + node.axis] < node.dist)
                node = node.children[1];
            else
                break;
        }

        var before = (ent.v.solid == SolidType.trigger) ? node.trigger_edicts : node.solid_edicts;
        ent.area.next = before;
        ent.area.prev = before.prev;
        ent.area.prev.next = ent.area;
        ent.area.next.prev = ent.area;
        ent.area.ent = ent;

        if (touch_triggers)
            TouchLinks(ent, areanodes[0]);
    }

    static function HullPointContents(hull:MHull, num:Int, p:Vec):ModContents {
        while (num >= 0) {
            if ((num < hull.firstclipnode) || (num > hull.lastclipnode))
                Sys.Error('SV.HullPointContents: bad node number');
            var node = hull.clipnodes[num];
            var plane = hull.planes[node.planenum];
            var d;
            if (plane.type <= 2)
                d = p[plane.type] - plane.dist;
            else
                d = plane.normal[0] * p[0] + plane.normal[1] * p[1] + plane.normal[2] * p[2] - plane.dist;
            if (d >= 0.0)
                num = node.children[0];
            else
                num = node.children[1];
        }
        return num;
    }

    static function PointContents(p:Vec):ModContents {
        var cont = SV.HullPointContents(SV.server.worldmodel.hulls[0], 0, p);
        if ((cont <= ModContents.current_0) && (cont >= ModContents.current_down))
            return ModContents.water;
        return cont;
    }

    static function TestEntityPosition(ent) {
        var origin = ED.Vector(ent, EdictVarOfs.origin);
        return SV.Move(origin, ED.Vector(ent, EdictVarOfs.mins), ED.Vector(ent, EdictVarOfs.maxs), origin, 0, ent).startsolid;
    }

    static function RecursiveHullCheck(hull:MHull, num:Int, p1f:Float, p2f:Float, p1:Vec, p2:Vec, trace:MTrace):Bool {
        if (num < 0) {
            if (num != ModContents.solid) {
                trace.allsolid = false;
                if (num == ModContents.empty)
                    trace.inopen = true;
                else
                    trace.inwater = true;
            } else
                trace.startsolid = true;
            return true;
        }

        if ((num < hull.firstclipnode) || (num > hull.lastclipnode))
            Sys.Error('SV.RecursiveHullCheck: bad node number');

        var node = hull.clipnodes[num];
        var plane = hull.planes[node.planenum];
        var t1, t2;

        if (plane.type <= 2) {
            t1 = p1[plane.type] - plane.dist;
            t2 = p2[plane.type] - plane.dist;
        } else {
            t1 = plane.normal[0] * p1[0] + plane.normal[1] * p1[1] + plane.normal[2] * p1[2] - plane.dist;
            t2 = plane.normal[0] * p2[0] + plane.normal[1] * p2[1] + plane.normal[2] * p2[2] - plane.dist;
        }

        if ((t1 >= 0.0) && (t2 >= 0.0))
            return SV.RecursiveHullCheck(hull, node.children[0], p1f, p2f, p1, p2, trace);
        if ((t1 < 0.0) && (t2 < 0.0))
            return SV.RecursiveHullCheck(hull, node.children[1], p1f, p2f, p1, p2, trace);

        var frac = (t1 + (t1 < 0.0 ? 0.03125 : -0.03125)) / (t1 - t2);
        if (frac < 0.0)
            frac = 0.0;
        else if (frac > 1.0)
            frac = 1.0;

        var midf = p1f + (p2f - p1f) * frac;
        var mid = Vec.of(
            p1[0] + frac * (p2[0] - p1[0]),
            p1[1] + frac * (p2[1] - p1[1]),
            p1[2] + frac * (p2[2] - p1[2])
        );
        var side = t1 < 0.0 ? 1 : 0;

        if (!SV.RecursiveHullCheck(hull, node.children[side], p1f, midf, p1, mid, trace))
            return false;

        if (SV.HullPointContents(hull, node.children[1 - side], mid) != ModContents.solid)
            return SV.RecursiveHullCheck(hull, node.children[1 - side], midf, p2f, mid, p2, trace);

        if (trace.allsolid)
            return false;

        if (side == 0) {
            trace.plane.normal = plane.normal.copy();
            trace.plane.dist = plane.dist;
        } else {
            trace.plane.normal = Vec.of(-plane.normal[0], -plane.normal[1], -plane.normal[2]);
            trace.plane.dist = -plane.dist;
        }

        while (SV.HullPointContents(hull, hull.firstclipnode, mid) == ModContents.solid) {
            frac -= 0.1;
            if (frac < 0.0) {
                trace.fraction = midf;
                trace.endpos = mid.copy();
                Console.DPrint('backup past 0\n');
                return false;
            }
            midf = p1f + (p2f - p1f) * frac;
            mid[0] = p1[0] + frac * (p2[0] - p1[0]);
            mid[1] = p1[1] + frac * (p2[1] - p1[1]);
            mid[2] = p1[2] + frac * (p2[2] - p1[2]);
        }

        trace.fraction = midf;
        trace.endpos = mid.copy();
        return false;
    }

    static function ClipMoveToEntity(ent:Edict, start:Vec, mins:Vec, maxs:Vec, end:Vec):MTrace {
        var trace = new MTrace();
        trace.fraction = 1.0;
        trace.allsolid = true;
        trace.endpos = end.copy();
        trace.plane = {
            var p = new Plane();
            p.normal = Vec.of(0.0, 0.0, 0.0);
            p.dist = 0.0;
            p;
        };

        var offset = new Vec();
        var hull = SV.HullForEntity(ent, mins, maxs, offset);
        SV.RecursiveHullCheck(hull, hull.firstclipnode, 0.0, 1.0,
            Vec.of(start[0] - offset[0], start[1] - offset[1], start[2] - offset[2]),
            Vec.of(end[0] - offset[0], end[1] - offset[1], end[2] - offset[2]), trace);
        if (trace.fraction != 1.0) {
            trace.endpos[0] += offset[0];
            trace.endpos[1] += offset[1];
            trace.endpos[2] += offset[2];
        }
        if ((trace.fraction < 1.0) || (trace.startsolid))
            trace.ent = ent;
        return trace;
    }

    static function ClipToLinks(node:MAreaNode, clip:MMoveClip):Void {
        var l = node.solid_edicts.next;
        while (l != node.solid_edicts) {
            var touch = l.ent;
            l = l.next;
            var solid = touch.v.solid;
            if ((solid == SolidType.not) || (touch == clip.passedict))
                continue;
            if (solid == SolidType.trigger)
                Sys.Error('Trigger in clipping list');
            if ((clip.type == ClipType.nomonsters) && (solid != SolidType.bsp))
                continue;
            if ((clip.boxmins[0] > touch.v.absmax) ||
                (clip.boxmins[1] > touch.v.absmax1) ||
                (clip.boxmins[2] > touch.v.absmax2) ||
                (clip.boxmaxs[0] < touch.v.absmin) ||
                (clip.boxmaxs[1] < touch.v.absmin1) ||
                (clip.boxmaxs[2] < touch.v.absmin2))
                continue;
            if (clip.passedict != null) {
                if ((clip.passedict.v.size != 0.0) && (touch.v.size == 0.0))
                    continue;
            }
            if (clip.trace.allsolid)
                return;
            if (clip.passedict != null) {
                if (SV.server.edicts[touch.v.owner] == clip.passedict)
                    continue;
                if (SV.server.edicts[clip.passedict.v.owner] == touch)
                    continue;
            }
            var trace;
            if ((touch.flags & EntFlag.monster) != 0)
                trace = SV.ClipMoveToEntity(touch, clip.start, clip.mins2, clip.maxs2, clip.end);
            else
                trace = SV.ClipMoveToEntity(touch, clip.start, clip.mins, clip.maxs, clip.end);
            if ((trace.allsolid) || (trace.startsolid) || (trace.fraction < clip.trace.fraction)) {
                trace.ent = touch;
                clip.trace = trace;
                if (trace.startsolid)
                    clip.trace.startsolid = true;
            }
        }
        if (node.axis == -1)
            return;
        if (clip.boxmaxs[node.axis] > node.dist)
            SV.ClipToLinks(node.children[0], clip);
        if (clip.boxmins[node.axis] < node.dist)
            SV.ClipToLinks(node.children[1], clip);
    }

    static function Move(start:Vec, mins:Vec, maxs:Vec, end:Vec, type:Int, passedict:Edict):MTrace {
        var clip = new MMoveClip();
        clip.trace = SV.ClipMoveToEntity(SV.server.edicts[0], start, mins, maxs, end);
        clip.start = start;
        clip.end = end;
        clip.mins = mins;
        clip.maxs = maxs;
        clip.type = type;
        clip.passedict = passedict;
        clip.boxmins = new Vec();
        clip.boxmaxs = new Vec();
        if (type == ClipType.missile) {
            clip.mins2 = Vec.of(-15.0, -15.0, -15.0);
            clip.maxs2 = Vec.of(15.0, 15.0, 15.0);
        } else {
            clip.mins2 = mins.copy();
            clip.maxs2 = maxs.copy();
        }
        for (i in 0...3) {
            if (end[i] > start[i]) {
                clip.boxmins[i] = start[i] + clip.mins2[i] - 1.0;
                clip.boxmaxs[i] = end[i] + clip.maxs2[i] + 1.0;
                continue;
            }
            clip.boxmins[i] = end[i] + clip.mins2[i] - 1.0;
            clip.boxmaxs[i] = start[i] + clip.maxs2[i] + 1.0;
        }
        SV.ClipToLinks(SV.areanodes[0], clip);
        return clip.trace;
    }

    static var areanodes:Array<MAreaNode>;
}