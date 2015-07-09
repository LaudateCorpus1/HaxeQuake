package quake;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.io.File;
#end

typedef ShaderSource = {
    var frag:String;
    var vert:String;
}

#if !macro
@:keep
@:build(quake.Shaders.build())
#end
class Shaders {
    #if macro
    static function build():Array<Field> {
        var fields:Array<Field> = [];
        var shadersDir = Context.resolvePath("shaders");
        var shaders = new Map<String,ShaderSource>();
        for (file in sys.FileSystem.readDirectory(shadersDir)) {
            var path = new haxe.io.Path(shadersDir + "/" + file);

            var entry = shaders[path.file];
            if (entry == null)
                entry = shaders[path.file] = {frag: null, vert: null};

            switch (path.ext) {
                case "frag":
                    entry.frag = File.getContent(path.toString());
                case "vert":
                    entry.vert = File.getContent(path.toString());
                default:
                    throw "Unknown shader file extension: " + path.toString();
            }
        }

        var pos = Context.currentPos();
        var init = [];
        for (key in shaders.keys()) {
            var value = shaders[key];
            if (value.vert == null)
                throw "No vertex shader for " + key;
            if (value.frag == null)
                throw "No fragment shader for " + key;
            init.push(macro $v{key} => $v{value});
        }

        fields.push({
            pos: pos,
            name: "shaders",
            kind: FProp("default", "null", macro : Map<String,quake.Shaders.ShaderSource>, macro $a{init}),
            access: [AStatic, APublic],
        });

        return fields;
    }
    #end
}
