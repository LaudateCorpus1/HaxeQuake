package quake;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class GlobalVarsMacro {
    static function build():Array<Field> {
        var fields = Context.getBuildFields();
        switch (Context.getType("quake.GlobalVars.GlobalVarOfs")) {
            case TInst(_.get() => cl, _):
                for (field in cl.statics.get()) {
                    var fieldName = field.name;
                    var fieldType;
                    var viewField;

                    switch (field.meta.get()) {
                        case [{name: "f"}]:
                            fieldType = macro : Float;
                            viewField = "floats";
                        case [{name: "i"}]:
                            fieldType = macro : Int;
                            viewField = "ints";
                        default:
                            throw new Error("Invalid field meta", field.pos);
                    }

                    fields.push({
                        name: fieldName,
                        pos: field.pos,
                        access: [APublic],
                        kind: FProp("get", "set", fieldType)
                    });

                    fields.push({
                        name: "get_" + fieldName,
                        pos: field.pos,
                        access: [AInline],
                        kind: FFun({
                            args: [],
                            ret: fieldType,
                            expr: macro return this.$viewField[quake.GlobalVarOfs.$fieldName]
                        })
                    });

                    fields.push({
                        name: "set_" + fieldName,
                        pos: field.pos,
                        access: [AInline],
                        kind: FFun({
                            args: [{name: "value", type: fieldType}],
                            ret: fieldType,
                            expr: macro return this.$viewField[quake.GlobalVarOfs.$fieldName] = value
                        })
                    });
                }
            default:
                throw false;
        }
        return fields;
    }
}