package quake;

@:publicFields
class DLight {
    var key:Int;
    var die:Float;
    var decay:Float;
    var minlight:Float;
    var origin(default,null):Vec;
    var radius:Float;
 
    function new() {
        origin = new Vec();
    }

    inline function alloc(key:Int) {
        this.key = key;
        this.die = 0.0;
        this.radius = 0.0;
        this.decay = 0.0;
        this.minlight = 0.0;
        this.origin[0] = 0.0;
        this.origin[1] = 0.0;
        this.origin[2] = 0.0;
        this.radius = 0.0;
    }
}
