package quake;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#else
import quake.PR.PROffset;
#end

abstract GlobalVars(Int) {
    @:resolve
    macro function resolve(ethis:Expr, field:String):Expr {
        var eIndex = macro GlobalVarOfs.$field;
        var viewField = switch (Context.typeof(eIndex)) {
            case TAbstract(_, [TInst(_.get() => {kind: KExpr({expr: EConst(CString(s))})}, _)]): s;
            default: throw false;
        }
        return macro @:pos(Context.currentPos()) PR.$viewField[$eIndex];
    }

    #if !macro
    public inline function SetReturnVector(v:Vec):Void {
        PR._globals_float[OFS_RETURN] = v[0];
        PR._globals_float[OFS_RETURN + 1] = v[1];
        PR._globals_float[OFS_RETURN + 2] = v[2];
    }

    public inline function GetVector(ofs:Int):Vec {
        return Vec.of(PR._globals_float[ofs], PR._globals_float[ofs + 1], PR._globals_float[ofs + 2]);
    }
    #end
}
