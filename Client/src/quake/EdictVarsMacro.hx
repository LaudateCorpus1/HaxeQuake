package quake;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;

class EdictVarsMacro {
    static function build():Array<Field> {
        var fields = Context.getBuildFields();
        switch (Context.getType("EdictVarOfs")) {
            case TInst(_.get() => cl, _):
                for (field in cl.statics.get()) {
                    var fieldName = field.name;
                    var fieldType;
                    var viewField;

                    switch (field.meta.get()) {
                        case [{name: "f"}]:
                            fieldType = macro : Float;
                            viewField = "_v_float";
                        case [{name: "i"}]:
                            fieldType = macro : Int;
                            viewField = "_v_int";
                        default:
                            throw new Error("Invalid field meta", field.pos);
                    }

                    inline function mod(m) return #if (haxe_ver < 3.3) [m, AStatic] #else [m] #end;
                    var meta = #if (haxe_ver < 3.3) [{name: ":impl", pos: field.pos}] #else [] #end;
                    var firstArgs = #if (haxe_ver < 3.3) [{name: "this", type: null}] #else [] #end;

                    fields.push({
                        name: fieldName,
                        pos: field.pos,
                        access: mod(APublic),
                        kind: FProp("get", "set", fieldType),
                        meta: meta
                    });

                    fields.push({
                        name: "get_" + fieldName,
                        pos: field.pos,
                        access: mod(AInline),
                        kind: FFun({
                            args: firstArgs,
                            ret: fieldType,
                            expr: macro return this.$viewField[quake.EdictVarOfs.$fieldName]
                        }),
                        meta: meta
                    });

                    fields.push({
                        name: "set_" + fieldName,
                        pos: field.pos,
                        access: mod(AInline),
                        kind: FFun({
                            args: firstArgs.concat([{name: "value", type: fieldType}]),
                            ret: fieldType,
                            expr: macro return this.$viewField[quake.EdictVarOfs.$fieldName] = value
                        }),
                        meta: meta
                    });
                }
            default:
                throw false;
        }
        return fields;
    }
}
