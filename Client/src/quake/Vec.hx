package quake;

abstract Vec(Array<Float>) from Array<Float> {
    @:arrayAccess function get(i:Int):Float return this[i];
    @:arrayAccess function set(i:Int, v:Float):Float return this[i] = v;
}