package quake;

import quake.GL.GLProgram;

class GLPrograms {
    public static var character(default,null):GLProgram;
    public static var fill(default,null):GLProgram;
    public static var pic(default,null):GLProgram;
    public static var picTranslate(default,null):GLProgram;
    public static var particle(default,null):GLProgram;
    public static var alias(default,null):GLProgram;
    public static var brush(default,null):GLProgram;
    public static var dlight(default,null):GLProgram;
    public static var player(default,null):GLProgram;
    public static var sprite(default,null):GLProgram;
    public static var spriteOriented(default,null):GLProgram;
    public static var turbulent(default,null):GLProgram;
    public static var warp(default,null):GLProgram;
    public static var sky(default,null):GLProgram;
    public static var skyChain(default,null):GLProgram;

    @:access(quake.GL.CreateProgram)
    public static function init() {
        character = GL.CreateProgram('character', ['uCharacter', 'uDest', 'uOrtho'], ['aPoint'], ['tTexture']);
        fill = GL.CreateProgram('fill', ['uRect', 'uOrtho', 'uColor'], ['aPoint'], []);
        pic = GL.CreateProgram('pic', ['uRect', 'uOrtho'], ['aPoint'], ['tTexture']);
        picTranslate = GL.CreateProgram('picTranslate', ['uRect', 'uOrtho', 'uTop', 'uBottom'], ['aPoint'], ['tTexture', 'tTrans']);
        particle = GL.CreateProgram('particle', ['uOrigin', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uScale', 'uGamma', 'uColor'], ['aPoint'], []);
        alias = GL.CreateProgram('alias', ['uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uLightVec', 'uGamma', 'uAmbientLight', 'uShadeLight'], ['aPoint', 'aLightNormal', 'aTexCoord'], ['tTexture']);
        brush = GL.CreateProgram('brush', ['uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uGamma'], ['aPoint', 'aTexCoord', 'aLightStyle'], ['tTexture', 'tLightmap', 'tDlight', 'tLightStyle']);
        dlight = GL.CreateProgram('dlight', ['uOrigin', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uRadius', 'uGamma'], ['aPoint'], []);
        player = GL.CreateProgram('player', ['uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uLightVec', 'uGamma', 'uAmbientLight', 'uShadeLight', 'uTop', 'uBottom'], ['aPoint', 'aLightNormal', 'aTexCoord'], ['tTexture', 'tPlayer']);
        sprite = GL.CreateProgram('sprite', ['uRect', 'uOrigin', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uGamma'], ['aPoint'], ['tTexture']);
        spriteOriented = GL.CreateProgram('spriteOriented', ['uRect', 'uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uGamma'], ['aPoint'], ['tTexture']);
        turbulent = GL.CreateProgram('turbulent', ['uOrigin', 'uAngles', 'uViewOrigin', 'uViewAngles', 'uPerspective', 'uGamma', 'uTime'], ['aPoint', 'aTexCoord'], ['tTexture']);
        warp = GL.CreateProgram('warp', ['uRect', 'uOrtho', 'uTime'], ['aPoint'], ['tTexture']);
        sky = GL.CreateProgram('sky', ['uViewAngles', 'uPerspective', 'uScale', 'uGamma', 'uTime'], ['aPoint'], ['tSolid', 'tAlpha']);
        skyChain = GL.CreateProgram('skyChain', ['uViewOrigin', 'uViewAngles', 'uPerspective'], ['aPoint'], []);
    }
}
