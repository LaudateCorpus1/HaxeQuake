package quake;

@:build(quake.EdictVarsMacro.build())
abstract EdictVars(Edict) {
    public inline function new(e) this = e;
}
