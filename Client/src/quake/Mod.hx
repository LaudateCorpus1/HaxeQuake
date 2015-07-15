package quake;

import js.html.ArrayBuffer;
import js.html.DataView;
import js.html.Float32Array;
import js.html.Uint32Array;
import js.html.Uint8Array;
import js.html.webgl.RenderingContext;
import js.html.webgl.Buffer;
import js.html.webgl.Texture;
import quake.GL.gl;
import quake.GL.GLTexture;

// TODO this is a mess - there are 3 types of models and we should have classes for each one specifically

@:enum abstract MModelType(Int) {
    var brush = 0;
    var sprite = 1;
    var alias = 2;
}

@:publicFields
class MModel {
    var flags:ModelEffect;
    var oriented:Bool;
    var numframes:Int;
    var frames:Array<MFrame>;
    var boundingradius:Float;
    var player:Bool;
    var numtris:Int;
    var cmds:Buffer;
    var numskins:Int;
    var skins:Array<MSkin>;
    var type:MModelType;
    var mins:Vec;
    var maxs:Vec;
    var radius:Float;
    var submodel:Bool;
    var submodels:Array<MModel>;
    var lightdata:Uint8Array;
    var chains:Array<Array<Int>>;
    var textures:Array<MTexture>;
    var waterchain:Int;
    var skychain:Int;
    var leafs:Array<MLeaf>;
    var numfaces:Int;
    var faces:Array<MSurface>;
    var firstface:Int;
    var marksurfaces:Array<Int>;
    var texinfo:Array<MTexinfo>;
    var name:String;
    var vertexes:Array<Vec>;
    var edges:Array<Array<Int>>;
    var surfedges:Array<Int>;
    var visdata:Uint8Array;
    var random:Bool;
    var nodes:Array<MNode>;
    var hulls:Array<MHull>;
    var entities:String;
    var needload:Bool;
    var scale:Vec;
    var scale_origin:Vec;
    var skinwidth:Int;
    var skinheight:Int;
    var numverts:Int;
    var width:Int;
    var height:Int;
    var planes:Array<Plane>;
    var clipnodes:Array<MClipNode>;
    var origin:Vec;

    function new(name:String) {
        this.name = name;
        this.needload = true;
    }
}



@:publicFields
class MTrivert {
    var v:Array<Int>;
    var lightnormalindex:Int;
    function new(v, lightnormalindex) {
        this.v = v;
        this.lightnormalindex = lightnormalindex;
    }
}

@:publicFields
class MHull {
    var clipnodes:Array<MClipNode>;
    var planes:Array<Plane>;
    var firstclipnode:Int;
    var lastclipnode:Int;
    var clip_mins:Vec;
    var clip_maxs:Vec;
    function new() {}
}

@:publicFields
class MClipNode {
    var planenum:Int;
    var children:Array<Contents>;
    function new() {}
}

@:publicFields
class MSkin {
    var group:Bool;
    var skins:Array<MSkin>;
    var interval:Float;
    var texturenum:GLTexture;
    var playertexture:Texture;
    function new(g) {
        this.group = g;
    }
}

@:publicFields
class MFrame {
    var name:String;
    var group:Bool;
    var frames:Array<MFrame>;
    var interval:Float;
    var origin:Array<Int>;
    var width:Int;
    var height:Int;
    var texturenum:Texture;
    var cmdofs:Int;
    var bboxmin:Array<Int>;
    var bboxmax:Array<Int>;
    var v:Array<MTrivert>;
    function new(g) {
        this.group = g;
    }
}

@:publicFields
class MNode {
    var contents:Contents;
    var plane:Plane;
    var num:Int;
    var parent:MNode;
    var children:Array<MNode>;
    var numfaces:Int;
    var firstface:Int;
    var visframe:Int;
    var markvisframe:Int;
    var skychain:Int;
    var waterchain:Int;
    var mins:Vec;
    var maxs:Vec;
    var cmds:Array<Array<Int>>;
    var nummarksurfaces:Int;
    var firstmarksurface:Int;
    var planenum:Int;
    function new() {}
}


@:publicFields
class MLeaf extends MNode {
    var visofs:Int;
    var ambient_level:Array<Int>;
    function new() super();
}

@:publicFields
class MTexinfo {
    var texture:Int;
    var vecs:Array<Array<Float>>;
    var flags:Int;
    function new(v,t,f) {
        vecs = v;
        texture = t;
        flags = f;
    }
}

