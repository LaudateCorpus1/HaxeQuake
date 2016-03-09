package quake;

import haxe.macro.Context;
import haxe.macro.Expr;

class GlobalVarsMacro {
    static function build():Array<Field> {
        var fields = Context.getBuildFields();
        var offset = 28;
        var addedFields = [];
        for (field in fields) {
            switch (field.kind) {
                case FVar(ct, null):
                    var viewField = switch (ct) {
                        case TPath({name: "Float"}): "floats";
                        case TPath({name: "Int"}): "ints";
                        default: continue;
                    }
                    field.kind = FProp("get", "set", ct);
                    field.access = [APublic];
                    addedFields.push({
                        pos: field.pos,
                        name: "get_" + field.name,
                        access: [APrivate, AInline],
                        kind: FFun({
                            ret: ct,
                            args: [],
                            expr: macro return this.$viewField[$v{offset}]
                        })
                    });
                    addedFields.push({
                        pos: field.pos,
                        name: "set_" + field.name,
                        access: [APrivate, AInline],
                        kind: FFun({
                            ret: ct,
                            args: [{name: "value", type: ct}],
                            expr: macro return this.$viewField[$v{offset}] = value
                        })
                    });
                    offset++;
                default:
            }
        }
        return fields.concat(addedFields);
    }
}
