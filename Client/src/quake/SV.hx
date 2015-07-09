package quake;

import js.html.ArrayBuffer;
import js.html.Float32Array;
import js.html.Int32Array;
import js.html.Uint8Array;
import quake.CL.ClientCmd;
import quake.ED.Edict;
import quake.Host.HClient;
import quake.Mod.MAreaNode;
import quake.Mod.MClipNode;
import quake.Mod.MHull;
import quake.Mod.MLink;
import quake.Mod.MModel;
import quake.Mod.MMoveClip;
import quake.Mod.MNode;
import quake.Mod.MTrace;
import quake.R.REntityState;
import quake.Protocol;

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


@:publicFields
class SV {

    static var solid = {
        not: 0,
        trigger: 1,
        bbox: 2,
        slidebox: 3,
        bsp: 4
    }

    static var damage = {
        no: 0,
        yes: 1,
        aim: 2
    }

    static var fl = {
        fly: 1,
        swim: 2,
        conveyor: 4,
        client: 8,
        inwater: 16,
        monster: 32,
        godmode: 64,
        notarget: 128,
        item: 256,
        onground: 512,
        partialground: 1024,
        waterjump: 2048,
        jumpreleased: 4096
    }

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
        datagram.WriteCoord(entity.v_float[PR.entvars.origin] + 0.5 *
            (entity.v_float[PR.entvars.mins] + entity.v_float[PR.entvars.maxs]));
        datagram.WriteCoord(entity.v_float[PR.entvars.origin1] + 0.5 *
            (entity.v_float[PR.entvars.mins1] + entity.v_float[PR.entvars.maxs1]));
        datagram.WriteCoord(entity.v_float[PR.entvars.origin2] + 0.5 *
            (entity.v_float[PR.entvars.mins2] + entity.v_float[PR.entvars.maxs2]));
    }

    static function SendServerinfo(client:HClient) {
        var message = client.message;
        message.WriteByte(SVC.print);
        message.WriteString(String.fromCharCode(2) + '\nVERSION 1.09 SERVER (' + PR.crc + ' CRC)');
        message.WriteByte(SVC.serverinfo);
        message.WriteLong(Protocol.version);
        message.WriteByte(SV.svs.maxclients);
        message.WriteByte(((Host.coop.value == 0) && (Host.deathmatch.value != 0)) ? 1 : 0);
        message.WriteString(PR.GetString(SV.server.edicts[0].v_int[PR.entvars.message]));
        for (i in 1...SV.server.model_precache.length)
            message.WriteString(SV.server.model_precache[i]);
        message.WriteByte(0);
        for (i in 1...SV.server.sound_precache.length)
            message.WriteString(SV.server.sound_precache[i]);
        message.WriteByte(0);
        message.WriteByte(SVC.cdtrack);
        message.WriteByte(Std.int(SV.server.edicts[0].v_float[PR.entvars.sounds]));
        message.WriteByte(Std.int(SV.server.edicts[0].v_float[PR.entvars.sounds]));
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
        client.wishdir = [0.0, 0.0, 0.0];
        client.message.cursize = 0;
        client.edict = SV.server.edicts[clientnum + 1];
        client.edict.v_int[PR.entvars.netname] = PR.netnames + (clientnum << 5);
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
            PR.ExecuteProgram(PR.globals_int[PR.globalvars.SetNewParms]);
            for (i in 0...16)
                client.spawn_parms[i] = PR.globals_float[PR.globalvars.parms + i];
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
        SV.FatPVS([
            clent.v_float[PR.entvars.origin] + clent.v_float[PR.entvars.view_ofs],
            clent.v_float[PR.entvars.origin1] + clent.v_float[PR.entvars.view_ofs1],
            clent.v_float[PR.entvars.origin2] + clent.v_float[PR.entvars.view_ofs2]
        ]);
        var pvs = SV.fatpvs;
        for (e in 1...SV.server.num_edicts) {
            var ent = SV.server.edicts[e];
            if (ent != clent) {
                if ((ent.v_float[PR.entvars.modelindex] == 0.0) || (PR.strings[ent.v_int[PR.entvars.model]] == 0))
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
                var miss = ent.v_float[PR.entvars.origin + i] - ent.baseline.origin[i];
                if ((miss < -0.1) || (miss > 0.1))
                    bits += U.origin1 << i;
            }
            if (ent.v_float[PR.entvars.angles] != ent.baseline.angles[0])
                bits += U.angle1;
            if (ent.v_float[PR.entvars.angles1] != ent.baseline.angles[1])
                bits += U.angle2;
            if (ent.v_float[PR.entvars.angles2] != ent.baseline.angles[2])
                bits += U.angle3;
            if (ent.v_float[PR.entvars.movetype] == MoveType.step)
                bits += U.nolerp;
            if (ent.baseline.colormap != ent.v_float[PR.entvars.colormap])
                bits += U.colormap;
            if (ent.baseline.skin != ent.v_float[PR.entvars.skin])
                bits += U.skin;
            if (ent.baseline.frame != ent.v_float[PR.entvars.frame])
                bits += U.frame;
            if (ent.baseline.effects != ent.v_float[PR.entvars.effects])
                bits += U.effects;
            if (ent.baseline.modelindex != ent.v_float[PR.entvars.modelindex])
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
                msg.WriteByte(Std.int(ent.v_float[PR.entvars.modelindex]));
            if ((bits & U.frame) != 0)
                msg.WriteByte(Std.int(ent.v_float[PR.entvars.frame]));
            if ((bits & U.colormap) != 0)
                msg.WriteByte(Std.int(ent.v_float[PR.entvars.colormap]));
            if ((bits & U.skin) != 0)
                msg.WriteByte(Std.int(ent.v_float[PR.entvars.skin]));
            if ((bits & U.effects) != 0)
                msg.WriteByte(Std.int(ent.v_float[PR.entvars.effects]));
            if ((bits & U.origin1) != 0)
                msg.WriteCoord(Std.int(ent.v_float[PR.entvars.origin]));
            if ((bits & U.angle1) != 0)
                msg.WriteAngle(Std.int(ent.v_float[PR.entvars.angles]));
            if ((bits & U.origin2) != 0)
                msg.WriteCoord(Std.int(ent.v_float[PR.entvars.origin1]));
            if ((bits & U.angle2) != 0)
                msg.WriteAngle(Std.int(ent.v_float[PR.entvars.angles1]));
            if ((bits & U.origin3) != 0)
                msg.WriteCoord(Std.int(ent.v_float[PR.entvars.origin2]));
            if ((bits & U.angle3) != 0)
                msg.WriteAngle(Std.int(ent.v_float[PR.entvars.angles2]));
        }
    }

    static function WriteClientdataToMessage(ent:Edict, msg:MSG):Void {
        if ((ent.v_float[PR.entvars.dmg_take] != 0.0) || (ent.v_float[PR.entvars.dmg_save] != 0.0)) {
            var other = SV.server.edicts[ent.v_int[PR.entvars.dmg_inflictor]];
            msg.WriteByte(SVC.damage);
            msg.WriteByte(Std.int(ent.v_float[PR.entvars.dmg_save]));
            msg.WriteByte(Std.int(ent.v_float[PR.entvars.dmg_take]));
            msg.WriteCoord(other.v_float[PR.entvars.origin] + 0.5 * (other.v_float[PR.entvars.mins] + other.v_float[PR.entvars.maxs]));
            msg.WriteCoord(other.v_float[PR.entvars.origin1] + 0.5 * (other.v_float[PR.entvars.mins1] + other.v_float[PR.entvars.maxs1]));
            msg.WriteCoord(other.v_float[PR.entvars.origin2] + 0.5 * (other.v_float[PR.entvars.mins2] + other.v_float[PR.entvars.maxs2]));
            ent.v_float[PR.entvars.dmg_take] = 0.0;
            ent.v_float[PR.entvars.dmg_save] = 0.0;
        }

        SV.SetIdealPitch();

        if (ent.v_float[PR.entvars.fixangle] != 0.0) {
            msg.WriteByte(SVC.setangle);
            msg.WriteAngle(ent.v_float[PR.entvars.angles]);
            msg.WriteAngle(ent.v_float[PR.entvars.angles1]);
            msg.WriteAngle(ent.v_float[PR.entvars.angles2]);
            ent.v_float[PR.entvars.fixangle] = 0.0;
        };

        var bits = SU.items + SU.weapon;
        if (ent.v_float[PR.entvars.view_ofs2] != Protocol.default_viewheight)
            bits += SU.viewheight;
        if (ent.v_float[PR.entvars.idealpitch] != 0.0)
            bits += SU.idealpitch;

        var val = PR.entvars.items2, items;
        if (val != null) {
            if (ent.v_float[val] != 0.0)
                items = Std.int(ent.items) + ((Std.int(ent.v_float[val]) << 23) >>> 0);
            else
                items = Std.int(ent.items) + ((Std.int(PR.globals_float[PR.globalvars.serverflags]) << 28) >>> 0);
        } else
            items = Std.int(ent.items) + ((Std.int(PR.globals_float[PR.globalvars.serverflags]) << 28) >>> 0);

        if ((ent.flags & SV.fl.onground) != 0)
            bits += SU.onground;
        if (ent.v_float[PR.entvars.waterlevel] >= 2.0)
            bits += SU.inwater;

        if (ent.v_float[PR.entvars.punchangle] != 0.0)
            bits += SU.punch1;
        if (ent.v_float[PR.entvars.velocity] != 0.0)
            bits += SU.velocity1;
        if (ent.v_float[PR.entvars.punchangle1] != 0.0)
            bits += SU.punch2;
        if (ent.v_float[PR.entvars.velocity1] != 0.0)
            bits += SU.velocity2;
        if (ent.v_float[PR.entvars.punchangle2] != 0.0)
            bits += SU.punch3;
        if (ent.v_float[PR.entvars.velocity2] != 0.0)
            bits += SU.velocity3;

        if (ent.v_float[PR.entvars.weaponframe] != 0.0)
            bits += SU.weaponframe;
        if (ent.v_float[PR.entvars.armorvalue] != 0.0)
            bits += SU.armor;

        msg.WriteByte(SVC.clientdata);
        msg.WriteShort(bits);
        if ((bits & SU.viewheight) != 0)
            msg.WriteChar(Std.int(ent.v_float[PR.entvars.view_ofs2]));
        if ((bits & SU.idealpitch) != 0)
            msg.WriteChar(Std.int(ent.v_float[PR.entvars.idealpitch]));

        if ((bits & SU.punch1) != 0)
            msg.WriteChar(Std.int(ent.v_float[PR.entvars.punchangle]));
        if ((bits & SU.velocity1) != 0)
            msg.WriteChar(Std.int(ent.v_float[PR.entvars.velocity] * 0.0625));
        if ((bits & SU.punch2) != 0)
            msg.WriteChar(Std.int(ent.v_float[PR.entvars.punchangle1]));
        if ((bits & SU.velocity2) != 0)
            msg.WriteChar(Std.int(ent.v_float[PR.entvars.velocity1] * 0.0625));
        if ((bits & SU.punch3) != 0)
            msg.WriteChar(Std.int(ent.v_float[PR.entvars.punchangle2]));
        if ((bits & SU.velocity3) != 0)
            msg.WriteChar(Std.int(ent.v_float[PR.entvars.velocity2] * 0.0625));

        msg.WriteLong(items);
        if ((bits & SU.weaponframe) != 0)
            msg.WriteByte(Std.int(ent.v_float[PR.entvars.weaponframe]));
        if ((bits & SU.armor) != 0)
            msg.WriteByte(Std.int(ent.v_float[PR.entvars.armorvalue]));
        msg.WriteByte(SV.ModelIndex(PR.GetString(ent.v_int[PR.entvars.weaponmodel])));
        msg.WriteShort(Std.int(ent.v_float[PR.entvars.health]));
        msg.WriteByte(Std.int(ent.v_float[PR.entvars.currentammo]));
        msg.WriteByte(Std.int(ent.v_float[PR.entvars.ammo_shells]));
        msg.WriteByte(Std.int(ent.v_float[PR.entvars.ammo_nails]));
        msg.WriteByte(Std.int(ent.v_float[PR.entvars.ammo_rockets]));
        msg.WriteByte(Std.int(ent.v_float[PR.entvars.ammo_cells]));
        if (COM.standard_quake)
            msg.WriteByte(Std.int(ent.v_float[PR.entvars.weapon]));
        else {
            var weapon = Std.int(ent.v_float[PR.entvars.weapon]);
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
            SZ.Write(msg, new Uint8Array(SV.server.datagram.data), SV.server.datagram.cursize);
        if (NET.SendUnreliableMessage(client.netconnection, msg) == -1) {
            Host.DropClient(true);
            return false;
        }
        return true;
    }

    static function UpdateToReliableMessages() {

        for (i in 0...SV.svs.maxclients) {
            Host.client = SV.svs.clients[i];
            Host.client.edict.v_float[PR.entvars.frags] = Std.int(Host.client.edict.v_float[PR.entvars.frags]) >> 0;
            var frags = Std.int(Host.client.edict.v_float[PR.entvars.frags]);
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
                SZ.Write(client.message, new Uint8Array(SV.server.reliable_datagram.data), SV.server.reliable_datagram.cursize);
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
            SV.server.edicts[i].v_float[PR.entvars.effects] = Std.int(SV.server.edicts[i].v_float[PR.entvars.effects]) & (~Mod.effects.muzzleflash >>> 0);
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
            if ((i > SV.svs.maxclients) && (svent.v_int[PR.entvars.modelindex] == 0))
                continue;
            var baseline = svent.baseline;
            baseline.origin = ED.Vector(svent, PR.entvars.origin);
            baseline.angles = ED.Vector(svent, PR.entvars.angles);
            baseline.frame = Std.int(svent.v_float[PR.entvars.frame]);
            baseline.skin = Std.int(svent.v_float[PR.entvars.skin]);
            if ((i > 0) && (i <= SV.svs.maxclients)) {
                baseline.colormap = i;
                baseline.modelindex = player;
            } else {
                baseline.colormap = 0;
                baseline.modelindex = SV.ModelIndex(PR.GetString(svent.v_int[PR.entvars.model]));
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
        SV.svs.serverflags = Std.int(PR.globals_float[PR.globalvars.serverflags]);
        for (i in 0...SV.svs.maxclients) {
            Host.client = SV.svs.clients[i];
            if (!Host.client.active)
                continue;
            PR.globals_int[PR.globalvars.self] = Host.client.edict.num;
            PR.ExecuteProgram(PR.globals_int[PR.globalvars.SetChangeParms]);
            for (j in 0...16)
                Host.client.spawn_parms[j] = PR.globals_float[PR.globalvars.parms + j];
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
        for (i in 0...Def.max_edicts) {
            var ed = {
                var e = new Edict();
                e.num = i;
                e.free = false;
                e.area = new MLink();
                e.leafnums = [];
                e.baseline = new REntityState();
                e.freetime = 0.0;
                e.v = new ArrayBuffer(PR.entityfields << 2);
                e;
            };
            ed.area.ent = ed;
            ed.v_float = new Float32Array(ed.v);
            ed.v_int = new Int32Array(ed.v);
            SV.server.edicts[i] = ed;
        }

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
        ent.v_int[PR.entvars.model] = PR.NewString(SV.server.modelname, 64);
        ent.v_float[PR.entvars.modelindex] = 1.0;
        ent.v_float[PR.entvars.solid] = SV.solid.bsp;
        ent.v_float[PR.entvars.movetype] = MoveType.push;

        if (Host.coop.value != 0)
            PR.globals_float[PR.globalvars.coop] = Host.coop.value;
        else
            PR.globals_float[PR.globalvars.deathmatch] = Host.deathmatch.value;

        PR.globals_int[PR.globalvars.mapname] = PR.NewString(server, 64);
        PR.globals_float[PR.globalvars.serverflags] = SV.svs.serverflags;
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
            Host.client.edict.v_int[PR.entvars.netname] = PR.netnames + (i << 5);
            SV.SendServerinfo(Host.client);
        }
        Console.DPrint('Server spawned.\n');
    }

    static function GetClientName(client):String {
        return PR.GetString(PR.netnames + (client.num << 5));
    }

    static function SetClientName(client, name:String):Void {
        var ofs = PR.netnames + (client.num << 5), i;
        for (i in 0...name.length)
            PR.strings[ofs + i] = name.charCodeAt(i);
        PR.strings[ofs + i] = 0;
    }

    // move

    static function CheckBottom(ent:Edict):Bool {
        var mins = [
            ent.v_float[PR.entvars.origin] + ent.v_float[PR.entvars.mins],
            ent.v_float[PR.entvars.origin1] + ent.v_float[PR.entvars.mins1],
            ent.v_float[PR.entvars.origin2] + ent.v_float[PR.entvars.mins2]
        ];
        var maxs = [
            ent.v_float[PR.entvars.origin] + ent.v_float[PR.entvars.maxs],
            ent.v_float[PR.entvars.origin1] + ent.v_float[PR.entvars.maxs1],
            ent.v_float[PR.entvars.origin2] + ent.v_float[PR.entvars.maxs2]
        ];
        while (true) {
            if (SV.PointContents([mins[0], mins[1], mins[2] - 1.0]) != ModContents.solid)
                break;
            if (SV.PointContents([mins[0], maxs[1], mins[2] - 1.0]) != ModContents.solid)
                break;
            if (SV.PointContents([maxs[0], mins[1], mins[2] - 1.0]) != ModContents.solid)
                break;
            if (SV.PointContents([maxs[0], maxs[1], mins[2] - 1.0]) != ModContents.solid)
                break;
            return true;
        }
        var start = [(mins[0] + maxs[0]) * 0.5, (mins[1] + maxs[1]) * 0.5, mins[2]];
        var stop = [start[0], start[1], start[2] - 36.0];
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
        var oldorg = ED.Vector(ent, PR.entvars.origin);
        var neworg = [];
        var mins = ED.Vector(ent, PR.entvars.mins), maxs = ED.Vector(ent, PR.entvars.maxs);
        var trace;
        if ((ent.flags & (SV.fl.swim + SV.fl.fly)) != 0) {
            var enemy = ent.v_int[PR.entvars.enemy];
            for (i in 0...2) {
                neworg[0] = ent.v_float[PR.entvars.origin] + move[0];
                neworg[1] = ent.v_float[PR.entvars.origin1] + move[1];
                neworg[2] = ent.v_float[PR.entvars.origin2];
                if ((i == 0) && (enemy != 0)) {
                    var dz = ent.v_float[PR.entvars.origin2] - SV.server.edicts[enemy].v_float[PR.entvars.origin2];
                    if (dz > 40.0)
                        neworg[2] -= 8.0;
                    else if (dz < 30.0)
                        neworg[2] += 8.0;
                }
                trace = SV.Move(ED.Vector(ent, PR.entvars.origin), mins, maxs, neworg, 0, ent);
                if (trace.fraction == 1.0) {
                    if (((ent.flags & SV.fl.swim) != 0) && (SV.PointContents(trace.endpos) == ModContents.empty))
                        return false;
                    ent.v_float[PR.entvars.origin] = trace.endpos[0];
                    ent.v_float[PR.entvars.origin1] = trace.endpos[1];
                    ent.v_float[PR.entvars.origin2] = trace.endpos[2];
                    if (relink)
                        SV.LinkEdict(ent, true);
                    return true;
                }
                if (enemy == 0)
                    return false;
            }
            return false;
        }
        neworg[0] = ent.v_float[PR.entvars.origin] + move[0];
        neworg[1] = ent.v_float[PR.entvars.origin1] + move[1];
        neworg[2] = ent.v_float[PR.entvars.origin2] + 18.0;
        var end = [neworg[0], neworg[1], neworg[2] - 36.0];
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
            if ((ent.flags & SV.fl.partialground) == 0)
                return false;
            ent.v_float[PR.entvars.origin] += move[0];
            ent.v_float[PR.entvars.origin1] += move[1];
            if (relink)
                SV.LinkEdict(ent, true);
            ent.flags = ent.flags & (~SV.fl.onground >>> 0);
            return true;
        }
        ent.v_float[PR.entvars.origin] = trace.endpos[0];
        ent.v_float[PR.entvars.origin1] = trace.endpos[1];
        ent.v_float[PR.entvars.origin2] = trace.endpos[2];
        if (!SV.CheckBottom(ent)) {
            if ((ent.flags & SV.fl.partialground) != 0) {
                if (relink)
                    SV.LinkEdict(ent, true);
                return true;
            }
            ent.v_float[PR.entvars.origin] = oldorg[0];
            ent.v_float[PR.entvars.origin1] = oldorg[1];
            ent.v_float[PR.entvars.origin2] = oldorg[2];
            return false;
        }
        ent.flags = ent.flags & (~SV.fl.partialground >>> 0);
        ent.v_int[PR.entvars.groundentity] = trace.ent.num;
        if (relink)
            SV.LinkEdict(ent, true);
        return true;
    }

    static function StepDirection(ent:Edict, yaw:Float, dist:Float):Bool {
        ent.v_float[PR.entvars.ideal_yaw] = yaw;
        PF.changeyaw();
        yaw *= Math.PI / 180.0;
        var oldorigin = ED.Vector(ent, PR.entvars.origin);
        if (SV.movestep(ent, [Math.cos(yaw) * dist, Math.sin(yaw) * dist], false)) {
            var delta = ent.v_float[PR.entvars.angles1] - ent.v_float[PR.entvars.ideal_yaw];
            if ((delta > 45.0) && (delta < 315.0))
                ED.SetVector(ent, PR.entvars.origin, oldorigin);
            SV.LinkEdict(ent, true);
            return true;
        }
        SV.LinkEdict(ent, true);
        return false;
    }

    static function NewChaseDir(actor:Edict, enemy:Edict, dist:Float):Void {
        var olddir = Vec.Anglemod(Std.int(actor.v_float[PR.entvars.ideal_yaw] / 45.0) * 45.0);
        var turnaround = Vec.Anglemod(olddir - 180.0);
        var deltax = enemy.v_float[PR.entvars.origin] - actor.v_float[PR.entvars.origin];
        var deltay = enemy.v_float[PR.entvars.origin1] - actor.v_float[PR.entvars.origin1];
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
        actor.v_float[PR.entvars.ideal_yaw] = olddir;
        if (!SV.CheckBottom(actor))
            actor.flags = actor.flags | SV.fl.partialground;
    }

    static function CloseEnough(ent:Edict, goal:Edict, dist:Float):Bool {
        for (i in 0...3) {
            if (goal.v_float[PR.entvars.absmin + i] > (ent.v_float[PR.entvars.absmax + i] + dist))
                return false;
            if (goal.v_float[PR.entvars.absmax + i] < (ent.v_float[PR.entvars.absmin + i] - dist))
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
            switch (check.v_float[PR.entvars.movetype]) {
                case MoveType.push | MoveType.none | MoveType.noclip:
                    continue;
            }
            if (SV.TestEntityPosition(check))
                Console.Print('entity in invalid position\n');
        }
    }

    static function CheckVelocity(ent:Edict) {
        for (i in 0...3) {
            var velocity = ent.v_float[PR.entvars.velocity + i];
            if (Math.isNaN(velocity)) {
                Console.Print('Got a NaN velocity on ' + PR.GetString(ent.v_int[PR.entvars.classname]) + '\n');
                velocity = 0.0;
            }
            if (Math.isNaN(ent.v_float[PR.entvars.origin + i])) {
                Console.Print('Got a NaN origin on ' + PR.GetString(ent.v_int[PR.entvars.classname]) + '\n');
                ent.v_float[PR.entvars.origin + i] = 0.0;
            }
            if (velocity > SV.maxvelocity.value)
                velocity = SV.maxvelocity.value;
            else if (velocity < -SV.maxvelocity.value)
                velocity = -SV.maxvelocity.value;
            ent.v_float[PR.entvars.velocity + i] = velocity;
        }
    }

    static function RunThink(ent:Edict) {
        var thinktime = ent.v_float[PR.entvars.nextthink];
        if ((thinktime <= 0.0) || (thinktime > (SV.server.time + Host.frametime)))
            return true;
        if (thinktime < SV.server.time)
            thinktime = SV.server.time;
        ent.v_float[PR.entvars.nextthink] = 0.0;
        PR.globals_float[PR.globalvars.time] = thinktime;
        PR.globals_int[PR.globalvars.self] = ent.num;
        PR.globals_int[PR.globalvars.other] = 0;
        PR.ExecuteProgram(ent.v_int[PR.entvars.think]);
        return !ent.free;
    }

    static function Impact(e1:Edict, e2:Edict):Void {
        var old_self = PR.globals_int[PR.globalvars.self];
        var old_other = PR.globals_int[PR.globalvars.other];
        PR.globals_float[PR.globalvars.time] = SV.server.time;

        if ((e1.v_int[PR.entvars.touch] != 0) && (e1.v_float[PR.entvars.solid] != SV.solid.not)) {
            PR.globals_int[PR.globalvars.self] = e1.num;
            PR.globals_int[PR.globalvars.other] = e2.num;
            PR.ExecuteProgram(e1.v_int[PR.entvars.touch]);
        }
        if ((e2.v_int[PR.entvars.touch] != 0) && (e2.v_float[PR.entvars.solid] != SV.solid.not)) {
            PR.globals_int[PR.globalvars.self] = e2.num;
            PR.globals_int[PR.globalvars.other] = e1.num;
            PR.ExecuteProgram(e2.v_int[PR.entvars.touch]);
        }

        PR.globals_int[PR.globalvars.self] = old_self;
        PR.globals_int[PR.globalvars.other] = old_other;
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
        var planes = [], plane;
        var primal_velocity = ED.Vector(ent, PR.entvars.velocity);
        var original_velocity = ED.Vector(ent, PR.entvars.velocity);
        var new_velocity = [];
        var i, j;
        var trace;
        var end = [];
        var time_left = time;
        var blocked = 0;
        for (bumpcount in 0...4) {
            if ((ent.v_float[PR.entvars.velocity] == 0.0) &&
                (ent.v_float[PR.entvars.velocity1] == 0.0) &&
                (ent.v_float[PR.entvars.velocity2] == 0.0))
                break;
            end[0] = ent.v_float[PR.entvars.origin] + time_left * ent.v_float[PR.entvars.velocity];
            end[1] = ent.v_float[PR.entvars.origin1] + time_left * ent.v_float[PR.entvars.velocity1];
            end[2] = ent.v_float[PR.entvars.origin2] + time_left * ent.v_float[PR.entvars.velocity2];
            trace = SV.Move(ED.Vector(ent, PR.entvars.origin), ED.Vector(ent, PR.entvars.mins), ED.Vector(ent, PR.entvars.maxs), end, 0, ent);
            if (trace.allsolid) {
                ED.SetVector(ent, PR.entvars.velocity, Vec.origin);
                return 3;
            }
            if (trace.fraction > 0.0) {
                ED.SetVector(ent, PR.entvars.origin, trace.endpos);
                original_velocity = ED.Vector(ent, PR.entvars.velocity);
                numplanes = 0;
                if (trace.fraction == 1.0)
                    break;
            }
            if (trace.ent == null)
                Sys.Error('SV.FlyMove: !trace.ent');
            if (trace.plane.normal[2] > 0.7) {
                blocked |= 1;
                if (trace.ent.v_float[PR.entvars.solid] == SV.solid.bsp) {
                    ent.flags = ent.flags | SV.fl.onground;
                    ent.v_int[PR.entvars.groundentity] = trace.ent.num;
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
                ED.SetVector(ent, PR.entvars.velocity, Vec.origin);
                return 3;
            }
            planes[numplanes++] = [trace.plane.normal[0], trace.plane.normal[1], trace.plane.normal[2]];
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
                ED.SetVector(ent, PR.entvars.velocity, new_velocity);
            else {
                if (numplanes != 2) {
                    ED.SetVector(ent, PR.entvars.velocity, Vec.origin);
                    return 7;
                }
                dir = Vec.CrossProduct(planes[0], planes[1]);
                d = dir[0] * ent.v_float[PR.entvars.velocity] +
                    dir[1] * ent.v_float[PR.entvars.velocity1] +
                    dir[2] * ent.v_float[PR.entvars.velocity2];
                ent.v_float[PR.entvars.velocity] = dir[0] * d;
                ent.v_float[PR.entvars.velocity1] = dir[1] * d;
                ent.v_float[PR.entvars.velocity2] = dir[2] * d;
            }
            if ((ent.v_float[PR.entvars.velocity] * primal_velocity[0] +
                ent.v_float[PR.entvars.velocity1] * primal_velocity[1] +
                ent.v_float[PR.entvars.velocity2] * primal_velocity[2]) <= 0.0) {
                ED.SetVector(ent, PR.entvars.velocity, Vec.origin);
                return blocked;
            }
        }
        return blocked;
    }

    static function AddGravity(ent:Edict) {
        var val = PR.entvars.gravity, ent_gravity;
        if (val != null)
            ent_gravity = (ent.v_float[val] != 0.0) ? ent.v_float[val] : 1.0;
        else
            ent_gravity = 1.0;
        ent.v_float[PR.entvars.velocity2] -= ent_gravity * SV.gravity.value * Host.frametime;
    }

    static function PushEntity(ent:Edict, push) {
        var end = [
            ent.v_float[PR.entvars.origin] + push[0],
            ent.v_float[PR.entvars.origin1] + push[1],
            ent.v_float[PR.entvars.origin2] + push[2]
        ];
        var nomonsters;
        var solid = ent.v_float[PR.entvars.solid];
        if (ent.v_float[PR.entvars.movetype] == MoveType.flymissile)
            nomonsters = SV.move.missile;
        else if ((solid == SV.solid.trigger) || (solid == SV.solid.not))
            nomonsters = SV.move.nomonsters
        else
            nomonsters = SV.move.normal;
        var trace = SV.Move(ED.Vector(ent, PR.entvars.origin), ED.Vector(ent, PR.entvars.mins),
            ED.Vector(ent, PR.entvars.maxs), end, nomonsters, ent);
        ED.SetVector(ent, PR.entvars.origin, trace.endpos);
        SV.LinkEdict(ent, true);
        if (trace.ent != null)
            SV.Impact(ent, trace.ent);
        return trace;
    }

    static function PushMove(pusher:Edict, movetime:Float):Void {
        if ((pusher.v_float[PR.entvars.velocity] == 0.0) &&
            (pusher.v_float[PR.entvars.velocity1] == 0.0) &&
            (pusher.v_float[PR.entvars.velocity2] == 0.0)) {
            pusher.v_float[PR.entvars.ltime] += movetime;
            return;
        }
        var move = [
            pusher.v_float[PR.entvars.velocity] * movetime,
            pusher.v_float[PR.entvars.velocity1] * movetime,
            pusher.v_float[PR.entvars.velocity2] * movetime
        ];
        var mins = [
            pusher.v_float[PR.entvars.absmin] + move[0],
            pusher.v_float[PR.entvars.absmin1] + move[1],
            pusher.v_float[PR.entvars.absmin2] + move[2]
        ];
        var maxs = [
            pusher.v_float[PR.entvars.absmax] + move[0],
            pusher.v_float[PR.entvars.absmax1] + move[1],
            pusher.v_float[PR.entvars.absmax2] + move[2]
        ];
        var pushorig = ED.Vector(pusher, PR.entvars.origin);
        pusher.v_float[PR.entvars.origin] += move[0];
        pusher.v_float[PR.entvars.origin1] += move[1];
        pusher.v_float[PR.entvars.origin2] += move[2];
        pusher.v_float[PR.entvars.ltime] += movetime;
        SV.LinkEdict(pusher, false);
        var moved:Array<Dynamic> = [];
        for (e in 1...SV.server.num_edicts) {
            var check = SV.server.edicts[e];
            if (check.free)
                continue;
            var movetype = check.v_float[PR.entvars.movetype];
            if ((movetype == MoveType.push)
                || (movetype == MoveType.none)
                || (movetype == MoveType.noclip))
                continue;
            if (((check.flags & SV.fl.onground) == 0) ||
                (check.v_int[PR.entvars.groundentity] != pusher.num)) {
                if ((check.v_float[PR.entvars.absmin] >= maxs[0])
                    || (check.v_float[PR.entvars.absmin1] >= maxs[1])
                    || (check.v_float[PR.entvars.absmin2] >= maxs[2])
                    || (check.v_float[PR.entvars.absmax] <= mins[0])
                    || (check.v_float[PR.entvars.absmax1] <= mins[1])
                    || (check.v_float[PR.entvars.absmax2] <= mins[2]))
                    continue;
                if (!SV.TestEntityPosition(check))
                    continue;
            }
            if (movetype != MoveType.walk)
                check.flags = check.flags & (~SV.fl.onground) >>> 0;
            var entorig = ED.Vector(check, PR.entvars.origin);
            moved[moved.length] = [entorig[0], entorig[1], entorig[2], check];
            pusher.v_float[PR.entvars.solid] = SV.solid.not;
            SV.PushEntity(check, move);
            pusher.v_float[PR.entvars.solid] = SV.solid.bsp;
            if (SV.TestEntityPosition(check)) {
                if (check.v_float[PR.entvars.mins] == check.v_float[PR.entvars.maxs])
                    continue;
                if ((check.v_float[PR.entvars.solid] == SV.solid.not) || (check.v_float[PR.entvars.solid] == SV.solid.trigger)) {
                    check.v_float[PR.entvars.mins] = check.v_float[PR.entvars.maxs] = 0.0;
                    check.v_float[PR.entvars.mins1] = check.v_float[PR.entvars.maxs1] = 0.0;
                    check.v_float[PR.entvars.maxs2] = check.v_float[PR.entvars.mins2];
                    continue;
                }
                check.v_float[PR.entvars.origin] = entorig[0];
                check.v_float[PR.entvars.origin1] = entorig[1];
                check.v_float[PR.entvars.origin2] = entorig[2];
                SV.LinkEdict(check, true);
                pusher.v_float[PR.entvars.origin] = pushorig[0];
                pusher.v_float[PR.entvars.origin1] = pushorig[1];
                pusher.v_float[PR.entvars.origin2] = pushorig[2];
                SV.LinkEdict(pusher, false);
                pusher.v_float[PR.entvars.ltime] -= movetime;
                if (pusher.v_int[PR.entvars.blocked] != 0) {
                    PR.globals_int[PR.globalvars.self] = pusher.num;
                    PR.globals_int[PR.globalvars.other] = check.num;
                    PR.ExecuteProgram(pusher.v_int[PR.entvars.blocked]);
                }
                for (moved_edict in moved) {
                    moved_edict[3].v_float[PR.entvars.origin] = moved_edict[0];
                    moved_edict[3].v_float[PR.entvars.origin1] = moved_edict[1];
                    moved_edict[3].v_float[PR.entvars.origin2] = moved_edict[2];
                    SV.LinkEdict(moved_edict[3], false);
                }
                return;
            }
        }
    }

    static function Physics_Pusher(ent:Edict) {
        var oldltime = ent.v_float[PR.entvars.ltime];
        var thinktime = ent.v_float[PR.entvars.nextthink];
        var movetime;
        if (thinktime < (oldltime + Host.frametime)) {
            movetime = thinktime - oldltime;
            if (movetime < 0.0)
                movetime = 0.0;
        } else
            movetime = Host.frametime;
        if (movetime != 0.0)
            SV.PushMove(ent, movetime);
        if ((thinktime <= oldltime) || (thinktime > ent.v_float[PR.entvars.ltime]))
            return;
        ent.v_float[PR.entvars.nextthink] = 0.0;
        PR.globals_float[PR.globalvars.time] = SV.server.time;
        PR.globals_int[PR.globalvars.self] = ent.num;
        PR.globals_int[PR.globalvars.other] = 0;
        PR.ExecuteProgram(ent.v_int[PR.entvars.think]);
    }

    static function CheckStuck(ent:Edict) {
        if (!SV.TestEntityPosition(ent)) {
            ent.v_float[PR.entvars.oldorigin] = ent.v_float[PR.entvars.origin];
            ent.v_float[PR.entvars.oldorigin1] = ent.v_float[PR.entvars.origin1];
            ent.v_float[PR.entvars.oldorigin2] = ent.v_float[PR.entvars.origin2];
            return;
        }
        var org = ED.Vector(ent, PR.entvars.origin);
        ent.v_float[PR.entvars.origin] = ent.v_float[PR.entvars.oldorigin];
        ent.v_float[PR.entvars.origin1] = ent.v_float[PR.entvars.oldorigin1];
        ent.v_float[PR.entvars.origin2] = ent.v_float[PR.entvars.oldorigin2];
        if (!SV.TestEntityPosition(ent)) {
            Console.DPrint('Unstuck.\n');
            SV.LinkEdict(ent, true);
            return;
        }
        for (z in 0...18) {
            for (i in -1...2) {
                for (j in -1...2) {
                    ent.v_float[PR.entvars.origin] = org[0] + i;
                    ent.v_float[PR.entvars.origin1] = org[1] + j;
                    ent.v_float[PR.entvars.origin2] = org[2] + z;
                    if (!SV.TestEntityPosition(ent)) {
                        Console.DPrint('Unstuck.\n');
                        SV.LinkEdict(ent, true);
                        return;
                    }
                }
            }
        }
        ED.SetVector(ent, PR.entvars.origin, org);
        Console.DPrint('player is stuck.\n');
    }

    static function CheckWater(ent:Edict):Bool {
        var point = [
            ent.v_float[PR.entvars.origin],
            ent.v_float[PR.entvars.origin1],
            ent.v_float[PR.entvars.origin2] + ent.v_float[PR.entvars.mins2] + 1.0
        ];
        ent.v_float[PR.entvars.waterlevel] = 0.0;
        ent.v_float[PR.entvars.watertype] = ModContents.empty;
        var cont = SV.PointContents(point);
        if (cont > ModContents.water)
            return false;
        ent.v_float[PR.entvars.watertype] = cont;
        ent.v_float[PR.entvars.waterlevel] = 1.0;
        point[2] = ent.v_float[PR.entvars.origin2] + (ent.v_float[PR.entvars.mins2] + ent.v_float[PR.entvars.maxs2]) * 0.5;
        cont = SV.PointContents(point);
        if (cont <= ModContents.water) {
            ent.v_float[PR.entvars.waterlevel] = 2.0;
            point[2] = ent.v_float[PR.entvars.origin2] + ent.v_float[PR.entvars.view_ofs2];
            cont = SV.PointContents(point);
            if (cont <= ModContents.water)
                ent.v_float[PR.entvars.waterlevel] = 3.0;
        }
        return ent.v_float[PR.entvars.waterlevel] > 1.0;
    }

    static function WallFriction(ent:Edict, trace:MTrace):Void {
        var forward = [];
        Vec.AngleVectors(ED.Vector(ent, PR.entvars.v_angle), forward);
        var normal = trace.plane.normal;
        var d = normal[0] * forward[0] + normal[1] * forward[1] + normal[2] * forward[2] + 0.5;
        if (d >= 0.0)
            return;
        d += 1.0;
        var i = normal[0] * ent.v_float[PR.entvars.velocity]
            + normal[1] * ent.v_float[PR.entvars.velocity1]
            + normal[2] * ent.v_float[PR.entvars.velocity2];
        ent.v_float[PR.entvars.velocity] = (ent.v_float[PR.entvars.velocity] - normal[0] * i) * d; 
        ent.v_float[PR.entvars.velocity1] = (ent.v_float[PR.entvars.velocity1] - normal[1] * i) * d; 
    }

    static function TryUnstick(ent:Edict, oldvel:Vec):Int {
        var oldorg = ED.Vector(ent, PR.entvars.origin);
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
            ent.v_float[PR.entvars.velocity] = oldvel[0];
            ent.v_float[PR.entvars.velocity1] = oldvel[1];
            ent.v_float[PR.entvars.velocity2] = 0.0;
            var clip = SV.FlyMove(ent, 0.1);
            if ((Math.abs(oldorg[1] - ent.v_float[PR.entvars.origin1]) > 4.0)
                || (Math.abs(oldorg[0] - ent.v_float[PR.entvars.origin]) > 4.0))
                return clip;
            ED.SetVector(ent, PR.entvars.origin, oldorg);
        }
        ED.SetVector(ent, PR.entvars.velocity, Vec.origin);
        return 7;
    }

    static function WalkMove(ent:Edict) {
        var oldonground = ent.flags & SV.fl.onground;
        ent.flags = ent.flags ^ oldonground;
        var oldorg = ED.Vector(ent, PR.entvars.origin);
        var oldvel = ED.Vector(ent, PR.entvars.velocity);
        var clip = SV.FlyMove(ent, Host.frametime);
        if ((clip & 2) == 0)
            return;
        if ((oldonground == 0) && (ent.v_float[PR.entvars.waterlevel] == 0.0))
            return;
        if (ent.v_float[PR.entvars.movetype] != MoveType.walk)
            return;
        if (SV.nostep.value != 0)
            return;
        if ((SV.player.flags & SV.fl.waterjump) != 0)
            return;
        var nosteporg = ED.Vector(ent, PR.entvars.origin);
        var nostepvel = ED.Vector(ent, PR.entvars.velocity);
        ED.SetVector(ent, PR.entvars.origin, oldorg);
        SV.PushEntity(ent, [0.0, 0.0, 18.0]);
        ent.v_float[PR.entvars.velocity] = oldvel[0];
        ent.v_float[PR.entvars.velocity1] = oldvel[1];
        ent.v_float[PR.entvars.velocity2] = 0.0;
        clip = SV.FlyMove(ent, Host.frametime);
        if (clip != 0) {
            if ((Math.abs(oldorg[1] - ent.v_float[PR.entvars.origin1]) < 0.03125)
                && (Math.abs(oldorg[0] - ent.v_float[PR.entvars.origin]) < 0.03125))
                clip = SV.TryUnstick(ent, oldvel);
            if ((clip & 2) != 0)
                SV.WallFriction(ent, SV.steptrace);
        }
        var downtrace = SV.PushEntity(ent, [0.0, 0.0, oldvel[2] * Host.frametime - 18.0]);
        if (downtrace.plane.normal[2] > 0.7) {
            if (ent.v_float[PR.entvars.solid] == SV.solid.bsp) {
                ent.flags = ent.flags | SV.fl.onground;
                ent.v_int[PR.entvars.groundentity] = downtrace.ent.num;
            }
            return;
        }
        ED.SetVector(ent, PR.entvars.origin, nosteporg);
        ED.SetVector(ent, PR.entvars.velocity, nostepvel);
    }

    static function Physics_Client(ent:Edict) {
        if (!SV.svs.clients[ent.num - 1].active)
            return;
        PR.globals_float[PR.globalvars.time] = SV.server.time;
        PR.globals_int[PR.globalvars.self] = ent.num;
        PR.ExecuteProgram(PR.globals_int[PR.globalvars.PlayerPreThink]);
        SV.CheckVelocity(ent);
        var movetype = Std.int(ent.v_float[PR.entvars.movetype]);
        if ((movetype == MoveType.toss) || (movetype == MoveType.bounce))
            SV.Physics_Toss(ent);
        else {
            if (!SV.RunThink(ent))
                return;
            switch (movetype) {
                case MoveType.none:
                case MoveType.walk:
                    if (!SV.CheckWater(ent) && (ent.flags & SV.fl.waterjump) == 0)
                        SV.AddGravity(ent);
                    SV.CheckStuck(ent);
                    SV.WalkMove(ent);
                case MoveType.fly:
                    SV.FlyMove(ent, Host.frametime);
                case MoveType.noclip:
                    ent.v_float[PR.entvars.origin] += Host.frametime * ent.v_float[PR.entvars.velocity];
                    ent.v_float[PR.entvars.origin1] += Host.frametime * ent.v_float[PR.entvars.velocity1];
                    ent.v_float[PR.entvars.origin2] += Host.frametime * ent.v_float[PR.entvars.velocity2];
                default:
                    Sys.Error('SV.Physics_Client: bad movetype ' + movetype);
            }
        }
        SV.LinkEdict(ent, true);
        PR.globals_float[PR.globalvars.time] = SV.server.time;
        PR.globals_int[PR.globalvars.self] = ent.num;
        PR.ExecuteProgram(PR.globals_int[PR.globalvars.PlayerPostThink]);
    }

    static function Physics_Noclip(ent:Edict) {
        if (!SV.RunThink(ent))
            return;
        ent.v_float[PR.entvars.angles] += Host.frametime * ent.v_float[PR.entvars.avelocity];
        ent.v_float[PR.entvars.angles1] += Host.frametime * ent.v_float[PR.entvars.avelocity1];
        ent.v_float[PR.entvars.angles2] += Host.frametime * ent.v_float[PR.entvars.avelocity2];
        ent.v_float[PR.entvars.origin] += Host.frametime * ent.v_float[PR.entvars.velocity];
        ent.v_float[PR.entvars.origin1] += Host.frametime * ent.v_float[PR.entvars.velocity1];
        ent.v_float[PR.entvars.origin2] += Host.frametime * ent.v_float[PR.entvars.velocity2];
        SV.LinkEdict(ent, false);
    }

    static function CheckWaterTransition(ent:Edict) {
        var cont = SV.PointContents(ED.Vector(ent, PR.entvars.origin));
        if (ent.v_float[PR.entvars.watertype] == 0.0) {
            ent.v_float[PR.entvars.watertype] = cont;
            ent.v_float[PR.entvars.waterlevel] = 1.0;
            return;
        }
        if (cont <= ModContents.water) {
            if (ent.v_float[PR.entvars.watertype] == ModContents.empty)
                SV.StartSound(ent, 0, 'misc/h2ohit1.wav', 255, 1.0);
            ent.v_float[PR.entvars.watertype] = cont;
            ent.v_float[PR.entvars.waterlevel] = 1.0;
            return;
        }
        if (ent.v_float[PR.entvars.watertype] != ModContents.empty)
            SV.StartSound(ent, 0, 'misc/h2ohit1.wav', 255, 1.0);
        ent.v_float[PR.entvars.watertype] = ModContents.empty;
        ent.v_float[PR.entvars.waterlevel] = cont;
    }

    static function Physics_Toss(ent:Edict) {
        if (!SV.RunThink(ent))
            return;
        if ((ent.flags & SV.fl.onground) != 0)
            return;
        SV.CheckVelocity(ent);
        var movetype = ent.v_float[PR.entvars.movetype];
        if ((movetype != MoveType.fly) && (movetype != MoveType.flymissile))
            SV.AddGravity(ent);
        ent.v_float[PR.entvars.angles] += Host.frametime * ent.v_float[PR.entvars.avelocity];
        ent.v_float[PR.entvars.angles1] += Host.frametime * ent.v_float[PR.entvars.avelocity1];
        ent.v_float[PR.entvars.angles2] += Host.frametime * ent.v_float[PR.entvars.avelocity2];
        var trace = SV.PushEntity(ent,
            [
                ent.v_float[PR.entvars.velocity] * Host.frametime,
                ent.v_float[PR.entvars.velocity1] * Host.frametime,
                ent.v_float[PR.entvars.velocity2] * Host.frametime
            ]);
        if ((trace.fraction == 1.0) || (ent.free))
            return;
        var velocity = [];
        SV.ClipVelocity(ED.Vector(ent, PR.entvars.velocity), trace.plane.normal, velocity, (movetype == MoveType.bounce) ? 1.5 : 1.0);
        ED.SetVector(ent, PR.entvars.velocity, velocity);
        if (trace.plane.normal[2] > 0.7) {
            if ((ent.v_float[PR.entvars.velocity2] < 60.0) || (movetype != MoveType.bounce)) {
                ent.flags = ent.flags | SV.fl.onground;
                ent.v_int[PR.entvars.groundentity] = trace.ent.num;
                ent.v_float[PR.entvars.velocity] = ent.v_float[PR.entvars.velocity1] = ent.v_float[PR.entvars.velocity2] = 0.0;
                ent.v_float[PR.entvars.avelocity] = ent.v_float[PR.entvars.avelocity1] = ent.v_float[PR.entvars.avelocity2] = 0.0;
            }
        }
        SV.CheckWaterTransition(ent);
    }

    static function Physics_Step(ent:Edict):Void {
        if ((ent.flags & (SV.fl.onground + SV.fl.fly + SV.fl.swim)) == 0) {
            var hitsound = (ent.v_float[PR.entvars.velocity2] < (SV.gravity.value * -0.1));
            SV.AddGravity(ent);
            SV.CheckVelocity(ent);
            SV.FlyMove(ent, Host.frametime);
            SV.LinkEdict(ent, true);
            if (((ent.flags & SV.fl.onground) != 0) && (hitsound))
                SV.StartSound(ent, 0, 'demon/dland2.wav', 255, 1.0);
        }
        SV.RunThink(ent);
        SV.CheckWaterTransition(ent);
    }

    static function Physics() {
        PR.globals_int[PR.globalvars.self] = 0;
        PR.globals_int[PR.globalvars.other] = 0;
        PR.globals_float[PR.globalvars.time] = SV.server.time;
        PR.ExecuteProgram(PR.globals_int[PR.globalvars.StartFrame]);
        for (i in 0...SV.server.num_edicts) {
            var ent = SV.server.edicts[i];
            if (ent.free)
                continue;
            if (PR.globals_float[PR.globalvars.force_retouch] != 0.0)
                SV.LinkEdict(ent, true);
            if ((i > 0) && (i <= SV.svs.maxclients)) {
                SV.Physics_Client(ent);
                continue;
            }
            switch (ent.v_float[PR.entvars.movetype]) {
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
                    Sys.Error('SV.Physics: bad movetype ' + Std.int(ent.v_float[PR.entvars.movetype]));
            }
        }
        if (PR.globals_float[PR.globalvars.force_retouch] != 0.0)
            --PR.globals_float[PR.globalvars.force_retouch];
        SV.server.time += Host.frametime;
    }

    // user

    static var player:Edict;

    static function SetIdealPitch() {
        var ent = SV.player;
        if ((ent.flags & SV.fl.onground) == 0)
            return;
        var angleval = ent.v_float[PR.entvars.angles1] * (Math.PI / 180.0);
        var sinval = Math.sin(angleval);
        var cosval = Math.cos(angleval);
        var top = [0.0, 0.0, ent.v_float[PR.entvars.origin2] + ent.v_float[PR.entvars.view_ofs2]];
        var bottom = [0.0, 0.0, top[2] - 160.0];
        var z = [];
        for (i in 0...6) {
            top[0] = bottom[0] = ent.v_float[PR.entvars.origin] + cosval * (i + 3) * 12.0;
            top[1] = bottom[1] = ent.v_float[PR.entvars.origin1] + sinval * (i + 3) * 12.0;
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
            ent.v_float[PR.entvars.idealpitch] = 0.0;
            return;
        }
        if (steps >= 2)
            ent.v_float[PR.entvars.idealpitch] = -dir * SV.idealpitchscale.value;
    }

    static function UserFriction() {
        var ent = SV.player;
        var vel0 = ent.v_float[PR.entvars.velocity], vel1 = ent.v_float[PR.entvars.velocity1];
        var speed = Math.sqrt(vel0 * vel0 + vel1 * vel1);
        if (speed == 0.0)
            return;
        var start = [
            ent.v_float[PR.entvars.origin] + vel0 / speed * 16.0,
            ent.v_float[PR.entvars.origin1] + vel1 / speed * 16.0,
            ent.v_float[PR.entvars.origin2] + ent.v_float[PR.entvars.mins2]
        ];
        var friction = SV.friction.value;
        if (SV.Move(start, Vec.origin, Vec.origin, [start[0], start[1], start[2] - 34.0], 1, ent).fraction == 1.0)
            friction *= SV.edgefriction.value;
        var newspeed = speed - Host.frametime * (speed < SV.stopspeed.value ? SV.stopspeed.value : speed) * friction;
        if (newspeed < 0.0)
            newspeed = 0.0;
        newspeed /= speed;
        ent.v_float[PR.entvars.velocity] *= newspeed;
        ent.v_float[PR.entvars.velocity1] *= newspeed;
        ent.v_float[PR.entvars.velocity2] *= newspeed;
    }

    static function Accelerate(wishvel:Vec, air:Bool) {
        var ent = SV.player;
        var wishdir = [wishvel[0], wishvel[1], wishvel[2]];
        var wishspeed = Vec.Normalize(wishdir);
        if ((air) && (wishspeed > 30.0))
            wishspeed = 30.0;
        var addspeed = wishspeed - (ent.v_float[PR.entvars.velocity] * wishdir[0]
            + ent.v_float[PR.entvars.velocity1] * wishdir[1]
            + ent.v_float[PR.entvars.velocity2] * wishdir[2]
        );
        if (addspeed <= 0.0)
            return;
        var accelspeed = SV.accelerate.value * Host.frametime * wishspeed;
        if (accelspeed > addspeed)
            accelspeed = addspeed;
        ent.v_float[PR.entvars.velocity] += accelspeed * wishdir[0];
        ent.v_float[PR.entvars.velocity1] += accelspeed * wishdir[1];
        ent.v_float[PR.entvars.velocity2] += accelspeed * wishdir[2];
    }

    static function WaterMove() {
        var ent = SV.player, cmd = Host.client.cmd;
        var forward = [], right = [];
        Vec.AngleVectors(ED.Vector(ent, PR.entvars.v_angle), forward, right);
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
        var speed = Math.sqrt(ent.v_float[PR.entvars.velocity] * ent.v_float[PR.entvars.velocity]
            + ent.v_float[PR.entvars.velocity1] * ent.v_float[PR.entvars.velocity1]
            + ent.v_float[PR.entvars.velocity2] * ent.v_float[PR.entvars.velocity2]
        ), newspeed;
        if (speed != 0.0) {
            newspeed = speed - Host.frametime * speed * SV.friction.value;
            if (newspeed < 0.0)
                newspeed = 0.0;
            scale = newspeed / speed;
            ent.v_float[PR.entvars.velocity] *= scale;
            ent.v_float[PR.entvars.velocity1] *= scale;
            ent.v_float[PR.entvars.velocity2] *= scale;
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
        ent.v_float[PR.entvars.velocity] += accelspeed * (wishvel[0] / wishspeed);
        ent.v_float[PR.entvars.velocity1] += accelspeed * (wishvel[1] / wishspeed);
        ent.v_float[PR.entvars.velocity2] += accelspeed * (wishvel[2] / wishspeed);
    }

    static function WaterJump() {
        var ent = SV.player;
        if ((SV.server.time > ent.v_float[PR.entvars.teleport_time]) || (ent.v_float[PR.entvars.waterlevel] == 0.0)) {
            ent.flags = ent.flags & (~SV.fl.waterjump >>> 0);
            ent.v_float[PR.entvars.teleport_time] = 0.0;
        }
        ent.v_float[PR.entvars.velocity] = ent.v_float[PR.entvars.movedir];
        ent.v_float[PR.entvars.velocity1] = ent.v_float[PR.entvars.movedir1];
    }

    static function AirMove() {
        var ent = SV.player;
        var cmd = Host.client.cmd;
        var forward = [], right = [];
        Vec.AngleVectors(ED.Vector(ent, PR.entvars.angles), forward, right);
        var fmove = cmd.forwardmove;
        var smove = cmd.sidemove;
        if ((SV.server.time < ent.v_float[PR.entvars.teleport_time]) && (fmove < 0.0))
            fmove = 0.0;
        var wishvel = [
            forward[0] * fmove + right[0] * smove,
            forward[1] * fmove + right[1] * smove,
            (Std.int(ent.v_float[PR.entvars.movetype]) != MoveType.walk) ? cmd.upmove : 0.0];
        var wishdir = [wishvel[0], wishvel[1], wishvel[2]];
        if (Vec.Normalize(wishdir) > SV.maxspeed.value) {
            wishvel[0] = wishdir[0] * SV.maxspeed.value;
            wishvel[1] = wishdir[1] * SV.maxspeed.value;
            wishvel[2] = wishdir[2] * SV.maxspeed.value;
        }
        if (ent.v_float[PR.entvars.movetype] == MoveType.noclip)
            ED.SetVector(ent, PR.entvars.velocity, wishvel);
        else if ((ent.flags & SV.fl.onground) != 0) {
            SV.UserFriction();
            SV.Accelerate(wishvel, false);
        } else
            SV.Accelerate(wishvel, true);
    }

    static function ClientThink() {
        var ent = SV.player;

        if (ent.v_float[PR.entvars.movetype] == MoveType.none)
            return;

        var punchangle = ED.Vector(ent, PR.entvars.punchangle);
        var len = Vec.Normalize(punchangle) - 10.0 * Host.frametime;
        if (len < 0.0)
            len = 0.0;
        ent.v_float[PR.entvars.punchangle] = punchangle[0] * len;
        ent.v_float[PR.entvars.punchangle1] = punchangle[1] * len;
        ent.v_float[PR.entvars.punchangle2] = punchangle[2] * len;

        if (ent.v_float[PR.entvars.health] <= 0.0)
            return;

        ent.v_float[PR.entvars.angles2] = V.CalcRoll(ED.Vector(ent, PR.entvars.angles), ED.Vector(ent, PR.entvars.velocity)) * 4.0;
        if (SV.player.v_float[PR.entvars.fixangle] == 0.0) {
            ent.v_float[PR.entvars.angles] = (ent.v_float[PR.entvars.v_angle] + ent.v_float[PR.entvars.punchangle]) / -3.0;
            ent.v_float[PR.entvars.angles1] = ent.v_float[PR.entvars.v_angle1] + ent.v_float[PR.entvars.punchangle1];
        }

        if ((ent.flags & SV.fl.waterjump) != 0)
            SV.WaterJump();
        else if ((ent.v_float[PR.entvars.waterlevel] >= 2.0) && (ent.v_float[PR.entvars.movetype] != MoveType.noclip))
            SV.WaterMove();
        else
            SV.AirMove();
    }

    static function ReadClientMove() {
        var client = Host.client;
        client.ping_times[client.num_pings++ & 15] = SV.server.time - MSG.ReadFloat();
        client.edict.v_float[PR.entvars.v_angle] = MSG.ReadAngle();
        client.edict.v_float[PR.entvars.v_angle1] = MSG.ReadAngle();
        client.edict.v_float[PR.entvars.v_angle2] = MSG.ReadAngle();
        client.cmd.forwardmove = MSG.ReadShort();
        client.cmd.sidemove = MSG.ReadShort();
        client.cmd.upmove = MSG.ReadShort();
        var i = MSG.ReadByte();
        client.edict.v_float[PR.entvars.button0] = i & 1;
        client.edict.v_float[PR.entvars.button2] = (i & 2) >> 1;
        i = MSG.ReadByte();
        if (i != 0)
            client.edict.v_float[PR.entvars.impulse] = i;
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

    static var move = {
        normal: 0,
        nomonsters: 1,
        missile: 2
    }

    static var box_clipnodes:Array<MClipNode>;
    static var box_planes:Array<Plane>;
    static var box_hull:MHull;

    static function InitBoxHull() {
        SV.box_clipnodes = [];
        SV.box_planes = [];
        SV.box_hull = {
            var h = new MHull();
            h.clipnodes = SV.box_clipnodes;
            h.planes = SV.box_planes;
            h.firstclipnode = 0;
            h.lastclipnode = 5;
            h;
        };
        for (i in 0...6) {
            var node = cast {};
            SV.box_clipnodes[i] = node;
            node.planenum = i;
            node.children = [];
            node.children[i & 1] = ModContents.empty;
            if (i != 5)
                node.children[1 - (i & 1)] = i + 1;
            else
                node.children[1 - (i & 1)] = ModContents.solid;
            var plane = cast {};
            SV.box_planes[i] = plane;
            plane.type = i >> 1;
            plane.normal = [0.0, 0.0, 0.0];
            plane.normal[i >> 1] = 1.0;
            plane.dist = 0.0;
        }
    }

    static function HullForEntity(ent:Edict, mins:Vec, maxs:Vec, offset:Vec):MHull {
        if (ent.v_float[PR.entvars.solid] != SV.solid.bsp) {
            SV.box_planes[0].dist = ent.v_float[PR.entvars.maxs] - mins[0];
            SV.box_planes[1].dist = ent.v_float[PR.entvars.mins] - maxs[0];
            SV.box_planes[2].dist = ent.v_float[PR.entvars.maxs1] - mins[1];
            SV.box_planes[3].dist = ent.v_float[PR.entvars.mins1] - maxs[1];
            SV.box_planes[4].dist = ent.v_float[PR.entvars.maxs2] - mins[2];
            SV.box_planes[5].dist = ent.v_float[PR.entvars.mins2] - maxs[2];
            offset[0] = ent.v_float[PR.entvars.origin];
            offset[1] = ent.v_float[PR.entvars.origin1];
            offset[2] = ent.v_float[PR.entvars.origin2];
            return SV.box_hull;
        }
        if (ent.v_float[PR.entvars.movetype] != MoveType.push)
            Sys.Error('SOLID_BSP without MOVETYPE_PUSH');
        var model = SV.server.models[Std.int(ent.v_float[PR.entvars.modelindex])];
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
        offset[0] = hull.clip_mins[0] - mins[0] + ent.v_float[PR.entvars.origin];
        offset[1] = hull.clip_mins[1] - mins[1] + ent.v_float[PR.entvars.origin1];
        offset[2] = hull.clip_mins[2] - mins[2] + ent.v_float[PR.entvars.origin2];
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

        var maxs1 = [maxs[0], maxs[1], maxs[2]];
        var mins2 = [mins[0], mins[1], mins[2]];
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
            var next = l.next;
            var touch = l.ent;
            l = next;
            if (touch == ent)
                continue;
            if ((touch.v_int[PR.entvars.touch] == 0) || (touch.v_float[PR.entvars.solid] != SV.solid.trigger))
                continue;
            if ((ent.v_float[PR.entvars.absmin] > touch.v_float[PR.entvars.absmax]) ||
                (ent.v_float[PR.entvars.absmin1] > touch.v_float[PR.entvars.absmax1]) || 
                (ent.v_float[PR.entvars.absmin2] > touch.v_float[PR.entvars.absmax2]) ||
                (ent.v_float[PR.entvars.absmax] < touch.v_float[PR.entvars.absmin]) ||
                (ent.v_float[PR.entvars.absmax1] < touch.v_float[PR.entvars.absmin1]) ||
                (ent.v_float[PR.entvars.absmax2] < touch.v_float[PR.entvars.absmin2]))
                continue;
            var old_self = PR.globals_int[PR.globalvars.self];
            var old_other = PR.globals_int[PR.globalvars.other];
            PR.globals_int[PR.globalvars.self] = touch.num;
            PR.globals_int[PR.globalvars.other] = ent.num;
            PR.globals_float[PR.globalvars.time] = SV.server.time;
            PR.ExecuteProgram(touch.v_int[PR.entvars.touch]);
            PR.globals_int[PR.globalvars.self] = old_self;
            PR.globals_int[PR.globalvars.other] = old_other;
        }
        if (node.axis == -1)
            return;
        if (ent.v_float[PR.entvars.absmax + node.axis] > node.dist)
            SV.TouchLinks(ent, node.children[0]);
        if (ent.v_float[PR.entvars.absmin + node.axis] < node.dist)
            SV.TouchLinks(ent, node.children[1]);
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

        var sides = Vec.BoxOnPlaneSide([ent.v_float[PR.entvars.absmin], ent.v_float[PR.entvars.absmin1], ent.v_float[PR.entvars.absmin2]],
            [ent.v_float[PR.entvars.absmax], ent.v_float[PR.entvars.absmax1], ent.v_float[PR.entvars.absmax2]], node.plane);
        if ((sides & 1) != 0)
            SV.FindTouchedLeafs(ent, node.children[0]);
        if ((sides & 2) != 0)
            SV.FindTouchedLeafs(ent, node.children[1]);
    }

    static function LinkEdict(ent, touch_triggers) {
        if ((ent == SV.server.edicts[0]) || (ent.free))
            return;

        SV.UnlinkEdict(ent);

        ent.v_float[PR.entvars.absmin] = ent.v_float[PR.entvars.origin] + ent.v_float[PR.entvars.mins] - 1.0;
        ent.v_float[PR.entvars.absmin1] = ent.v_float[PR.entvars.origin1] + ent.v_float[PR.entvars.mins1] - 1.0;
        ent.v_float[PR.entvars.absmin2] = ent.v_float[PR.entvars.origin2] + ent.v_float[PR.entvars.mins2];
        ent.v_float[PR.entvars.absmax] = ent.v_float[PR.entvars.origin] + ent.v_float[PR.entvars.maxs] + 1.0;
        ent.v_float[PR.entvars.absmax1] = ent.v_float[PR.entvars.origin1] + ent.v_float[PR.entvars.maxs1] + 1.0;
        ent.v_float[PR.entvars.absmax2] = ent.v_float[PR.entvars.origin2] + ent.v_float[PR.entvars.maxs2];

        if ((ent.flags & SV.fl.item) != 0) {
            ent.v_float[PR.entvars.absmin] -= 14.0;
            ent.v_float[PR.entvars.absmin1] -= 14.0;
            ent.v_float[PR.entvars.absmax] += 14.0;
            ent.v_float[PR.entvars.absmax1] += 14.0;
        } else {
            ent.v_float[PR.entvars.absmin2] -= 1.0;
            ent.v_float[PR.entvars.absmax2] += 1.0;
        }

        ent.leafnums = [];
        if (ent.v_float[PR.entvars.modelindex] != 0.0)
            SV.FindTouchedLeafs(ent, SV.server.worldmodel.nodes[0]);

        if (ent.v_float[PR.entvars.solid] == SV.solid.not)
            return;

        var node = SV.areanodes[0];
        while (true) {
            if (node.axis == -1)
                break;
            if (ent.v_float[PR.entvars.absmin + node.axis] > node.dist)
                node = node.children[0];
            else if (ent.v_float[PR.entvars.absmax + node.axis] < node.dist)
                node = node.children[1];
            else
                break;
        }

        var before = (ent.v_float[PR.entvars.solid] == SV.solid.trigger) ? node.trigger_edicts : node.solid_edicts;
        ent.area.next = before;
        ent.area.prev = before.prev;
        ent.area.prev.next = ent.area;
        ent.area.next.prev = ent.area;
        ent.area.ent = ent;

        if (touch_triggers)
            SV.TouchLinks(ent, SV.areanodes[0]);
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
        var origin = ED.Vector(ent, PR.entvars.origin);
        return SV.Move(origin, ED.Vector(ent, PR.entvars.mins), ED.Vector(ent, PR.entvars.maxs), origin, 0, ent).startsolid;
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
        var mid = [
            p1[0] + frac * (p2[0] - p1[0]),
            p1[1] + frac * (p2[1] - p1[1]),
            p1[2] + frac * (p2[2] - p1[2])
        ];
        var side = t1 < 0.0 ? 1 : 0;

        if (!SV.RecursiveHullCheck(hull, node.children[side], p1f, midf, p1, mid, trace))
            return false;

        if (SV.HullPointContents(hull, node.children[1 - side], mid) != ModContents.solid)
            return SV.RecursiveHullCheck(hull, node.children[1 - side], midf, p2f, mid, p2, trace);

        if (trace.allsolid)
            return false;

        if (side == 0) {
            trace.plane.normal = [plane.normal[0], plane.normal[1], plane.normal[2]];
            trace.plane.dist = plane.dist;
        } else {
            trace.plane.normal = [-plane.normal[0], -plane.normal[1], -plane.normal[2]];
            trace.plane.dist = -plane.dist;
        }

        while (SV.HullPointContents(hull, hull.firstclipnode, mid) == ModContents.solid) {
            frac -= 0.1;
            if (frac < 0.0) {
                trace.fraction = midf;
                trace.endpos = [mid[0], mid[1], mid[2]];
                Console.DPrint('backup past 0\n');
                return false;
            }
            midf = p1f + (p2f - p1f) * frac;
            mid[0] = p1[0] + frac * (p2[0] - p1[0]);
            mid[1] = p1[1] + frac * (p2[1] - p1[1]);
            mid[2] = p1[2] + frac * (p2[2] - p1[2]);
        }

        trace.fraction = midf;
        trace.endpos = [mid[0], mid[1], mid[2]];
        return false;
    }

    static function ClipMoveToEntity(ent:Edict, start:Vec, mins:Vec, maxs:Vec, end:Vec):MTrace {
        var trace = new MTrace();
        trace.fraction = 1.0;
        trace.allsolid = true;
        trace.endpos = [end[0], end[1], end[2]];
        trace.plane = {
            var p = new Plane();
            p.normal = [0.0, 0.0, 0.0];
            p.dist = 0.0;
            p;
        };

        var offset = [];
        var hull = SV.HullForEntity(ent, mins, maxs, offset);
        SV.RecursiveHullCheck(hull, hull.firstclipnode, 0.0, 1.0,
            [start[0] - offset[0], start[1] - offset[1], start[2] - offset[2]],
            [end[0] - offset[0], end[1] - offset[1], end[2] - offset[2]], trace);
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
            var solid = touch.v_float[PR.entvars.solid];
            if ((solid == SV.solid.not) || (touch == clip.passedict))
                continue;
            if (solid == SV.solid.trigger)
                Sys.Error('Trigger in clipping list');
            if ((clip.type == SV.move.nomonsters) && (solid != SV.solid.bsp))
                continue;
            if ((clip.boxmins[0] > touch.v_float[PR.entvars.absmax]) ||
                (clip.boxmins[1] > touch.v_float[PR.entvars.absmax1]) ||
                (clip.boxmins[2] > touch.v_float[PR.entvars.absmax2]) ||
                (clip.boxmaxs[0] < touch.v_float[PR.entvars.absmin]) ||
                (clip.boxmaxs[1] < touch.v_float[PR.entvars.absmin1]) ||
                (clip.boxmaxs[2] < touch.v_float[PR.entvars.absmin2]))
                continue;
            if (clip.passedict != null) {
                if ((clip.passedict.v_float[PR.entvars.size] != 0.0) && (touch.v_float[PR.entvars.size] == 0.0))
                    continue;
            }
            if (clip.trace.allsolid)
                return;
            if (clip.passedict != null) {
                if (SV.server.edicts[touch.v_int[PR.entvars.owner]] == clip.passedict)
                    continue;
                if (SV.server.edicts[clip.passedict.v_int[PR.entvars.owner]] == touch)
                    continue;
            }
            var trace;
            if ((touch.flags & SV.fl.monster) != 0)
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
        var clip = {
            var c = new MMoveClip();
            c.trace = SV.ClipMoveToEntity(SV.server.edicts[0], start, mins, maxs, end);
            c.start = start;
            c.end = end;
            c.mins = mins;
            c.maxs = maxs;
            c.type = type;
            c.passedict = passedict;
            c.boxmins = [];
            c.boxmaxs = [];
            c;
        };
        if (type == SV.move.missile) {
            clip.mins2 = [-15.0, -15.0, -15.0];
            clip.maxs2 = [15.0, 15.0, 15.0];
        } else {
            clip.mins2 = [mins[0], mins[1], mins[2]];
            clip.maxs2 = [maxs[0], maxs[1], maxs[2]];
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