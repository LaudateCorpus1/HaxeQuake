package quake;

import js.html.ArrayBuffer;
import js.html.Uint8Array;
import js.html.Uint32Array;
import js.html.Float32Array;
import js.html.webgl.Buffer;
import js.html.webgl.Framebuffer;
import js.html.webgl.Renderbuffer;
import js.html.webgl.Texture;
import js.html.webgl.RenderingContext;
import quake.Mod;
import quake.GL.gl;
import quake.Mod.MSurface;
import quake.Def.ClientStat;
using Tools;

@:enum private abstract ParticleType(Int) {
    var tracer = 0;
    var grav = 1;
    var slowgrav = 2;
    var fire = 3;
    var explode = 4;
    var explode2 = 5;
    var blob = 6;
    var blob2 = 7;
}

@:publicFields
private class Particle {
    var type:ParticleType;
    var ramp:Float;
    var die:Float;
    var org(default,null):Vec;
    var vel(default,null):Vec;
    var color:Int;
    function new() {
        this.type = tracer;
        this.ramp = 0.0;
        this.die = -1;
        this.org = new Vec();
        this.vel = new Vec();
        this.color = 0;
    }
}

@:publicFields
class R {
    static var currententity:Entity;
    static var emins:Vec;
    static var emaxs:Vec;

    static var waterwarp:Cvar;
    static var fullbright:Cvar;
    static var drawentities:Cvar;
    static var drawviewmodel:Cvar;
    static var novis:Cvar;
    static var speeds:Cvar;
    static var polyblend:Cvar;
    static var flashblend:Cvar;
    static var nocolors:Cvar;

    static var warpbuffer:Framebuffer;
    static var warptexture:Texture;
    static var dlightvecs:Buffer;
    static var skyvecs:Buffer;

    static var solidskytexture:Texture;
    static var alphaskytexture:Texture;
    static var lightmap_texture:Texture;
    static var dlightmap_texture:Texture;
    static var lightstyle_texture:Texture;
    static var fullbright_texture:Texture;
    static var null_texture:Texture;

    static var notexture_mip:MTexture;

    static var c_brush_verts:Int;
    static var c_alias_polys:Int;

    static var particles:Array<Particle>;

    static var oldviewleaf:MLeaf;
    static var viewleaf:MLeaf;

    static var skytexturenum:Int;

    // efrag

    static function SplitEntityOnNode(node:MNode):Void {
        if (node.contents == solid)
            return;
        if (node.contents < 0) {
            currententity.leafs.push(node.num - 1);
            return;
        }
        var sides = Vec.BoxOnPlaneSide(emins, emaxs, node.plane);
        if ((sides & 1) != 0)
            SplitEntityOnNode(node.children[0]);
        if ((sides & 2) != 0)
            SplitEntityOnNode(node.children[1]);
    }

    // light

    static var dlightframecount = 0;

    static var lightstylevalue = new Uint8Array(CL.MAX_LIGHTSTYLES);

