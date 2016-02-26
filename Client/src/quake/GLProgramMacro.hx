package quake;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;

class GLProgramMacro {
    static var shadersDir = Context.resolvePath("shaders");

    static function build() {
        var fields = Context.getBuildFields();
        var cls = Context.getLocalClass().get();
        var shaderMeta = cls.meta.extract(":shader");
        var shaderName = switch (shaderMeta) {
            case [{name: ":shader", params: [{expr: EConst(CString(s))}]}]: s;
            default: throw new Error("No @:shader(\"name\") meta or it's invalid", cls.pos);
        }

        var path = shadersDir + "/" + shaderName;
        var vert = sys.io.File.getContent(path + ".vert");
        var frag = sys.io.File.getContent(path + ".frag");

        var ctorExprs = [macro prepareShader($v{vert}, $v{frag})];
        var bindExprs = [macro quake.GL.gl.useProgram(this.program)];
        var unbindExprs = [];
        var texNum = 0;

        for (field in fields) {
            switch (field.kind) {
                case FVar(ct, _):
                    switch (ct.toType()) {
                        case TType(_.get() => dt, _):
                            var name = field.name;
                            switch (dt.name) {
                                case "GLUni":
                                    ctorExprs.push(macro this.$name = quake.GL.gl.getUniformLocation(this.program, $v{name}));
                                case "GLAtt":
                                    ctorExprs.push(macro this.$name = quake.GL.gl.getAttribLocation(this.program, $v{name}));
                                    bindExprs.push(macro quake.GL.gl.enableVertexAttribArray(this.$name));
                                    unbindExprs.push(macro quake.GL.gl.disableVertexAttribArray(this.$name));
                                case "GLTex":
                                    var id = texNum++;
                                    ctorExprs.push(macro this.$name = $v{id});
                                    ctorExprs.push(macro quake.GL.gl.uniform1i(GL.gl.getUniformLocation(this.program, $v{name}), $v{id}));
                                default:
                                    continue;
                            }
                            field.kind = FProp("default", "null", ct);
                            field.access.push(APublic);
                        default:
                    }
                default:
            }
        }

        var pos = Context.currentPos();
        fields = fields.concat([
            {
                pos: pos,
                name: "new",
                access: [APublic],
                kind: FFun({
                    ret: null,
                    args: [],
                    expr: macro $b{ctorExprs}
                })
            },
            {
                pos: pos,
                name: "use",
                access: [AOverride],
                kind: FFun({
                    ret: null,
                    args: [],
                    expr: macro $b{bindExprs}
                })
            },
            {
                pos: pos,
                name: "unbind",
                access: [AOverride],
                kind: FFun({
                    ret: null,
                    args: [],
                    expr: macro $b{unbindExprs}
                })
            }
        ]);

        return fields;
    }
}
#end
