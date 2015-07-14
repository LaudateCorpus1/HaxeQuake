package quake;

@:publicFields
class DLight {
    var key:Int;
    var die:Float = 0.0;
    var decay:Float;
    var minlight:Float;
    var origin(default,null):Vec;
    var radius:Float = 0.0;
    function new() {
        origin = new Vec();
    }
}