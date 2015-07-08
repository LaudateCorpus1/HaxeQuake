package quake;

using Tools;

@:expose("Cvar")
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

    public static var vars:Array<Cvar> = [];

    public static function FindVar(name:String):Cvar {
        for (v in vars) {
            if (v.name == name)
                return v;
        }
        return null;
    }

    public static function CompleteVariable(partial:String):String {
        if (partial.length == 0)
            return null;
        for (v in vars) {
            if (v.name.substring(0, partial.length) == partial)
                return v.name;
        }
        return null;
    }

    public static function Set(name:String, value:String):Void {
        for (v in vars)
        {
            if (v.name != name)
                continue;
            var changed = (v.string != value);
            v.string = value;
            v.value = Q.atof(value);
            if (v.server && changed && (untyped SV).server.active)
                Host.BroadcastPrint('"' + v.name + '" changed to "' + v.string + '"\n');
            return;
        }
        Console.Print('Cvar.Set: variable ' + name + ' not found\n');
    }

    public static function SetValue(name:String, value:Float):Void {
        Cvar.Set(name, value.toFixed(6));
    }

    public static function RegisterVariable(name:String, value:String, archive = false, server = false):Cvar {
        for (v in vars) {
            if (v.name == name) {
                Console.Print('Can\'t register variable ' + name + ', already defined\n');
                return null;
            }
        }
        var v = new Cvar(name, value, archive, server);
        vars.push(v);
        return v;
    }

    public static function Command():Bool {
        var v = Cvar.FindVar(Cmd.argv[0]);
        if (v == null)
            return false;
        if (Cmd.argv.length <= 1) {
            Console.Print('"' + v.name + '" is "' + v.string + '"\n');
            return true;
        }
        Cvar.Set(v.name, Cmd.argv[1]);
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
