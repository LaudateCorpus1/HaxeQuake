package quake;

import js.html.webgl.Program;
import js.html.webgl.UniformLocation;
import js.html.webgl.RenderingContext;

typedef GLTex = Int;
typedef GLUni = UniformLocation;
typedef GLAtt = Int;

@:autoBuild(quake.GLProgramMacro.build())
class GLProgram {
    var program:Program;

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

    public inline function use():Void {
        GL.gl.useProgram(program);
    }

    @:allow(quake.GL)
    function bind():Void {}

    @:allow(quake.GL)
    function unbind():Void {}

    public function setOrtho(ortho:Array<Float>):Void {}
    public function setGamma(gamma:Float):Void {}
    public function setViewOrigin(v:Vec):Void {}
    public function setViewAngles(v:Array<Float>):Void {}
    public function setPerspective(v:Array<Float>):Void {}
}
