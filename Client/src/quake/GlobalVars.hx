package quake;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

abstract GlobalVars(Void) {
    public inline function new() this = null;

    @:resolve
    macro function resolve(ethis:Expr, field:String):Expr {
        var eIndex = macro GlobalVarOfs.$field;
        var viewField = switch (Context.typeof(eIndex)) {
            case TAbstract(_, [TInst(_.get() => {kind: KExpr({expr: EConst(CString(s))})}, _)]): s;
            default: throw false;
        }
        return macro @:pos(Context.currentPos()) PR.$viewField[$eIndex];
    }
}
