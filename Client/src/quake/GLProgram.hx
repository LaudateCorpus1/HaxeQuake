package quake;

import js.html.webgl.Program;
import js.html.webgl.UniformLocation;
import js.html.webgl.RenderingContext;

typedef GLTex = Int;
typedef GLUni = UniformLocation;
typedef GLAtt = Int;

@:allow(quake.GL)
@:autoBuild(quake.GLProgramMacro.build())
class GLProgram implements Dynamic<haxe.extern.EitherType<UniformLocation,Int>> {
    public var program(default,null):Program;

    function prepareShader(srcVert:String, srcFrag:String):Void {
        program = GL.gl.createProgram();
        var vsh = GL.gl.createShader(RenderingContext.VERTEX_SHADER);
        GL.gl.shaderSource(vsh, srcVert);
        GL.gl.compileShader(vsh);
        if (!GL.gl.getShaderParameter(vsh, RenderingContext.COMPILE_STATUS))
            Sys.Error('Error compiling shader: ' + GL.gl.getShaderInfoLog(vsh));

        var fsh = GL.gl.createShader(RenderingContext.FRAGMENT_SHADER);
        GL.gl.shaderSource(fsh, srcFrag);
        GL.gl.compileShader(fsh);
        if (!GL.gl.getShaderParameter(fsh, RenderingContext.COMPILE_STATUS))
            Sys.Error('Error compiling shader: ' + GL.gl.getShaderInfoLog(fsh));

        GL.gl.attachShader(program, vsh);
        GL.gl.attachShader(program, fsh);

        GL.gl.linkProgram(program);
        if (!GL.gl.getProgramParameter(program, RenderingContext.LINK_STATUS))
            Sys.Error('Error linking program: ' + GL.gl.getProgramInfoLog(program));
        GL.gl.useProgram(program);
    }

    function use():Void throw "abstract";
    function unbind():Void throw "abstract";
}
