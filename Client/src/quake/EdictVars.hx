package quake;

import js.html.ArrayBuffer;
import js.html.Float32Array;
import js.html.Int32Array;

@:build(quake.EdictVarsMacro.build())
class EdictVars {
    public var buffer(default,null):ArrayBuffer;
    public var floats(default,null):Float32Array;
    public var ints(default,null):Int32Array;

    public function new(buf) {
        buffer = buf;
        floats = new Float32Array(buf);
        ints = new Int32Array(buf);
    }
}