@:publicFields
class MSurface {
    var extents:Array<Int>;
    var texturemins:Array<Int>;
    var light_s:Int;
    var light_t:Int;
    var dlightframe:Int;
    var dlightbits:Int;
    var plane:Plane;
    var texinfo:Int;
    var sky:Bool;
    var turbulent:Bool;
    var lightofs:Int;
    var styles:Array<Int>;
    var texture:Int;
    var verts:Array<Array<Float>>;
    var numedges:Int;
    var firstedge:Int;
    function new() {}
}

@:publicFields
class MTexture {
    var name:String;
    var width:Int;
    var height:Int;
    var anim_base:Int;
    var anim_frame:Int;
    var anims:Array<Int>;
    var alternate_anims:Array<Int>;
    var sky:Bool;
    var turbulent:Bool;
    var texturenum:Texture;
    function new() {}
}

@:publicFields
class MTrace {
    var allsolid:Bool;
    var startsolid:Bool;
    var inopen:Bool;
    var inwater:Bool;
    var plane:Plane;
    var fraction:Float;
    var endpos:Vec;
    var ent:Edict;
    function new() {}
}


@:publicFields
class MMoveClip {
    var type:Int;
    var trace:MTrace;
    var boxmins:Vec;
    var boxmaxs:Vec;
    var mins:Vec;
    var maxs:Vec;
    var mins2:Vec;
    var maxs2:Vec;
    var start:Vec;
    var end:Vec;
    var passedict:Edict;
    function new() {}
}


@:publicFields
class MAreaNode {
    var axis:Int;
    var dist:Float;
    var children:Array<MAreaNode>;
    var trigger_edicts:MLink;
    var solid_edicts:MLink;
    function new() {}
}

class MLink {
    public var prev:MLink;
    public var next:MLink;
    public var ent:Edict;
    public function new() {}
}

@:enum abstract EntEffect(Int) to Int {
    var no = 0;
    var brightfield = 1;
    var muzzleflash = 2;
    var brightlight = 4;
    var dimlight = 8;
}

@:enum abstract ModelEffect(Int) to Int {
    var rocket = 1;
    var grenade = 2;
    var gib = 4;
    var rotate = 8;
    var tracer = 16;
    var zomgib = 32;
    var tracer2 = 64;
    var tracer3 = 128;
}

class Mod {
    static var known:Array<MModel> = [];

    public static function Init():Void {
        Mod_Brush.Init();
        Mod_Alias.Init();
    }

    public static function ClearAll():Void {
        for (i in 0...known.length) {
            var mod = known[i];
            if (mod.type != brush)
                continue;
            if (mod.cmds != null)
                gl.deleteBuffer(mod.cmds);
            known[i] = new MModel(mod.name);
        }
    }

    public static function FindName(name:String):MModel {
        if (name.length == 0)
            Sys.Error('Mod.FindName: NULL name');
        for (mod in known) {
            if (mod == null)
                continue;
            if (mod.name == name)
                return mod;
        }
        for (i in 0...known.length + 1) {
            if (known[i] != null)
                continue;
            return known[i] = new MModel(name);
        }
        return null;
    }

    static inline var IDPOLYHEADER = ('O'.code << 24) + ('P'.code << 16) + ('D'.code << 8) + 'I'.code; // little-endian "IDPO"
    static inline var IDSPRITEHEADER = ('P'.code << 24) + ('S'.code << 16) + ('D'.code << 8) + 'I'.code; // little-endian "IDSP"

    static function LoadModel(mod:MModel, crash:Bool):MModel {
        if (!mod.needload)
            return mod;
        var buf = COM.LoadFile(mod.name);
        if (buf == null) {
            if (crash)
                Sys.Error('Mod.LoadModel: ' + mod.name + ' not found');
            return null;
        }
        mod.needload = false;
        var view = new DataView(buf);
        switch (view.getUint32(0, true)) {
            case IDPOLYHEADER:
                Mod_Alias.LoadAliasModel(mod, view);
            case IDSPRITEHEADER:
                Mod_Sprite.LoadSpriteModel(mod, view);
            default:
                Mod_Brush.LoadBrushModel(mod, view);
        }
        return mod;
    }

    public static inline function ForName(name:String, crash:Bool):MModel {
        return LoadModel(FindName(name), crash);
    }

    public static function Print() {
        Console.Print('Cached models:\n');
        for (mod in known)
            Console.Print(mod.name + '\n');
    }
}
