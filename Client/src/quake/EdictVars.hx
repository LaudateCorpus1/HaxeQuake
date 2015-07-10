package quake;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
typedef Edict = Dynamic;
#end

abstract EdictVars(Edict) {
    public inline function new(e) this = e;

    @:resolve
    macro function resolve(ethis:Expr, field:String):Expr {
        var eIndex = macro EdictVarOfs.$field;
        var viewField = switch (Context.typeof(eIndex)) {
            case TAbstract(_, [TInst(_.get() => {kind: KExpr({expr: EConst(CString(s))})}, _)]): s;
            default: throw false;
        }
        return macro (@:privateAccess (cast $ethis : Edict).$viewField)[$eIndex];
    }
}