    static function AnimateLight() {
        if (fullbright.value == 0) {
            var i = Math.floor(CL.state.time * 10.0);
            for (j in 0...CL.MAX_LIGHTSTYLES) {
                var style = CL.lightstyle[j];
                if (style.length == 0)
                    lightstylevalue[j] = 12;
                else
                    lightstylevalue[j] = style.charCodeAt(i % style.length) - 97;
            }
        } else {
            for (j in 0...CL.MAX_LIGHTSTYLES)
                lightstylevalue[j] = 12;
        }
        GL.Bind(0, lightstyle_texture);
        gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.ALPHA, CL.MAX_LIGHTSTYLES, 1, 0, RenderingContext.ALPHA, RenderingContext.UNSIGNED_BYTE, lightstylevalue);
    }

    static function RenderDlights():Void {
        if (flashblend.value == 0)
            return;
        dlightframecount++;
        gl.enable(RenderingContext.BLEND);
        var program = GL.UseProgram('dlight');
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, dlightvecs);
        gl.vertexAttribPointer(program.aPoint, 3, RenderingContext.FLOAT, false, 0, 0);
        for (l in CL.dlights) {
            if (l.die < CL.state.time || l.radius == 0.0)
                continue;
            if (Vec.Length(Vec.of(l.origin[0] - R.refdef.vieworg[0], l.origin[1] - R.refdef.vieworg[1], l.origin[2] - R.refdef.vieworg[2])) < (l.radius * 0.35)) {
                var a = l.radius * 0.0003;
                V.blend[3] += a * (1.0 - V.blend[3]);
                a /= V.blend[3];
                V.blend[0] = V.blend[1] * (1.0 - a) + (255.0 * a);
                V.blend[1] = V.blend[1] * (1.0 - a) + (127.5 * a);
                V.blend[2] *= 1.0 - a;
                continue;
            }
            gl.uniform3fv(program.uOrigin, l.origin);
            gl.uniform1f(program.uRadius, l.radius);
            gl.drawArrays(RenderingContext.TRIANGLE_FAN, 0, 18);
        }
        gl.disable(RenderingContext.BLEND);
    }

    static function MarkLights(light:DLight, bit:Int, node:MNode):Void {
        while (true) {
            if (node.contents < 0)
                return;

            var splitplane = node.plane;
            var dist;
            if (splitplane.type < 3)
                dist = light.origin[splitplane.type] - splitplane.dist;
            else
                dist = Vec.DotProduct(light.origin, splitplane.normal) - splitplane.dist;

            if (dist > light.radius) {
                node = node.children[0];
                continue;
            }
            if (dist < -light.radius) {
                node = node.children[1];
                continue;
            }

            for (i in 0...node.numfaces) {
                var surf = CL.state.worldmodel.faces[node.firstface + i];
                if (surf.sky || surf.turbulent)
                    continue;
                if (surf.dlightframe != (dlightframecount + 1)) {
                    surf.dlightbits = 0;
                    surf.dlightframe = dlightframecount + 1;
                }
                surf.dlightbits += bit;
            }

            var child = node.children[0];
            if (child.contents >= 0)
                MarkLights(light, bit, child);

            child = node.children[1];
            if (child.contents >= 0)
                MarkLights(light, bit, child);

            break;
        }
    }

    static function PushDlights() {
        if (R.flashblend.value != 0)
            return;
        for (i in 0...1024)
            R.lightmap_modified[i] = 0;

        var bit = 1;
        for (l in CL.dlights) {
            if (l.die >= CL.state.time && l.radius != 0.0) {
                MarkLights(l, bit, CL.state.worldmodel.nodes[0]);
                for (j in 0...CL.numvisedicts) {
                    var ent = CL.visedicts[j];
                    if (ent.model == null)
                        continue;
                    if (ent.model.type != brush || !ent.model.submodel)
                        continue;
                    MarkLights(l, bit, CL.state.worldmodel.nodes[ent.model.hulls[0].firstclipnode]);
                }
            }
            bit += bit;
        }

        for (surf in CL.state.worldmodel.faces) {
            if (surf.dlightframe == R.dlightframecount)
                RemoveDynamicLights(surf);
            else if (surf.dlightframe == (R.dlightframecount + 1))
                AddDynamicLights(surf);
        }

        GL.Bind(0, R.dlightmap_texture);
        var start:Null<Int> = null;
        for (i in 0...1024) {
            if (start == null && R.lightmap_modified[i] != 0)
                start = i;
            else if (start != null && R.lightmap_modified[i] == 0) {
                gl.texSubImage2D(RenderingContext.TEXTURE_2D, 0, 0, start, 1024, i - start, RenderingContext.ALPHA, RenderingContext.UNSIGNED_BYTE,
                    R.dlightmaps.subarray(start << 10, i << 10));
                start = null;
            }
        }
        if (start != null) {
            gl.texSubImage2D(RenderingContext.TEXTURE_2D, 0, 0, start, 1024, 1024 - start, RenderingContext.ALPHA, RenderingContext.UNSIGNED_BYTE,
                R.dlightmaps.subarray(start << 10, 1048576));
        }
        dlightframecount++;
    }

    static function RecursiveLightPoint(node:MNode, start:Vec, end:Vec):Int {
        if (node.contents < 0)
            return -1;

        var normal = node.plane.normal;
        var front = Vec.DotProduct(start, normal) - node.plane.dist;
        var back = Vec.DotProduct(end, normal) - node.plane.dist;
        var side = front < 0;

        if ((back < 0) == side)
            return RecursiveLightPoint(node.children[side ? 1 : 0], start, end);

        var frac = front / (front - back);
        var mid = Vec.of(
            start[0] + (end[0] - start[0]) * frac,
            start[1] + (end[1] - start[1]) * frac,
            start[2] + (end[2] - start[2]) * frac
        );

        var r = RecursiveLightPoint(node.children[side ? 1 : 0], start, mid);
        if (r >= 0)
            return r;

        if ((back < 0) == side)
            return -1;

        for (i in 0...node.numfaces) {
            var surf = CL.state.worldmodel.faces[node.firstface + i];
            if (surf.sky || surf.turbulent)
                continue;

            var tex = CL.state.worldmodel.texinfo[surf.texinfo];

            var s = Std.int(Vec.DotProduct(mid, Vec.ofArray(tex.vecs[0])) + tex.vecs[0][3]);
            var t = Std.int(Vec.DotProduct(mid, Vec.ofArray(tex.vecs[1])) + tex.vecs[1][3]);
            if (s < surf.texturemins[0] || t < surf.texturemins[1])
                continue;

            var ds = s - surf.texturemins[0];
            var dt = t - surf.texturemins[1];
            if (ds > surf.extents[0] || dt > surf.extents[1])
                continue;

            if (surf.lightofs == 0)
                return 0;

            ds >>= 4;
            dt >>= 4;

            var lightmap = surf.lightofs;
            if (lightmap == 0)
                return 0;

            lightmap += dt * ((surf.extents[0] >> 4) + 1) + ds;
            r = 0;
            var size = ((surf.extents[0] >> 4) + 1) * ((surf.extents[1] >> 4) + 1);
            for (maps in 0...surf.styles.length) {
                r += CL.state.worldmodel.lightdata[lightmap] * lightstylevalue[surf.styles[maps]] * 22;
                lightmap += size;
            }
            return r >> 8;
        }
        return RecursiveLightPoint(node.children[side ? 0 : 1], mid, end);
    }

    static function LightPoint(p:Vec):Int {
        if (CL.state.worldmodel.lightdata == null)
            return 255;
        var r = R.RecursiveLightPoint(CL.state.worldmodel.nodes[0], p, Vec.of(p[0], p[1], p[2] - 2048.0));
        if (r == -1)
            return 0;
        return r;
    }

    // main

    static var visframecount = 0;

    static var frustum = [new Plane(), new Plane(), new Plane(), new Plane()];

    static var vup = new Vec();
    static var vpn = new Vec();
    static var vright = new Vec();

    static var refdef = {
        vrect: {x: 0, y: 0, width: 0, height: 0},
        vieworg: new Vec(),
        viewangles: new Vec(),
        fov_x: 0.0,
        fov_y: 0.0,
    }

    static function CullBox(mins:Vec, maxs:Vec):Bool {
        if (Vec.BoxOnPlaneSide(mins, maxs, R.frustum[0]) == 2)
            return true;
        if (Vec.BoxOnPlaneSide(mins, maxs, R.frustum[1]) == 2)
            return true;
        if (Vec.BoxOnPlaneSide(mins, maxs, R.frustum[2]) == 2)
            return true;
        if (Vec.BoxOnPlaneSide(mins, maxs, R.frustum[3]) == 2)
            return true;
        return false;
    }

    static function DrawSpriteModel(e:Entity):Void {
        var program;
        if (e.model.oriented) {
            program = GL.UseProgram('spriteOriented');
            gl.uniformMatrix3fv(program.uAngles, false, GL.RotationMatrix(e.angles[0], e.angles[1] - 90.0, e.angles[2]));
        } else
            program = GL.UseProgram('sprite');
        var num = e.frame;
        if (num >= e.model.numframes || num < 0) {
            Console.DPrint('R.DrawSpriteModel: no such frame ' + num + '\n');
            num = 0;
        }
        var frame = e.model.frames[num];
        if (frame.group) {
            var time = CL.state.time + e.syncbase;
            var num = frame.frames.length - 1;
            var fullinterval = frame.frames[num].interval;
            var targettime = time - Math.floor(time / fullinterval) * fullinterval;
            var i = 0;
            while (i < num) {
                if (frame.frames[i].interval > targettime)
                    break;
                i++;
            }
            frame = frame.frames[i];
        }
        gl.uniform4f(program.uRect, frame.origin[0], frame.origin[1], frame.width, frame.height);
        gl.uniform3fv(program.uOrigin, e.origin);
        GL.Bind(program.tTexture, frame.texturenum);
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, GL.rect);
        gl.vertexAttribPointer(program.aPoint, 2, RenderingContext.FLOAT, false, 0, 0);
        gl.drawArrays(RenderingContext.TRIANGLE_STRIP, 0, 4);
    }

    static var avertexnormals = [
        [-0.525731, 0.0, 0.850651],
        [-0.442863, 0.238856, 0.864188],
        [-0.295242, 0.0, 0.955423],
        [-0.309017, 0.5, 0.809017],
        [-0.16246, 0.262866, 0.951056],
        [0.0, 0.0, 1.0],
        [0.0, 0.850651, 0.525731],
        [-0.147621, 0.716567, 0.681718],
        [0.147621, 0.716567, 0.681718],
        [0.0, 0.525731, 0.850651],
        [0.309017, 0.5, 0.809017],
        [0.525731, 0.0, 0.850651],
        [0.295242, 0.0, 0.955423],
        [0.442863, 0.238856, 0.864188],
        [0.16246, 0.262866, 0.951056],
        [-0.681718, 0.147621, 0.716567],
        [-0.809017, 0.309017, 0.5],
        [-0.587785, 0.425325, 0.688191],
        [-0.850651, 0.525731, 0.0],
        [-0.864188, 0.442863, 0.238856],
        [-0.716567, 0.681718, 0.147621],
        [-0.688191, 0.587785, 0.425325],
        [-0.5, 0.809017, 0.309017],
        [-0.238856, 0.864188, 0.442863],
        [-0.425325, 0.688191, 0.587785],
        [-0.716567, 0.681718, -0.147621],
        [-0.5, 0.809017, -0.309017],
        [-0.525731, 0.850651, 0.0],
        [0.0, 0.850651, -0.525731],
        [-0.238856, 0.864188, -0.442863],
        [0.0, 0.955423, -0.295242],
        [-0.262866, 0.951056, -0.16246],
        [0.0, 1.0, 0.0],
        [0.0, 0.955423, 0.295242],
        [-0.262866, 0.951056, 0.16246],
        [0.238856, 0.864188, 0.442863],
        [0.262866, 0.951056, 0.16246],
        [0.5, 0.809017, 0.309017],
        [0.238856, 0.864188, -0.442863],
        [0.262866, 0.951056, -0.16246],
        [0.5, 0.809017, -0.309017],
        [0.850651, 0.525731, 0.0],
        [0.716567, 0.681718, 0.147621],
        [0.716567, 0.681718, -0.147621],
        [0.525731, 0.850651, 0.0],
        [0.425325, 0.688191, 0.587785],
        [0.864188, 0.442863, 0.238856],
        [0.688191, 0.587785, 0.425325],
        [0.809017, 0.309017, 0.5],
        [0.681718, 0.147621, 0.716567],
        [0.587785, 0.425325, 0.688191],
        [0.955423, 0.295242, 0.0],
        [1.0, 0.0, 0.0],
        [0.951056, 0.16246, 0.262866],
        [0.850651, -0.525731, 0.0],
        [0.955423, -0.295242, 0.0],
        [0.864188, -0.442863, 0.238856],
        [0.951056, -0.16246, 0.262866],
        [0.809017, -0.309017, 0.5],
        [0.681718, -0.147621, 0.716567],
        [0.850651, 0.0, 0.525731],
        [0.864188, 0.442863, -0.238856],
        [0.809017, 0.309017, -0.5],
        [0.951056, 0.16246, -0.262866],
        [0.525731, 0.0, -0.850651],
        [0.681718, 0.147621, -0.716567],
        [0.681718, -0.147621, -0.716567],
        [0.850651, 0.0, -0.525731],
        [0.809017, -0.309017, -0.5],
        [0.864188, -0.442863, -0.238856],
        [0.951056, -0.16246, -0.262866],
        [0.147621, 0.716567, -0.681718],
        [0.309017, 0.5, -0.809017],
        [0.425325, 0.688191, -0.587785],
        [0.442863, 0.238856, -0.864188],
        [0.587785, 0.425325, -0.688191],
        [0.688191, 0.587785, -0.425325],
        [-0.147621, 0.716567, -0.681718],
        [-0.309017, 0.5, -0.809017],
        [0.0, 0.525731, -0.850651],
        [-0.525731, 0.0, -0.850651],
        [-0.442863, 0.238856, -0.864188],
        [-0.295242, 0.0, -0.955423],
        [-0.16246, 0.262866, -0.951056],
        [0.0, 0.0, -1.0],
        [0.295242, 0.0, -0.955423],
        [0.16246, 0.262866, -0.951056],
        [-0.442863, -0.238856, -0.864188],
        [-0.309017, -0.5, -0.809017],
        [-0.16246, -0.262866, -0.951056],
        [0.0, -0.850651, -0.525731],
        [-0.147621, -0.716567, -0.681718],
        [0.147621, -0.716567, -0.681718],
        [0.0, -0.525731, -0.850651],
        [0.309017, -0.5, -0.809017],
        [0.442863, -0.238856, -0.864188],
        [0.16246, -0.262866, -0.951056],
        [0.238856, -0.864188, -0.442863],
        [0.5, -0.809017, -0.309017],
        [0.425325, -0.688191, -0.587785],
        [0.716567, -0.681718, -0.147621],
        [0.688191, -0.587785, -0.425325],
        [0.587785, -0.425325, -0.688191],
        [0.0, -0.955423, -0.295242],
        [0.0, -1.0, 0.0],
        [0.262866, -0.951056, -0.16246],
        [0.0, -0.850651, 0.525731],
        [0.0, -0.955423, 0.295242],
        [0.238856, -0.864188, 0.442863],
        [0.262866, -0.951056, 0.16246],
        [0.5, -0.809017, 0.309017],
        [0.716567, -0.681718, 0.147621],
        [0.525731, -0.850651, 0.0],
        [-0.238856, -0.864188, -0.442863],
        [-0.5, -0.809017, -0.309017],
        [-0.262866, -0.951056, -0.16246],
        [-0.850651, -0.525731, 0.0],
        [-0.716567, -0.681718, -0.147621],
        [-0.716567, -0.681718, 0.147621],
        [-0.525731, -0.850651, 0.0],
        [-0.5, -0.809017, 0.309017],
        [-0.238856, -0.864188, 0.442863],
        [-0.262866, -0.951056, 0.16246],
        [-0.864188, -0.442863, 0.238856],
        [-0.809017, -0.309017, 0.5],
        [-0.688191, -0.587785, 0.425325],
        [-0.681718, -0.147621, 0.716567],
        [-0.442863, -0.238856, 0.864188],
        [-0.587785, -0.425325, 0.688191],
        [-0.309017, -0.5, 0.809017],
        [-0.147621, -0.716567, 0.681718],
        [-0.425325, -0.688191, 0.587785],
        [-0.16246, -0.262866, 0.951056],
        [0.442863, -0.238856, 0.864188],
        [0.16246, -0.262866, 0.951056],
        [0.309017, -0.5, 0.809017],
        [0.147621, -0.716567, 0.681718],
        [0.0, -0.525731, 0.850651],
        [0.425325, -0.688191, 0.587785],
        [0.587785, -0.425325, 0.688191],
        [0.688191, -0.587785, 0.425325],
        [-0.955423, 0.295242, 0.0],
        [-0.951056, 0.16246, 0.262866],
        [-1.0, 0.0, 0.0],
        [-0.850651, 0.0, 0.525731],
        [-0.955423, -0.295242, 0.0],
        [-0.951056, -0.16246, 0.262866],
        [-0.864188, 0.442863, -0.238856],
        [-0.951056, 0.16246, -0.262866],
        [-0.809017, 0.309017, -0.5],
        [-0.864188, -0.442863, -0.238856],
        [-0.951056, -0.16246, -0.262866],
        [-0.809017, -0.309017, -0.5],
        [-0.681718, 0.147621, -0.716567],
        [-0.681718, -0.147621, -0.716567],
        [-0.850651, 0.0, -0.525731],
        [-0.688191, 0.587785, -0.425325],
        [-0.587785, 0.425325, -0.688191],
        [-0.425325, 0.688191, -0.587785],
        [-0.425325, -0.688191, -0.587785],
        [-0.587785, -0.425325, -0.688191],
        [-0.688191, -0.587785, -0.425325]
    ];

    static function DrawAliasModel(e:Entity):Void {
        var clmodel = e.model;

        if (R.CullBox(
            Vec.of(
                e.origin[0] - clmodel.boundingradius,
                e.origin[1] - clmodel.boundingradius,
                e.origin[2] - clmodel.boundingradius
            ),
            Vec.of(
                e.origin[0] + clmodel.boundingradius,
                e.origin[1] + clmodel.boundingradius,
                e.origin[2] + clmodel.boundingradius
            )))
            return;

        var program;
        if ((e.colormap != 0) && (clmodel.player) && (R.nocolors.value == 0)) {
            program = GL.UseProgram('player');
            var top = (CL.state.scores[e.colormap - 1].colors & 0xf0) + 4;
            var bottom = ((CL.state.scores[e.colormap - 1].colors & 0xf) << 4) + 4;
            if (top <= 127)
                top += 7;
            if (bottom <= 127)
                bottom += 7;
            top = VID.d_8to24table[top];
            bottom = VID.d_8to24table[bottom];
            gl.uniform3f(program.uTop, top & 0xff, (top >> 8) & 0xff, top >> 16);
            gl.uniform3f(program.uBottom, bottom & 0xff, (bottom >> 8) & 0xff, bottom >> 16);
        } else
            program = GL.UseProgram('alias');
        gl.uniform3fv(program.uOrigin, e.origin);
        gl.uniformMatrix3fv(program.uAngles, false, GL.RotationMatrix(e.angles[0], e.angles[1], e.angles[2]));

        var ambientlight:Float = R.LightPoint(e.origin);
        var shadelight = ambientlight;
        if ((e == CL.state.viewent) && (ambientlight < 24.0))
            ambientlight = shadelight = 24;
        for (dl in CL.dlights) {
            if (dl.die < CL.state.time)
                continue;
            var add = dl.radius - Vec.Length(Vec.of(e.origin[0] - dl.origin[0], e.origin[1] - dl.origin[1], e.origin[1] - dl.origin[1]));
            if (add > 0) {
                ambientlight += add;
                shadelight += add;
            }
        }
        if (ambientlight > 128.0)
            ambientlight = 128.0;
        if ((ambientlight + shadelight) > 192.0)
            shadelight = 192.0 - ambientlight;
        if ((e.num >= 1) && (e.num <= CL.state.maxclients) && (ambientlight < 8.0))
            ambientlight = shadelight = 8.0;
        gl.uniform1f(program.uAmbientLight, ambientlight * 0.0078125);
        gl.uniform1f(program.uShadeLight, shadelight * 0.0078125);

        var forward = new Vec(), right = new Vec(), up = new Vec();
        Vec.AngleVectors(e.angles, forward, right, up);
        gl.uniform3fv(program.uLightVec, [
            Vec.DotProduct(Vec.of(-1.0, 0.0, 0.0), forward),
            -Vec.DotProduct(Vec.of(-1.0, 0.0, 0.0), right),
            Vec.DotProduct(Vec.of(-1.0, 0.0, 0.0), up)
        ]);

        R.c_alias_polys += clmodel.numtris;

        var time = CL.state.time + e.syncbase;
        var num = e.frame;
        if (num >= clmodel.numframes || num < 0) {
            Console.DPrint('R.DrawAliasModel: no such frame ' + num + '\n');
            num = 0;
        }
        var frame = clmodel.frames[num];
        if (frame.group) {  
            var num = frame.frames.length - 1;
            var fullinterval = frame.frames[num].interval;
            var targettime = time - Math.floor(time / fullinterval) * fullinterval;
            var i = 0;
            while (i < num) {
                if (frame.frames[i].interval > targettime)
                    break;
                i++;
            }
            frame = frame.frames[i];
        }
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, clmodel.cmds);
        gl.vertexAttribPointer(program.aPoint, 3, RenderingContext.FLOAT, false, 24, frame.cmdofs);
        gl.vertexAttribPointer(program.aLightNormal, 3, RenderingContext.FLOAT, false, 24, frame.cmdofs + 12);
        gl.vertexAttribPointer(program.aTexCoord, 2, RenderingContext.FLOAT, false, 0, 0);

        num = e.skinnum;
        if (num >= clmodel.numskins || num < 0) {
            Console.DPrint('R.DrawAliasModel: no such skin # ' + num + '\n');
            num = 0;
        }
        var skin = clmodel.skins[num];
        if (skin.group) {   
            num = skin.skins.length - 1;
            var fullinterval = skin.skins[num].interval;
            var targettime = time - Math.floor(time / fullinterval) * fullinterval;
            var i = 0;
            while (i < num) {
                if (skin.skins[i].interval > targettime)
                    break;
                i++;
            }
            skin = skin.skins[i];
        }
        GL.Bind(program.tTexture, skin.texturenum.texnum);
        if (clmodel.player)
            GL.Bind(program.tPlayer, skin.playertexture);

        gl.drawArrays(RenderingContext.TRIANGLES, 0, clmodel.numtris * 3);
    }

    static function DrawEntitiesOnList() {
        if (R.drawentities.value == 0)
            return;
        var vis = (R.novis.value != 0) ? Mod.novis : Mod.LeafPVS(R.viewleaf, CL.state.worldmodel);
        for (i in 0...CL.state.num_statics) {
            R.currententity = CL.static_entities[i];
            if (R.currententity.model == null)
                continue;
            var j = 0;
            while (j < R.currententity.leafs.length) {
                var leaf = R.currententity.leafs[j];
                if (leaf < 0 || (vis[leaf >> 3] & (1 << (leaf & 7))) != 0)
                    break;
                j++;

            }
            if (j == R.currententity.leafs.length)
                continue;
            switch (R.currententity.model.type) {
                case alias:
                    R.DrawAliasModel(R.currententity);
                case brush:
                    R.DrawBrushModel(R.currententity);
                default:
            }
        }
        for (i in 0...CL.numvisedicts) {
            R.currententity = CL.visedicts[i];
            if (R.currententity.model == null)
                continue;
            switch (R.currententity.model.type) {
                case alias:
                    R.DrawAliasModel(R.currententity);
                case brush:
                    R.DrawBrushModel(R.currententity);
                default:
            }
        }
        gl.depthMask(false);
        gl.enable(RenderingContext.BLEND);
        for (i in 0...CL.state.num_statics) {
            R.currententity = CL.static_entities[i];
            if (R.currententity.model == null)
                continue;
            if (R.currententity.model.type == sprite)
                R.DrawSpriteModel(R.currententity);
        }
        for (i in 0...CL.numvisedicts) {
            R.currententity = CL.visedicts[i];
            if (R.currententity.model == null)
                continue;
            if (R.currententity.model.type == sprite)
                R.DrawSpriteModel(R.currententity);
        }
        gl.disable(RenderingContext.BLEND);
        gl.depthMask(true);
    }

    static function DrawViewModel() {
        if (R.drawviewmodel.value == 0)
            return;
        if (Chase.active.value != 0)
            return;
        if (R.drawentities.value == 0)
            return;
        if ((CL.state.items & Def.it.invisibility) != 0)
            return;
        if (CL.state.stats[ClientStat.health] <= 0)
            return;
        if (CL.state.viewent.model == null)
            return;

        gl.depthRange(0.0, 0.3);

        var ymax = 4.0 * Math.tan(SCR.fov.value * 0.82 * Math.PI / 360.0);
        R.perspective[0] = 4.0 / (ymax * R.refdef.vrect.width / R.refdef.vrect.height);
        R.perspective[5] = 4.0 / ymax;
        var program = GL.UseProgram('alias');
        gl.uniformMatrix4fv(program.uPerspective, false, R.perspective);

        R.DrawAliasModel(CL.state.viewent);

        ymax = 4.0 * Math.tan(R.refdef.fov_y * Math.PI / 360.0);
        R.perspective[0] = 4.0 / (ymax * R.refdef.vrect.width / R.refdef.vrect.height);
        R.perspective[5] = 4.0 / ymax;
        program = GL.UseProgram('alias');
        gl.uniformMatrix4fv(program.uPerspective, false, R.perspective);

        gl.depthRange(0.0, 1.0);
    }

    static function PolyBlend() {
        if (R.polyblend.value == 0)
            return;
        if (V.blend[3] == 0.0)
            return;
        var program = GL.UseProgram('fill');
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, GL.rect);
        gl.vertexAttribPointer(program.aPoint, 2, RenderingContext.FLOAT, false, 0, 0);
        var vrect = R.refdef.vrect;
        gl.uniform4f(program.uRect, vrect.x, vrect.y, vrect.width, vrect.height);
        gl.uniform4fv(program.uColor, V.blend);
        gl.drawArrays(RenderingContext.TRIANGLE_STRIP, 0, 4);
    }

    static function SetFrustum() {
        frustum[0].normal = Vec.RotatePointAroundVector(vup, vpn, -(90.0 - refdef.fov_x * 0.5));
        frustum[1].normal = Vec.RotatePointAroundVector(vup, vpn, 90.0 - refdef.fov_x * 0.5);
        frustum[2].normal = Vec.RotatePointAroundVector(vright, vpn, 90.0 - refdef.fov_y * 0.5);
        frustum[3].normal = Vec.RotatePointAroundVector(vright, vpn, -(90.0 - refdef.fov_y * 0.5));
        for (i in 0...4) {
            var out = frustum[i];
            out.type = 5;
            out.dist = Vec.DotProduct(refdef.vieworg, out.normal);
            out.signbits = 0;
            if (out.normal[0] < 0.0)
                out.signbits = 1;
            if (out.normal[1] < 0.0)
                out.signbits += 2;
            if (out.normal[2] < 0.0)
                out.signbits += 4;
            if (out.normal[3] < 0.0)
                out.signbits += 8;
        }
    }

    static var perspective = [
        0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, -65540.0 / 65532.0, -1.0,
        0.0, 0.0, -524288.0 / 65532.0, 0.0
    ];

    static function Perspective() {
        var viewangles = [
            R.refdef.viewangles[0] * Math.PI / 180.0,
            (R.refdef.viewangles[1] - 90.0) * Math.PI / -180.0,
            R.refdef.viewangles[2] * Math.PI / -180.0
        ];
        var sp = Math.sin(viewangles[0]);
        var cp = Math.cos(viewangles[0]);
        var sy = Math.sin(viewangles[1]);
        var cy = Math.cos(viewangles[1]);
        var sr = Math.sin(viewangles[2]);
        var cr = Math.cos(viewangles[2]);
        var viewMatrix = [
            cr * cy + sr * sp * sy,     cp * sy,    -sr * cy + cr * sp * sy,
            cr * -sy + sr * sp * cy,    cp * cy,    -sr * -sy + cr * sp * cy,
            sr * cp,                    -sp,        cr * cp
        ];

        if (V.gamma.value < 0.5)
            V.gamma.setValue(0.5);
        else if (V.gamma.value > 1.0)
            V.gamma.setValue(1.0);

        GL.UnbindProgram();
        for (program in GL.programs) {
            gl.useProgram(program.program);
            if (program.uViewOrigin != null)
                gl.uniform3fv(program.uViewOrigin, R.refdef.vieworg);
            if (program.uViewAngles != null)
                gl.uniformMatrix3fv(program.uViewAngles, false, viewMatrix);
            if (program.uPerspective != null)
                gl.uniformMatrix4fv(program.uPerspective, false, R.perspective);
            if (program.uGamma != null)
                gl.uniform1f(program.uGamma, V.gamma.value);
        }
    }

    static var dowarp:Bool;
    static var warpwidth:Int;
    static var warpheight:Int;
    static var oldwarpwidth:Int;
    static var oldwarpheight:Int;

    static function SetupGL() {
        if (R.dowarp) {
            gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, R.warpbuffer);
            gl.clear(RenderingContext.COLOR_BUFFER_BIT + RenderingContext.DEPTH_BUFFER_BIT);
            gl.viewport(0, 0, R.warpwidth, R.warpheight);
        } else {
            var vrect = R.refdef.vrect;
            var pixelRatio = SCR.devicePixelRatio;
            gl.viewport(Std.int(vrect.x * pixelRatio), Std.int((VID.height - vrect.height - vrect.y) * pixelRatio), Std.int(vrect.width * pixelRatio), Std.int(vrect.height * pixelRatio));
        }
        Perspective();
        gl.enable(RenderingContext.DEPTH_TEST);
    }

    static function RenderScene() {
        if (CL.state.maxclients >= 2)
            fullbright.set("0");
        AnimateLight();
        Vec.AngleVectors(refdef.viewangles, vpn, vright, vup);
        viewleaf = Mod.PointInLeaf(refdef.vieworg, CL.state.worldmodel);
        V.SetContentsColor(R.viewleaf.contents);
        V.CalcBlend();
        dowarp = (R.waterwarp.value != 0) && (viewleaf.contents <= Contents.water);

        SetFrustum();
        SetupGL();
        MarkLeaves();
        gl.enable(RenderingContext.CULL_FACE);
        DrawSkyBox();
        DrawViewModel();
        DrawWorld();
        DrawEntitiesOnList();
        gl.disable(RenderingContext.CULL_FACE);
        RenderDlights();
        DrawParticles();
    }

    static function RenderView() {
        gl.finish();
        var time1;
        if (R.speeds.value != 0)
            time1 = Sys.FloatTime();
        R.c_brush_verts = 0;
        R.c_alias_polys = 0;
        gl.clear(RenderingContext.COLOR_BUFFER_BIT + RenderingContext.DEPTH_BUFFER_BIT);
        R.RenderScene();
        if (R.speeds.value != 0) {
            var time2 = Math.floor((Sys.FloatTime() - time1) * 1000.0);
            var c_brush_polys = R.c_brush_verts / 3;
            var c_alias_polys = R.c_alias_polys;
            var msg = ((time2 >= 100) ? '' : ((time2 >= 10) ? ' ' : '  ')) + time2 + ' ms  ';
            msg += ((c_brush_polys >= 1000) ? '' : ((c_brush_polys >= 100) ? ' ' : ((c_brush_polys >= 10) ? '  ' : '   '))) + c_brush_polys + ' wpoly ';
            msg += ((c_alias_polys >= 1000) ? '' : ((c_alias_polys >= 100) ? ' ' : ((c_alias_polys >= 10) ? '  ' : '   '))) + c_alias_polys + ' epoly\n';
            Console.Print(msg);
        }
    }

    // mesh

    static function MakeBrushModelDisplayLists(m:MModel) {
        if (m.cmds != null)
            gl.deleteBuffer(m.cmds);
        var cmds = [];
        var styles = [0.0, 0.0, 0.0, 0.0];
        var verts = 0;
        m.chains = [];
        for (i in 0...m.textures.length) {
            var texture = m.textures[i];
            if (texture.sky || texture.turbulent)
                continue;
            var chain = [i, verts, 0];
            for (j in 0...m.numfaces) {
                var surf = m.faces[m.firstface + j];
                if (surf.texture != i)
                    continue;
                styles[0] = styles[1] = styles[2] = styles[3] = 0.0;
                switch (surf.styles.length) {
                    case 4:
                        styles[3] = surf.styles[3] * 0.015625 + 0.0078125;
                    case 3:
                        styles[2] = surf.styles[2] * 0.015625 + 0.0078125;
                    case 2:
                        styles[1] = surf.styles[1] * 0.015625 + 0.0078125;
                    case 1:
                        styles[0] = surf.styles[0] * 0.015625 + 0.0078125;
                }
                chain[2] += surf.verts.length;
                for (k in 0...surf.verts.length) {
                    var vert = surf.verts[k];
                    cmds[cmds.length] = vert[0];
                    cmds[cmds.length] = vert[1];
                    cmds[cmds.length] = vert[2];
                    cmds[cmds.length] = vert[3];
                    cmds[cmds.length] = vert[4];
                    cmds[cmds.length] = vert[5];
                    cmds[cmds.length] = vert[6];
                    cmds[cmds.length] = styles[0];
                    cmds[cmds.length] = styles[1];
                    cmds[cmds.length] = styles[2];
                    cmds[cmds.length] = styles[3];
                }
            }
            if (chain[2] != 0) {
                m.chains[m.chains.length] = chain;
                verts += chain[2];
            }
        }
        m.waterchain = verts * 44;
        verts = 0;
        for (i in 0...m.textures.length) {
            var texture = m.textures[i];
            if (!texture.turbulent)
                continue;
            var chain = [i, verts, 0];
            for (j in 0...m.numfaces) {
                var surf = m.faces[m.firstface + j];
                if (surf.texture != i)
                    continue;
                chain[2] += surf.verts.length;
                for (k in 0...surf.verts.length) {
                    var vert = surf.verts[k];
                    cmds[cmds.length] = vert[0];
                    cmds[cmds.length] = vert[1];
                    cmds[cmds.length] = vert[2];
                    cmds[cmds.length] = vert[3];
                    cmds[cmds.length] = vert[4];
                }
            }
            if (chain[2] != 0) {
                m.chains[m.chains.length] = chain;
                verts += chain[2];
            }
        }
        m.cmds = gl.createBuffer();
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, m.cmds);
        gl.bufferData(RenderingContext.ARRAY_BUFFER, new Float32Array(cmds), RenderingContext.STATIC_DRAW);
    }

    static function MakeWorldModelDisplayLists(m:MModel):Void {
        if (m.cmds != null)
            return;
        var cmds = [];
        var styles = [0.0, 0.0, 0.0, 0.0];
        var verts = 0;
        for (i in 0...m.textures.length) {
            var texture = m.textures[i];
            if (texture.sky || texture.turbulent)
                continue;
            for (j in 0...m.leafs.length) {
                var leaf = m.leafs[j];
                var chain = [i, verts, 0];
                for (k in 0...leaf.nummarksurfaces) {
                    var surf = m.faces[m.marksurfaces[leaf.firstmarksurface + k]];
                    if (surf.texture != i)
                        continue;
                    styles[0] = styles[1] = styles[2] = styles[3] = 0.0;
                    switch (surf.styles.length) {
                        case 4:
                            styles[3] = surf.styles[3] * 0.015625 + 0.0078125;
                            styles[2] = surf.styles[2] * 0.015625 + 0.0078125;
                            styles[1] = surf.styles[1] * 0.015625 + 0.0078125;
                            styles[0] = surf.styles[0] * 0.015625 + 0.0078125;
                        case 3:
                            styles[2] = surf.styles[2] * 0.015625 + 0.0078125;
                            styles[1] = surf.styles[1] * 0.015625 + 0.0078125;
                            styles[0] = surf.styles[0] * 0.015625 + 0.0078125;
                        case 2:
                            styles[1] = surf.styles[1] * 0.015625 + 0.0078125;
                            styles[0] = surf.styles[0] * 0.015625 + 0.0078125;
                        case 1:
                            styles[0] = surf.styles[0] * 0.015625 + 0.0078125;
                    }
                    chain[2] += surf.verts.length;
                    for (vert in surf.verts) {
                        cmds[cmds.length] = vert[0];
                        cmds[cmds.length] = vert[1];
                        cmds[cmds.length] = vert[2];
                        cmds[cmds.length] = vert[3];
                        cmds[cmds.length] = vert[4];
                        cmds[cmds.length] = vert[5];
                        cmds[cmds.length] = vert[6];
                        cmds[cmds.length] = styles[0];
                        cmds[cmds.length] = styles[1];
                        cmds[cmds.length] = styles[2];
                        cmds[cmds.length] = styles[3];
                    }
                }
                if (chain[2] != 0) {
                    leaf.cmds[leaf.cmds.length] = chain;
                    ++leaf.skychain;
                    ++leaf.waterchain;
                    verts += chain[2];
                }
            }
        }
        m.skychain = verts * 44;
        verts = 0;
        for (i in 0...m.textures.length) {
            var texture = m.textures[i];
            if (!texture.sky)
                continue;
            for (j in 0...m.leafs.length) {
                var leaf = m.leafs[j];
                var chain = [verts, 0];
                for (k in 0...leaf.nummarksurfaces) {
                    var surf = m.faces[m.marksurfaces[leaf.firstmarksurface + k]];
                    if (surf.texture != i)
                        continue;
                    chain[1] += surf.verts.length;
                    for (l in 0...surf.verts.length) {
                        var vert = surf.verts[l];
                        cmds[cmds.length] = vert[0];
                        cmds[cmds.length] = vert[1];
                        cmds[cmds.length] = vert[2];
                    }
                }
                if (chain[1] != 0) {
                    leaf.cmds[leaf.cmds.length] = chain;
                    ++leaf.waterchain;
                    verts += chain[1];
                }
            }
        }
        m.waterchain = m.skychain + verts * 12;
        verts = 0;
        for (i in 0...m.textures.length) {
            var texture = m.textures[i];
            if (!texture.turbulent)
                continue;
            for (j in 0...m.leafs.length) {
                var leaf = m.leafs[j];
                var chain = [i, verts, 0];
                for (k in 0...leaf.nummarksurfaces) {
                    var surf = m.faces[m.marksurfaces[leaf.firstmarksurface + k]];
                    if (surf.texture != i)
                        continue;
                    chain[2] += surf.verts.length;
                    for (l in 0...surf.verts.length) {
                        var vert = surf.verts[l];
                        cmds[cmds.length] = vert[0];
                        cmds[cmds.length] = vert[1];
                        cmds[cmds.length] = vert[2];
                        cmds[cmds.length] = vert[3];
                        cmds[cmds.length] = vert[4];
                    }
                }
                if (chain[2] != 0) {
                    leaf.cmds[leaf.cmds.length] = chain;
                    verts += chain[2];
                }
            }
        }
        m.cmds = gl.createBuffer();
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, m.cmds);
        gl.bufferData(RenderingContext.ARRAY_BUFFER, new Float32Array(cmds), RenderingContext.STATIC_DRAW);
    }

    // misc

    static function InitTextures() {
        var data = new Uint8Array(new ArrayBuffer(256));
        for (i in 0...8) {
            for (j in 0...8) {
                data[(i << 4) + j] = data[136 + (i << 4) + j] = 255;
                data[8 + (i << 4) + j] = data[128 + (i << 4) + j] = 0;
            }
        }
        R.notexture_mip = {
            var t = new MTexture();
            t.name = 'notexture';
            t.width = 16;
            t.height = 16;
            t.texturenum = gl.createTexture();
            t;
        };
        GL.Bind(0, R.notexture_mip.texturenum);
        GL.Upload(data, 16, 16);

        R.solidskytexture = gl.createTexture();
        GL.Bind(0, R.solidskytexture);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.LINEAR);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.LINEAR);
        R.alphaskytexture = gl.createTexture();
        GL.Bind(0, R.alphaskytexture);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.LINEAR);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.LINEAR);

        R.lightmap_texture = gl.createTexture();
        GL.Bind(0, R.lightmap_texture);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.LINEAR);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.LINEAR);

        R.dlightmap_texture = gl.createTexture();
        GL.Bind(0, R.dlightmap_texture);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.LINEAR);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.LINEAR);

        R.lightstyle_texture = gl.createTexture();
        GL.Bind(0, R.lightstyle_texture);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.NEAREST);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.NEAREST);

        R.fullbright_texture = gl.createTexture();
        GL.Bind(0, R.fullbright_texture);
        gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA, 1, 1, 0, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, new Uint8Array([255, 0, 0, 0]));
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.NEAREST);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.NEAREST);

        R.null_texture = gl.createTexture();
        GL.Bind(0, R.null_texture);
        gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA, 1, 1, 0, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 0]));
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.NEAREST);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.NEAREST);
    }

    static var warprenderbuffer:Renderbuffer;

    static function Init() {
        R.InitTextures();

        Cmd.AddCommand('timerefresh', R.TimeRefresh_f);
        Cmd.AddCommand('pointfile', R.ReadPointFile_f);

        R.waterwarp = Cvar.RegisterVariable('r_waterwarp', '1');
        R.fullbright = Cvar.RegisterVariable('r_fullbright', '0');
        R.drawentities = Cvar.RegisterVariable('r_drawentities', '1');
        R.drawviewmodel = Cvar.RegisterVariable('r_drawviewmodel', '1');
        R.novis = Cvar.RegisterVariable('r_novis', '0');
        R.speeds = Cvar.RegisterVariable('r_speeds', '0');
        R.polyblend = Cvar.RegisterVariable('gl_polyblend', '1');
        R.flashblend = Cvar.RegisterVariable('gl_flashblend', '0');
        R.nocolors = Cvar.RegisterVariable('gl_nocolors', '0');

        R.InitParticles();

        GL.CreateProgram('alias',
            ['uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uLightVec', 'uGamma', 'uAmbientLight', 'uShadeLight'],
            ['aPoint', 'aLightNormal', 'aTexCoord'],
            ['tTexture']);
        GL.CreateProgram('brush',
            ['uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uGamma'],
            ['aPoint', 'aTexCoord', 'aLightStyle'],
            ['tTexture', 'tLightmap', 'tDlight', 'tLightStyle']);
        GL.CreateProgram('dlight', ['uOrigin', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uRadius', 'uGamma'], ['aPoint'], []);
        GL.CreateProgram('player',
            ['uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uLightVec', 'uGamma', 'uAmbientLight', 'uShadeLight', 'uTop', 'uBottom'],
            ['aPoint', 'aLightNormal', 'aTexCoord'],
            ['tTexture', 'tPlayer']);
        GL.CreateProgram('sprite', ['uRect', 'uOrigin', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uGamma'], ['aPoint'], ['tTexture']);
        GL.CreateProgram('spriteOriented', ['uRect', 'uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uGamma'], ['aPoint'], ['tTexture']);
        GL.CreateProgram('turbulent',
            ['uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uGamma', 'uTime'],
            ['aPoint', 'aTexCoord'],
            ['tTexture']);
        GL.CreateProgram('warp', ['uRect', 'uOrtho', 'uTime'], ['aPoint'], ['tTexture']);

        R.warpbuffer = gl.createFramebuffer();
        R.warptexture = gl.createTexture();
        GL.Bind(0, R.warptexture);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.LINEAR);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.LINEAR);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_S, RenderingContext.CLAMP_TO_EDGE);
        gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_T, RenderingContext.CLAMP_TO_EDGE);
        R.warprenderbuffer = gl.createRenderbuffer();
        gl.bindRenderbuffer(RenderingContext.RENDERBUFFER, R.warprenderbuffer);
        gl.renderbufferStorage(RenderingContext.RENDERBUFFER, RenderingContext.DEPTH_COMPONENT16, 0, 0);
        gl.bindRenderbuffer(RenderingContext.RENDERBUFFER, null);
        gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, R.warpbuffer);
        gl.framebufferTexture2D(RenderingContext.FRAMEBUFFER, RenderingContext.COLOR_ATTACHMENT0, RenderingContext.TEXTURE_2D, R.warptexture, 0);
        gl.framebufferRenderbuffer(RenderingContext.FRAMEBUFFER, RenderingContext.DEPTH_ATTACHMENT, RenderingContext.RENDERBUFFER, R.warprenderbuffer);
        gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, null);

        R.dlightvecs = gl.createBuffer();
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, R.dlightvecs);
        gl.bufferData(RenderingContext.ARRAY_BUFFER, new Float32Array([
            0.0, -1.0, 0.0,
            0.0, 0.0, 1.0,
            -0.382683, 0.0, 0.92388,
            -0.707107, 0.0, 0.707107,
            -0.92388, 0.0, 0.382683,
            -1.0, 0.0, 0.0,
            -0.92388, 0.0, -0.382683,
            -0.707107, 0.0, -0.707107,
            -0.382683, 0.0, -0.92388,
            0.0, 0.0, -1.0,
            0.382683, 0.0, -0.92388,
            0.707107, 0.0, -0.707107,
            0.92388, 0.0, -0.382683,
            1.0, 0.0, 0.0,
            0.92388, 0.0, 0.382683,
            0.707107, 0.0, 0.707107,
            0.382683, 0.0, 0.92388,
            0.0, 0.0, 1.0
        ]), RenderingContext.STATIC_DRAW);

        R.MakeSky();
    }

    static function NewMap() {
        for (i in 0...CL.MAX_LIGHTSTYLES)
            R.lightstylevalue[i] = 12;

        R.ClearParticles();
        R.BuildLightmaps();

        for (i in 0...1048576)
            R.dlightmaps[i] = 0;
        GL.Bind(0, R.dlightmap_texture);
        gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.ALPHA, 1024, 1024, 0, RenderingContext.ALPHA, RenderingContext.UNSIGNED_BYTE, null);
    }

    static function TimeRefresh_f() {
        gl.finish();
        var start = Sys.FloatTime();
        for (i in 0...128) {
            R.refdef.viewangles[1] = i * 2.8125;
            R.RenderView();
        }
        gl.finish();
        var time = Sys.FloatTime() - start;
        Console.Print(time.toFixed(6) + ' seconds (' + (128.0 / time).toFixed(6) + ' fps)\n');
    }

    // part

    static var ramp1 = [0x6f, 0x6d, 0x6b, 0x69, 0x67, 0x65, 0x63, 0x61];
    static var ramp2 = [0x6f, 0x6e, 0x6d, 0x6c, 0x6b, 0x6a, 0x68, 0x66];
    static var ramp3 = [0x6d, 0x6b, 6, 5, 4, 3];
    static var avelocities:Array<Vec>;

    static inline var MAX_PARTICLES = 2048; // default max # of particles at one time
    static inline var ABSOLUTE_MIN_PARTICLES = 512; // no fewer than this no matter what's on the command line
    static inline var NUMVERTEXNORMALS = 162;

    static function InitParticles():Void {
        var numparticles;
        var i = COM.CheckParm('-particles');
        if (i != null) {
            numparticles = Q.atoi(COM.argv[i + 1]);
            if (numparticles < ABSOLUTE_MIN_PARTICLES)
                numparticles = ABSOLUTE_MIN_PARTICLES;
        } else {
            numparticles = MAX_PARTICLES;
        }
        particles = [for (_ in 0...numparticles) new Particle()];


        avelocities = [];
        for (_ in 0...NUMVERTEXNORMALS)
            avelocities.push(Vec.of(Math.random() * 2.56, Math.random() * 2.56, Math.random() * 2.56));

        GL.CreateProgram('particle', ['uOrigin', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uScale', 'uGamma', 'uColor'], ['aPoint'], []);
    }

    static function EntityParticles(ent:Entity):Void {
        var dist = 64;
        var beamlength = 16;
        var allocated = AllocParticles(NUMVERTEXNORMALS);
        for (i in 0...allocated.length) {
            var p = particles[allocated[i]];

            var angle = CL.state.time * avelocities[i][0];
            var sy = Math.sin(angle);
            var cy = Math.cos(angle);
            var angle = CL.state.time * avelocities[i][1];
            var sp = Math.sin(angle);
            var cp = Math.cos(angle);

            p.die = CL.state.time + 0.01;
            p.color = 0x6f;
            p.type = explode;

            p.org.setValues(
                ent.origin[0] + avertexnormals[i][0] * dist + cp * cy * beamlength,
                ent.origin[1] + avertexnormals[i][1] * dist + cp * sy * beamlength,
                ent.origin[2] + avertexnormals[i][2] * dist - sp * beamlength
            );
        }
    }

    static function ClearParticles():Void {
        for (p in particles)
            p.die = -1.0;
    }

    static function ReadPointFile_f() {
        if (!SV.server.active)
            return;
        var name = 'maps/' + PR.GetString(PR.globals.mapname) + '.pts';
        var f = COM.LoadTextFile(name);
        if (f == null) {
            Console.Print('couldn\'t open ' + name + '\n');
            return;
        }
        Console.Print('Reading ' + name + '...\n');
        var f = f.split('\n');
        var c = 0;
        while (c < f.length) {
            var org = f[c].split(' ');
            if (org.length != 3)
                break;
            ++c;
            var p = R.AllocParticles(1);
            if (p.length == 0) {
                Console.Print('Not enough free particles\n');
                break;
            }
            var p = R.particles[p[0]];
            p.type = tracer;
            p.die = 99999.0;
            p.color = -c & 15;
            p.org.setValues(Q.atof(org[0]), Q.atof(org[1]), Q.atof(org[2]));
        }
        Console.Print(c + ' points read\n');
    }

    static function ParseParticleEffect() {
        var org = MSG.ReadVector();
        var dir = Vec.of(MSG.ReadChar() * 0.0625, MSG.ReadChar() * 0.0625, MSG.ReadChar() * 0.0625);
        var msgcount = MSG.ReadByte();
        var color = MSG.ReadByte();
        if (msgcount == 255)
            ParticleExplosion(org);
        else
            RunParticleEffect(org, dir, color, msgcount);
    }

    static function ParticleExplosion(org:Vec):Void {
        var allocated = AllocParticles(1024);
        for (i in 0...allocated.length) {
            var p = particles[allocated[i]];
            p.type = (i & 1) != 0 ? explode : explode2;
            p.die = CL.state.time + 5.0;
            p.color = R.ramp1[0];
            p.ramp = Math.floor(Math.random() * 4.0);
            p.vel.setValues(
                Math.random() * 512.0 - 256.0,
                Math.random() * 512.0 - 256.0,
                Math.random() * 512.0 - 256.0
            );
            p.org.setValues(
                org[0] + Math.random() * 32.0 - 16.0,
                org[1] + Math.random() * 32.0 - 16.0,
                org[2] + Math.random() * 32.0 - 16.0
            );
        }
    }

    static function ParticleExplosion2(org:Vec, colorStart:Int, colorLength:Int):Void {
        var allocated = AllocParticles(512);
        var colorMod = 0;
        for (idx in allocated) {
            var p = particles[idx];
            p.type = blob;
            p.die = CL.state.time + 0.3;
            p.color = colorStart + (colorMod++ % colorLength);
            p.org.setValues(
                org[0] + Math.random() * 32.0 - 16.0,
                org[1] + Math.random() * 32.0 - 16.0,
                org[2] + Math.random() * 32.0 - 16.0
            );
            p.vel.setValues(
                Math.random() * 512.0 - 256.0,
                Math.random() * 512.0 - 256.0,
                Math.random() * 512.0 - 256.0
            );
            p;
        }
    }

    static function BlobExplosion(org:Vec) {
        var allocated = R.AllocParticles(1024);
        for (i in 0...allocated.length) {
            var p = R.particles[allocated[i]];
            p.die = CL.state.time + 1.0 + Math.random() * 0.4;
            if ((i & 1) != 0) {
                p.type = blob;
                p.color = 66 + Math.floor(Math.random() * 7.0);
            } else {
                p.type = blob2;
                p.color = 150 + Math.floor(Math.random() * 7.0);
            }
            p.org.setValues(
                org[0] + Math.random() * 32.0 - 16.0,
                org[1] + Math.random() * 32.0 - 16.0,
                org[2] + Math.random() * 32.0 - 16.0
            );
            p.vel.setValues(
                Math.random() * 512.0 - 256.0,
                Math.random() * 512.0 - 256.0,
                Math.random() * 512.0 - 256.0
            );
        }
    }

    static function RunParticleEffect(org:Vec, dir:Vec, color:Int, count:Int):Void {
        var allocated = AllocParticles(count);
        for (idx in allocated) {
            var p = particles[idx];
            p.type = slowgrav;
            p.die = CL.state.time + 0.6 * Math.random();
            p.color = (color & 0xf8) + Math.floor(Math.random() * 8.0);
            p.org.setValues(
                org[0] + Math.random() * 16.0 - 8.0,
                org[1] + Math.random() * 16.0 - 8.0,
                org[2] + Math.random() * 16.0 - 8.0
            );
            p.vel.setValues(
                dir[0] * 15.0,
                dir[1] * 15.0,
                dir[2] * 15.0
            );
        }
    }

    static function LavaSplash(org:Vec) {
        var allocated = AllocParticles(1024);
        var dir = new Vec();
        var k = 0;
        for (i in -16...16) {
            for (j in -16...16) {
                if (k >= allocated.length)
                    return;
                var p = particles[allocated[k++]];
                p.die = CL.state.time + 2.0 + Math.random() * 0.64;
                p.color = 224 + Math.floor(Math.random() * 8.0);
                p.type = slowgrav;
                dir[0] = (j + Math.random()) * 8.0;
                dir[1] = (i + Math.random()) * 8.0;
                dir[2] = 256.0;
                p.org.setValues(
                    org[0] + dir[0],
                    org[1] + dir[1],
                    org[2] + Math.random() * 64.0
                );
                Vec.Normalize(dir);
                var vel = 50.0 + Math.random() * 64.0;
                p.vel.setValues(
                    dir[0] * vel,
                    dir[1] * vel,
                    dir[2] * vel
                );
            }
        }
    }

    static function TeleportSplash(org:Vec):Void {
        var allocated = R.AllocParticles(896), i, j, k, l = 0;
        var dir = new Vec();
        i = -16;
        while (i < 16) {
            j = -16;
            while (j < 16) {
                k = -24;
                while (k < 32) {
                    if (l >= allocated.length)
                        return;
                    var p = R.particles[allocated[l++]];
                    p.die = CL.state.time + 0.2 + Math.random() * 0.16;
                    p.color = 7 + Math.floor(Math.random() * 8.0);
                    p.type = slowgrav;
                    dir[0] = j * 8.0;
                    dir[1] = i * 8.0;
                    dir[2] = k * 8.0;
                    p.org.setValues(
                        org[0] + i + Math.random() * 4.0,
                        org[1] + j + Math.random() * 4.0,
                        org[2] + k + Math.random() * 4.0
                    );
                    Vec.Normalize(dir);
                    var vel = 50.0 + Math.random() * 64.0;
                    p.vel.setValues(
                        dir[0] * vel,
                        dir[1] * vel,
                        dir[2] * vel
                    );
                    k += 4;
                }
                j += 4;
            }
            i += 4;
        }
    }

    static var tracercount = 0;
    static function RocketTrail(start:Vec, end:Vec, type:Int):Void {
        var vec = Vec.of(end[0] - start[0], end[1] - start[1], end[2] - start[2]);
        var len = Vec.Normalize(vec);
        if (len == 0.0)
            return;

        var allocated;
        if (type == 4)
            allocated = R.AllocParticles(Math.floor(len / 6.0));
        else
            allocated = R.AllocParticles(Math.floor(len / 3.0));

        for (idx in allocated) {
            var p = R.particles[idx];
            p.vel.setVector(Vec.origin);
            p.die = CL.state.time + 2.0;
            switch (type) {
                case 0 | 1:
                    p.ramp = Math.floor(Math.random() * 4.0) + (type << 1);
                    p.color = R.ramp3[Std.int(p.ramp)];
                    p.type = fire;
                    p.org.setValues(
                        start[0] + Math.random() * 6.0 - 3.0,
                        start[1] + Math.random() * 6.0 - 3.0,
                        start[2] + Math.random() * 6.0 - 3.0
                    );
                case 2:
                    p.type = grav;
                    p.color = 67 + Math.floor(Math.random() * 4.0);
                    p.org.setValues(
                        start[0] + Math.random() * 6.0 - 3.0,
                        start[1] + Math.random() * 6.0 - 3.0,
                        start[2] + Math.random() * 6.0 - 3.0
                    );
                case 3 | 5:
                    p.die = CL.state.time + 0.5;
                    p.type = tracer;
                    if (type == 3)
                        p.color = 52 + ((R.tracercount++ & 4) << 1);
                    else
                        p.color = 230 + ((R.tracercount++ & 4) << 1);
                    p.org.setVector(start);
                    if ((R.tracercount & 1) != 0) {
                        p.vel[0] = 30.0 * vec[1];
                        p.vel[2] = -30.0 * vec[0];
                    } else {
                        p.vel[0] = -30.0 * vec[1];
                        p.vel[2] = 30.0 * vec[0];
                    }
                case 4:
                    p.type = grav;
                    p.color = 67 + Math.floor(Math.random() * 4.0);
                    p.org.setValues(
                        start[0] + Math.random() * 6.0 - 3.0,
                        start[1] + Math.random() * 6.0 - 3.0,
                        start[2] + Math.random() * 6.0 - 3.0
                    );
                case 6:
                    p.color = 152 + Math.floor(Math.random() * 4.0);
                    p.type = tracer;
                    p.die = CL.state.time + 0.3;
                    p.org.setValues(
                        start[0] + Math.random() * 16.0 - 8.0,
                        start[1] + Math.random() * 16.0 - 8.0,
                        start[2] + Math.random() * 16.0 - 8.0
                    );
            }
            start[0] += vec[0];
            start[1] += vec[1];
            start[2] += vec[2];
        }
    }

    static function DrawParticles() {
        var program = GL.UseProgram('particle');
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, GL.rect);
        gl.vertexAttribPointer(program.aPoint, 2, RenderingContext.FLOAT, false, 0, 0);
        gl.depthMask(false);
        gl.enable(RenderingContext.BLEND);

        for (p in particles) {
            if (p.die < CL.state.time)
                continue;

            var color = VID.d_8to24table[p.color];
            gl.uniform3f(program.uColor, color & 0xff, (color >> 8) & 0xff, color >> 16);

            gl.uniform3fv(program.uOrigin, p.org);

            var scale = (p.org[0] - R.refdef.vieworg[0]) * R.vpn[0]
                      + (p.org[1] - R.refdef.vieworg[1]) * R.vpn[1]
                      + (p.org[2] - R.refdef.vieworg[2]) * R.vpn[2];
            if (scale < 20.0)
                gl.uniform1f(program.uScale, 1 + 0.08);
            else
                gl.uniform1f(program.uScale, 1 + scale * 0.004);

            scale *= 1.27; // for round particles

            gl.drawArrays(RenderingContext.TRIANGLE_STRIP, 0, 4);
        }

        gl.disable(RenderingContext.BLEND);
        gl.depthMask(true);
    }

    static function AllocParticles(count:Int):Array<Int> {
        var allocated = [];
        for (i in 0...particles.length) {
            if (count == 0)
                return allocated;
            if (particles[i].die < CL.state.time) {
                allocated.push(i);
                count--;
            }
        }
        return allocated;
    }

    // surf

    static var lightmap_modified = new Uint8Array(1024);
    static var lightmaps = new Uint8Array(new ArrayBuffer(4194304));
    static var dlightmaps = new Uint8Array(new ArrayBuffer(1048576));

    static function AddDynamicLights(surf:MSurface):Void {
        var smax = (surf.extents[0] >> 4) + 1;
        var tmax = (surf.extents[1] >> 4) + 1;
        var size = smax * tmax;
        var tex = CL.state.worldmodel.texinfo[surf.texinfo];
        var impact = new Vec(), local = [];

        var blocklights = [];
        for (i in 0...size)
            blocklights[i] = 0;

        for (i in 0...CL.MAX_DLIGHTS) {
            if (((surf.dlightbits >>> i) & 1) == 0)
                continue;
            var light = CL.dlights[i];
            var dist = Vec.DotProduct(light.origin, surf.plane.normal) - surf.plane.dist;
            var rad = light.radius - Math.abs(dist);
            var minlight = light.minlight;
            if (rad < minlight)
                continue;
            minlight = rad - minlight;
            impact[0] = light.origin[0] - surf.plane.normal[0] * dist;
            impact[1] = light.origin[1] - surf.plane.normal[1] * dist;
            impact[2] = light.origin[2] - surf.plane.normal[2] * dist;
            local[0] = Vec.DotProduct(impact, Vec.ofArray(tex.vecs[0])) + tex.vecs[0][3] - surf.texturemins[0];
            local[1] = Vec.DotProduct(impact, Vec.ofArray(tex.vecs[1])) + tex.vecs[1][3] - surf.texturemins[1];
            for (t in 0...tmax) {
                var td = local[1] - (t << 4);
                if (td < 0.0)
                    td = -td;
                var td = Math.floor(td);
                for (s in 0...smax) {
                    var sd = local[0] - (s << 4);
                    if (sd < 0)
                        sd = -sd;
                    var sd = Math.floor(sd);
                    if (sd > td)
                        dist = sd + (td >> 1);
                    else
                        dist = td + (sd >> 1);
                    if (dist < minlight)
                        blocklights[t * smax + s] += Math.floor((rad - dist) * 256.0);
                }
            }
        }

        var i = 0;
        for (t in 0...tmax) {
            var idx = surf.light_t + t;
            if (idx >= 1024)
                Sys.Error('Funny lightmap_modified index: $idx < 1024');
            R.lightmap_modified[idx] = 1;
            var dest = (idx << 10) + surf.light_s;
            for (s in 0...smax) {
                var bl = blocklights[i++] >> 7;
                if (bl > 255)
                    bl = 255;
                R.dlightmaps[dest + s] = bl;
            }
        }
    }

    static function RemoveDynamicLights(surf:MSurface):Void {
        var smax = (surf.extents[0] >> 4) + 1;
        var tmax = (surf.extents[1] >> 4) + 1;
        for (t in 0...tmax) {
            var idx = surf.light_t + t;
            if (idx >= 1024)
                Sys.Error('Funny lightmap_modified index: $idx < 1024');
            R.lightmap_modified[idx] = 1;
            var dest = (idx << 10) + surf.light_s;
            for (s in 0...smax)
                R.dlightmaps[dest + s] = 0;
        }
    }

    static function BuildLightMap(surf:MSurface):Void {
        var smax = (surf.extents[0] >> 4) + 1;
        var tmax = (surf.extents[1] >> 4) + 1;
        var lightmap = surf.lightofs;
        var maps = 0;
        while (maps < surf.styles.length) {
            var dest = (surf.light_t << 12) + (surf.light_s << 2) + maps;
            for (i in 0...tmax) {
                for (j in 0...smax)
                    R.lightmaps[dest + (j << 2)] = R.currentmodel.lightdata[lightmap + j];
                lightmap += smax;
                dest += 4096;
            }
            maps++;
        }
        while (maps <= 3) {
            var dest = (surf.light_t << 12) + (surf.light_s << 2) + maps;
            for (i in 0...tmax) {
                for (j in 0...smax)
                    R.lightmaps[dest + (j << 2)] = 0;
                dest += 4096;
            }
            maps++;
        }
    }

    static function TextureAnimation(base:MTexture):MTexture {
        var frame = 0;
        if (base.anim_base != null) {
            frame = base.anim_frame;
            base = R.currententity.model.textures[base.anim_base];
        }
        var anims = base.anims;
        if (anims == null)
            return base;
        if ((R.currententity.frame != 0) && (base.alternate_anims.length != 0))
            anims = base.alternate_anims;
        return R.currententity.model.textures[anims[(Math.floor(CL.state.time * 5.0) + frame) % anims.length]];
    }

    static function DrawBrushModel(e:Entity):Void {
        var clmodel = e.model;

        if (clmodel.submodel) {
            if (R.CullBox(
                Vec.of(
                    e.origin[0] + clmodel.mins[0],
                    e.origin[1] + clmodel.mins[1],
                    e.origin[2] + clmodel.mins[2]
                ),
                Vec.of(
                    e.origin[0] + clmodel.maxs[0],
                    e.origin[1] + clmodel.maxs[1],
                    e.origin[2] + clmodel.maxs[2]
                )))
                return;
        } else {
            if (R.CullBox(
                Vec.of(
                    e.origin[0] - clmodel.radius,
                    e.origin[1] - clmodel.radius,
                    e.origin[2] - clmodel.radius
                ),
                Vec.of(
                    e.origin[0] + clmodel.radius,
                    e.origin[1] + clmodel.radius,
                    e.origin[2] + clmodel.radius
                )))
                return;
        }

        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, clmodel.cmds);
        var viewMatrix = GL.RotationMatrix(e.angles[0], e.angles[1], e.angles[2]);

        var program = GL.UseProgram('brush');
        gl.uniform3fv(program.uOrigin, e.origin);
        gl.uniformMatrix3fv(program.uAngles, false, viewMatrix);
        gl.vertexAttribPointer(program.aPoint, 3, RenderingContext.FLOAT, false, 44, 0);
        gl.vertexAttribPointer(program.aTexCoord, 4, RenderingContext.FLOAT, false, 44, 12);
        gl.vertexAttribPointer(program.aLightStyle, 4, RenderingContext.FLOAT, false, 44, 28);
        if (R.fullbright.value != 0 || clmodel.lightdata == null)
            GL.Bind(program.tLightmap, R.fullbright_texture);
        else
            GL.Bind(program.tLightmap, R.lightmap_texture);
        GL.Bind(program.tDlight, ((R.flashblend.value == 0) && (clmodel.submodel)) ? R.dlightmap_texture : R.null_texture);
        GL.Bind(program.tLightStyle, R.lightstyle_texture);
        for (i in 0...clmodel.chains.length) {
            var chain = clmodel.chains[i];
            var texture = R.TextureAnimation(clmodel.textures[chain[0]]);
            if (texture.turbulent)
                continue;
            R.c_brush_verts += chain[2];
            GL.Bind(program.tTexture, texture.texturenum);
            gl.drawArrays(RenderingContext.TRIANGLES, chain[1], chain[2]);
        }

        program = GL.UseProgram('turbulent');
        gl.uniform3f(program.uOrigin, 0.0, 0.0, 0.0);
        gl.uniformMatrix3fv(program.uAngles, false, viewMatrix);
        gl.uniform1f(program.uTime, Host.realtime % (Math.PI * 2.0));
        gl.vertexAttribPointer(program.aPoint, 3, RenderingContext.FLOAT, false, 20, e.model.waterchain);
        gl.vertexAttribPointer(program.aTexCoord, 2, RenderingContext.FLOAT, false, 20, e.model.waterchain + 12);
        for (i in 0...clmodel.chains.length) {
            var chain = clmodel.chains[i];
            var texture = clmodel.textures[chain[0]];
            if (!texture.turbulent)
                continue;
            R.c_brush_verts += chain[2];
            GL.Bind(program.tTexture, texture.texturenum);
            gl.drawArrays(RenderingContext.TRIANGLES, chain[1], chain[2]);
        }
    }

    static function RecursiveWorldNode(node:MNode):Void {
        if (node.contents == Contents.solid)
            return;
        if (node.contents < 0) {
            if (node.markvisframe != R.visframecount)
                return;
            node.visframe = R.visframecount;
            if (node.skychain != node.waterchain)
                R.drawsky = true;
            return;
        }
        R.RecursiveWorldNode(node.children[0]);
        R.RecursiveWorldNode(node.children[1]);
    }

    static function DrawWorld() {
        var clmodel = CL.state.worldmodel;
        R.currententity = CL.entities[0];
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, clmodel.cmds);

        var program = GL.UseProgram('brush');
        gl.uniform3f(program.uOrigin, 0.0, 0.0, 0.0);
        gl.uniformMatrix3fv(program.uAngles, false, GL.identity);
        gl.vertexAttribPointer(program.aPoint, 3, RenderingContext.FLOAT, false, 44, 0);
        gl.vertexAttribPointer(program.aTexCoord, 4, RenderingContext.FLOAT, false, 44, 12);
        gl.vertexAttribPointer(program.aLightStyle, 4, RenderingContext.FLOAT, false, 44, 28);
        if (R.fullbright.value != 0 || clmodel.lightdata == null)
            GL.Bind(program.tLightmap, R.fullbright_texture);
        else
            GL.Bind(program.tLightmap, R.lightmap_texture);
        if (R.flashblend.value == 0)
            GL.Bind(program.tDlight, R.dlightmap_texture);
        else
            GL.Bind(program.tDlight, R.null_texture);
        GL.Bind(program.tLightStyle, R.lightstyle_texture);
        for (leaf in clmodel.leafs) {
            if (leaf.visframe != R.visframecount || leaf.skychain == 0)
                continue;
            if (CullBox(leaf.mins, leaf.maxs))
                continue;
            for (j in 0...leaf.skychain) {
                var cmds = leaf.cmds[j];
                R.c_brush_verts += cmds[2];
                GL.Bind(program.tTexture, TextureAnimation(clmodel.textures[cmds[0]]).texturenum);
                gl.drawArrays(RenderingContext.TRIANGLES, cmds[1], cmds[2]);
            }
        }

        program = GL.UseProgram('turbulent');
        gl.uniform3f(program.uOrigin, 0.0, 0.0, 0.0);
        gl.uniformMatrix3fv(program.uAngles, false, GL.identity);
        gl.uniform1f(program.uTime, Host.realtime % (Math.PI * 2.0));
        gl.vertexAttribPointer(program.aPoint, 3, RenderingContext.FLOAT, false, 20, clmodel.waterchain);
        gl.vertexAttribPointer(program.aTexCoord, 2, RenderingContext.FLOAT, false, 20, clmodel.waterchain + 12);
        for (leaf in clmodel.leafs) {
            if (leaf.visframe != R.visframecount || leaf.waterchain == leaf.cmds.length)
                continue;
            if (CullBox(leaf.mins, leaf.maxs))
                continue;
            for (j in leaf.waterchain...leaf.cmds.length) {
                var cmds = leaf.cmds[j];
                R.c_brush_verts += cmds[2];
                GL.Bind(program.tTexture, clmodel.textures[cmds[0]].texturenum);
                gl.drawArrays(RenderingContext.TRIANGLES, cmds[1], cmds[2]);
            }
        }
    }

    static function MarkLeaves() {
        if ((R.oldviewleaf == R.viewleaf) && (R.novis.value == 0))
            return;
        ++R.visframecount;
        R.oldviewleaf = R.viewleaf;
        var vis = (R.novis.value != 0) ? Mod.novis : Mod.LeafPVS(R.viewleaf, CL.state.worldmodel);
        for (i in 0...CL.state.worldmodel.leafs.length) {
            if ((vis[i >> 3] & (1 << (i & 7))) == 0)
                continue;
            var node:MNode = CL.state.worldmodel.leafs[i + 1];
            while (node != null) {
                if (node.markvisframe == R.visframecount)
                    break;
                node.markvisframe = R.visframecount;
                node = node.parent;
            }
        }
        do
        {
            if (R.novis.value != 0)
                break;
            var p = [R.refdef.vieworg[0], R.refdef.vieworg[1], R.refdef.vieworg[2]];
            var leaf;
            if (R.viewleaf.contents <= Contents.water) {
                leaf = Mod.PointInLeaf(Vec.of(R.refdef.vieworg[0], R.refdef.vieworg[1], R.refdef.vieworg[2] + 16.0), CL.state.worldmodel);
                if (leaf.contents <= Contents.water)
                    break;
            } else {
                leaf = Mod.PointInLeaf(Vec.of(R.refdef.vieworg[0], R.refdef.vieworg[1], R.refdef.vieworg[2] - 16.0), CL.state.worldmodel);
                if (leaf.contents > Contents.water)
                    break;
            }
            if (leaf == R.viewleaf)
                break;
            vis = Mod.LeafPVS(leaf, CL.state.worldmodel);
            for (i in 0...CL.state.worldmodel.leafs.length) {
                if ((vis[i >> 3] & (1 << (i & 7))) == 0)
                    continue;
                var node:MNode = CL.state.worldmodel.leafs[i + 1];
                while (node != null) {
                    if (node.markvisframe == R.visframecount)
                        break;
                    node.markvisframe = R.visframecount;
                    node = node.parent;
                }
            }
        } while (false);
        R.drawsky = false;
        R.RecursiveWorldNode(CL.state.worldmodel.nodes[0]);
    }

    static var drawsky:Bool;

    static function AllocBlock(surf:MSurface) {
        var w = (surf.extents[0] >> 4) + 1;
        var h = (surf.extents[1] >> 4) + 1;
        var x, y;
        var best = 1024;
        for (i in 0...(1024 - w)) {
            var best2 = 0;
            var j = 0;
            while (j < w) {
                if (R.allocated[i + j] >= best)
                    break;
                if (R.allocated[i + j] > best2)
                    best2 = R.allocated[i + j];
                j++;
            }
            if (j == w) {
                x = i;
                y = best = best2;
            }
        }
        best += h;
        if (best > 1024)
            Sys.Error('AllocBlock: full');
        for (i in 0...w)
            R.allocated[x + i] = best;
        surf.light_s = x;
        surf.light_t = y;
    }

    // Based on Quake 2 polygon generation algorithm by Toji - http://blog.tojicode.com/2010/06/quake-2-bsp-quite-possibly-worst-format.html
    static function BuildSurfaceDisplayList(fa:MSurface):Void {
        fa.verts = [];
        if (fa.numedges <= 2)
            return;
        var texinfo = R.currentmodel.texinfo[fa.texinfo];
        var texture = R.currentmodel.textures[texinfo.texture];
        for (i in 0...fa.numedges) {
            var index = R.currentmodel.surfedges[fa.firstedge + i];
            var vec;
            if (index > 0)
                vec = R.currentmodel.vertexes[R.currentmodel.edges[index][0]];
            else
                vec = R.currentmodel.vertexes[R.currentmodel.edges[-index][1]];
            var vert = [vec[0], vec[1], vec[2]];
            if (!fa.sky) {
                var s = Vec.DotProduct(vec, Vec.ofArray(texinfo.vecs[0])) + texinfo.vecs[0][3];
                var t = Vec.DotProduct(vec, Vec.ofArray(texinfo.vecs[1])) + texinfo.vecs[1][3];
                vert[3] = s / texture.width;
                vert[4] = t / texture.height;
                if (!fa.turbulent) {
                    vert[5] = (s - fa.texturemins[0] + (fa.light_s << 4) + 8.0) / 16384.0;
                    vert[6] = (t - fa.texturemins[1] + (fa.light_t << 4) + 8.0) / 16384.0;
                }
            }
            if (i >= 3) {
                fa.verts[fa.verts.length] = fa.verts[0];
                fa.verts[fa.verts.length] = fa.verts[fa.verts.length - 2];
            }
            fa.verts[fa.verts.length] = vert;
        }
    }

    static var allocated:Array<Int>;
    static var currentmodel:MModel;

    static function BuildLightmaps():Void {
        R.allocated = [];
        for (i in 0...1024)
            R.allocated[i] = 0;

        for (i in 1...CL.state.model_precache.length) {
            R.currentmodel = CL.state.model_precache[i];
            if (R.currentmodel.type != brush)
                continue;
            if (R.currentmodel.name.charCodeAt(0) != 42) {
                for (j in 0...R.currentmodel.faces.length) {
                    var surf = R.currentmodel.faces[j];
                    if (!surf.sky && !surf.turbulent) {
                        R.AllocBlock(surf);
                        if (R.currentmodel.lightdata != null)
                            R.BuildLightMap(surf);
                    }
                    R.BuildSurfaceDisplayList(surf);
                }
            }
            if (i == 1)
                R.MakeWorldModelDisplayLists(R.currentmodel);
            else
                R.MakeBrushModelDisplayLists(R.currentmodel);
        }

        GL.Bind(0, R.lightmap_texture);
        gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA, 1024, 1024, 0, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, R.lightmaps);
    }

    // scan

    static function WarpScreen() {
        gl.finish();
        gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, null);
        gl.bindRenderbuffer(RenderingContext.RENDERBUFFER, null);
        var program = GL.UseProgram('warp');
        var vrect = R.refdef.vrect;
        gl.uniform4f(program.uRect, vrect.x, vrect.y, vrect.width, vrect.height);
        gl.uniform1f(program.uTime, Host.realtime % (Math.PI * 2.0));
        GL.Bind(program.tTexture, R.warptexture);
        gl.clear(RenderingContext.COLOR_BUFFER_BIT);
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, GL.rect);
        gl.vertexAttribPointer(program.aPoint, 2, RenderingContext.FLOAT, false, 0, 0);
        gl.drawArrays(RenderingContext.TRIANGLE_STRIP, 0, 4);
    }

    // warp

    static function MakeSky() {
        var sin = [0.0, 0.19509, 0.382683, 0.55557, 0.707107, 0.831470, 0.92388, 0.980785, 1.0];
        var vecs = [];

        var i = 0;
        while (i < 7) {
            vecs = vecs.concat(
            [
                0.0, 0.0, 1.0,
                sin[i + 2] * 0.19509, sin[6 - i] * 0.19509, 0.980785,
                sin[i] * 0.19509, sin[8 - i] * 0.19509, 0.980785
            ]);
            for (j in 0...7) {
                vecs = vecs.concat(
                [
                    sin[i] * sin[8 - j], sin[8 - i] * sin[8 - j], sin[j],
                    sin[i] * sin[7 - j], sin[8 - i] * sin[7 - j], sin[j + 1],
                    sin[i + 2] * sin[7 - j], sin[6 - i] * sin[7 - j], sin[j + 1],

                    sin[i] * sin[8 - j], sin[8 - i] * sin[8 - j], sin[j],
                    sin[i + 2] * sin[7 - j], sin[6 - i] * sin[7 - j], sin[j + 1],
                    sin[i + 2] * sin[8 - j], sin[6 - i] * sin[8 - j], sin[j]
                ]);
            }
            i += 2;
        }

        GL.CreateProgram('sky', ['uViewAngles', 'uPerspective', 'uScale', 'uGamma', 'uTime'], ['aPoint'], ['tSolid', 'tAlpha']);
        GL.CreateProgram('skyChain', ['uViewOrigin', 'uViewAngles', 'uPerspective'], ['aPoint'], []);

        R.skyvecs = gl.createBuffer();
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, R.skyvecs);
        gl.bufferData(RenderingContext.ARRAY_BUFFER, new Float32Array(vecs), RenderingContext.STATIC_DRAW);
    }

    static function DrawSkyBox() {
        if (!R.drawsky)
            return;

        gl.colorMask(false, false, false, false);
        var clmodel:MModel = CL.state.worldmodel;
        var program = GL.UseProgram('skyChain');
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, clmodel.cmds);
        gl.vertexAttribPointer(program.aPoint, 3, RenderingContext.FLOAT, false, 12, clmodel.skychain);
        for (i in 0...clmodel.leafs.length) {
            var leaf = clmodel.leafs[i];
            if ((leaf.visframe != R.visframecount) || (leaf.skychain == leaf.waterchain))
                continue;
            if (R.CullBox(leaf.mins, leaf.maxs))
                continue;
            for (j in leaf.skychain...leaf.waterchain) {
                var cmds = leaf.cmds[j];
                gl.drawArrays(RenderingContext.TRIANGLES, cmds[0], cmds[1]);
            }
        }
        gl.colorMask(true, true, true, true);

        gl.depthFunc(RenderingContext.GREATER);
        gl.depthMask(false);
        gl.disable(RenderingContext.CULL_FACE);

        program = GL.UseProgram('sky');
        gl.uniform2f(program.uTime, (Host.realtime * 0.125) % 1.0, (Host.realtime * 0.03125) % 1.0);
        GL.Bind(program.tSolid, R.solidskytexture);
        GL.Bind(program.tAlpha, R.alphaskytexture);
        gl.bindBuffer(RenderingContext.ARRAY_BUFFER, R.skyvecs);
        gl.vertexAttribPointer(program.aPoint, 3, RenderingContext.FLOAT, false, 12, 0);

        gl.uniform3f(program.uScale, 2.0, -2.0, 1.0);
        gl.drawArrays(RenderingContext.TRIANGLES, 0, 180);
        gl.uniform3f(program.uScale, 2.0, -2.0, -1.0);
        gl.drawArrays(RenderingContext.TRIANGLES, 0, 180);

        gl.uniform3f(program.uScale, 2.0, 2.0, 1.0);
        gl.drawArrays(RenderingContext.TRIANGLES, 0, 180);
        gl.uniform3f(program.uScale, 2.0, 2.0, -1.0);
        gl.drawArrays(RenderingContext.TRIANGLES, 0, 180);

        gl.uniform3f(program.uScale, -2.0, -2.0, 1.0);
        gl.drawArrays(RenderingContext.TRIANGLES, 0, 180);
        gl.uniform3f(program.uScale, -2.0, -2.0, -1.0);
        gl.drawArrays(RenderingContext.TRIANGLES, 0, 180);

        gl.uniform3f(program.uScale, -2.0, 2.0, 1.0);
        gl.drawArrays(RenderingContext.TRIANGLES, 0, 180);
        gl.uniform3f(program.uScale, -2.0, 2.0, -1.0);
        gl.drawArrays(RenderingContext.TRIANGLES, 0, 180);

        gl.enable(RenderingContext.CULL_FACE);
        gl.depthMask(true);
        gl.depthFunc(RenderingContext.LESS);
    }

    static function InitSky(src:Uint8Array) {
        var trans = new ArrayBuffer(65536);
        var trans32 = new Uint32Array(trans);

        for (i in 0...128) {
            for (j in 0...128)
                trans32[(i << 7) + j] = COM.LittleLong(VID.d_8to24table[src[(i << 8) + j + 128]] + 0xff000000);
        }
        GL.Bind(0, R.solidskytexture);
        gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA, 128, 128, 0, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, new Uint8Array(trans));
        gl.generateMipmap(RenderingContext.TEXTURE_2D);

        for (i in 0...128) {
            for (j in 0...128) {
                var p = (i << 8) + j;
                if (src[p] != 0)
                    trans32[(i << 7) + j] = COM.LittleLong(VID.d_8to24table[src[p]] + 0xff000000);
                else
                    trans32[(i << 7) + j] = 0;
            }
        }
        GL.Bind(0, R.alphaskytexture);
        gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA, 128, 128, 0, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, new Uint8Array(trans));
        gl.generateMipmap(RenderingContext.TEXTURE_2D);
    }
}