package quake;

@:publicFields
private class Alias {
    var name:String;
    var value:String;
    function new(name, value) {
        this.name = name;
        this.value = value;
    }
}

@:publicFields
private class Func {
    var name:String;
    var command:Void->Void;
    function new(name, command) {
        this.name = name;
        this.command = command;
    }
}

@:expose("Cmd")
@:publicFields
class Cmd {
    static var alias = new Array<Alias>();
    static var wait = false;
    static var text = "";
    static var args:String;
    static var argv = new Array<String>();
    static var functions = new Array<Func>();
    static var client:Bool;

    static inline function Wait_f() {
        Cmd.wait = true;
    }

    static function Execute() {
        var line = '', quotes = false;
        while (text.length != 0) {
            var c = text.charCodeAt(0);
            text = text.substring(1);
            if (c == 34) {
                quotes = !quotes;
                line += String.fromCharCode(34);
                continue;
            }
            if ((!quotes && c == 59) || c == 10) {
                if (line.length == 0)
                    continue;
                ExecuteString(line);
                if (wait) {
                    wait = false;
                    return;
                }
                line = '';
                continue;
            }
            line += String.fromCharCode(c);
        }
        text = '';
    }

    static function StuffCmds_f() {
        var s = false, build = '';
        for (arg in COM.argv) {
            var c = arg.charCodeAt(0);
            if (s == true) {
                if (c == 43) {
                    build += ('\n' + arg.substring(1) + ' ');
                    continue;
                }
                if (c == 45) {
                    s = false;
                    build += '\n';
                    continue;
                }
                build += (arg + ' ');
                continue;
            }
            if (c == 43) {
                s = true;
                build += (arg.substring(1) + ' ');
            }
        }
        if (build.length != 0)
            Cmd.text = build + '\n' + Cmd.text;
    }

    static function Exec_f() {
        if (Cmd.argv.length != 2) {
            Console.Print('exec <filename> : execute a script file\n');
            return;
        }
        var f = COM.LoadTextFile(Cmd.argv[1]);
        if (f == null) {
            Console.Print('couldn\'t exec ' + Cmd.argv[1] + '\n');
            return;
        }
        Console.Print('execing ' + Cmd.argv[1] + '\n');
        Cmd.text = f + Cmd.text;
    }

    static function Echo_f() {
        for (i in 1...Cmd.argv.length)
            Console.Print(Cmd.argv[i] + ' ');
        Console.Print('\n');
    }

    static function Alias_f() {
        if (Cmd.argv.length <= 1) {
            Console.Print('Current alias commands:\n');
            for (a in alias)
                Console.Print(a.name + ' : ' + a.value + '\n');
        }
        var s = Cmd.argv[1], value = '';
        var i = 0;
        while (i < Cmd.alias.length) {
            if (Cmd.alias[i].name == s)
                break;
            i++;
        }
        for (j in 2...Cmd.argv.length) {
            value += Cmd.argv[j];
            if (j != Cmd.argv.length - 1)
                value += ' ';
        }
        Cmd.alias[i] = new Alias(s, value + '\n');
    }

    static function Init() {
        Cmd.AddCommand('stuffcmds', Cmd.StuffCmds_f);
        Cmd.AddCommand('exec', Cmd.Exec_f);
        Cmd.AddCommand('echo', Cmd.Echo_f);
        Cmd.AddCommand('alias', Cmd.Alias_f);
        Cmd.AddCommand('cmd', Cmd.ForwardToServer);
        Cmd.AddCommand('wait', Cmd.Wait_f);
    }

    static function TokenizeString(text:String):Void {
        argv = [];
        while (true) {
            var i = 0;
            while (i < text.length) {
                var c = text.charCodeAt(i);
                if (c > 32 || c == 10)
                    break;
                i++;
            }
            if (Cmd.argv.length == 1)
                Cmd.args = text.substring(i);
            if ((text.charCodeAt(i) == 10) || (i >= text.length))
                return;
            text = COM.Parse(text);
            if (text == null)
                return;
            argv.push(COM.token);
        }
    }

    static function AddCommand(name:String, command:Void->Void):Void {
        for (v in Cvar.vars) {
            if (v.name == name) {
                Console.Print('Cmd.AddCommand: ' + name + ' already defined as a var\n');
                return;
            }
        }
        for (f in functions) {
            if (f.name == name) {
                Console.Print('Cmd.AddCommand: ' + name + ' already defined\n');
                return;
            }
        }
        functions.push(new Func(name, command));
    }

    static function CompleteCommand(partial:String):String {
        if (partial.length == 0)
            return null;
        for (f in functions) {
            if (f.name.substring(0, partial.length) == partial)
                return f.name;
        }
        return null;
    }

    static function ExecuteString(text:String, client = false):Void {
        Cmd.client = client;
        TokenizeString(text);
        if (Cmd.argv.length == 0)
            return;
        var name = Cmd.argv[0].toLowerCase();
        for (f in functions) {
            if (f.name == name) {
                f.command();
                return;
            }
        }
        for (a in alias) {
            if (a.name == name) {
                Cmd.text = a.value + Cmd.text;
                return;
            }
        }
        if (!Cvar.Command())
            Console.Print('Unknown command "' + name + '"\n');
    }

    static function ForwardToServer() {
        if (CL.cls.state != CL.active.connected) {
            Console.Print('Can\'t "' + Cmd.argv[0] + '", not connected\n');
            return;
        }
        if (CL.cls.demoplayback == true)
            return;
        var args = String.fromCharCode(Protocol.clc.stringcmd);
        if (Cmd.argv[0].toLowerCase() != 'cmd')
            args += Cmd.argv[0] + ' ';
        if (Cmd.argv.length >= 2)
            args += Cmd.args;
        else
            args += '\n';
        MSG.WriteString(CL.cls.message, args);
    }
}
