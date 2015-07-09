package quake;

using Tools;


class Cvar {
    public var name(default,null):String;
    public var string(default,null):String;
    public var value:Float;
    public var archive(default,null):Bool;
    public var server(default,null):Bool;

    function new(name:String, value:String, archive:Bool, server:Bool) {
        this.name = name;
        this.string = value;
        this.archive = archive;
        this.server = server;
        this.value = Q.atof(value);
    }

    @:allow(quake.Cmd)
    static var vars = new Map<String,Cvar>();

    public static inline function FindVar(name:String):Cvar {
        return vars[name];
    }

    public static function CompleteVariable(partial:String):String {
        if (partial.length == 0)
            return null;
        for (name in vars.keys()) {
            if (name.substring(0, partial.length) == partial)
                return name;
        }
        return null;
    }

    public static function Set(name:String, value:String):Void {
        var v = vars[name];
        if (v == null) {
            Console.Print('Cvar.Set: variable ' + name + ' not found\n');
            return;
        }

        var changed = (v.string != value);
        v.string = value;
        v.value = Q.atof(value);
        if (v.server && changed && SV.server.active)
            Host.BroadcastPrint('"' + name + '" changed to "' + v.string + '"\n');
    }

    public static function SetValue(name:String, value:Float):Void {
        Set(name, value.toFixed(6));
    }

    public static function RegisterVariable(name:String, value:String, archive = false, server = false):Cvar {
        if (vars.exists(name)) {
            Console.Print('Can\'t register variable ' + name + ', already defined\n');
            return null;
        }
        return vars[name] = new Cvar(name, value, archive, server);
    }

    public static function Command():Bool {
        var v = FindVar(Cmd.argv[0]);
        if (v == null)
            return false;
        if (Cmd.argv.length <= 1) {
            Console.Print('"' + v.name + '" is "' + v.string + '"\n');
            return true;
        }
        Set(v.name, Cmd.argv[1]);
        return true;
    }

    public static function WriteVariables():String {
        var f = [];
        for (v in vars) {
            if (v.archive)
                f.push(v.name + ' "' + v.string + '"\n');
        }
        return f.join('');
    }
}
