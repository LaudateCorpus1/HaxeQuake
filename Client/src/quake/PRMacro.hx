package quake;

class PRMacro {
    public static macro function SetEntVarField(field:String) {
        return macro {
            var def = ED.FindField($v{field});
            if (def != null) EdictVarOfs.$field = cast def.ofs;
        };
    }
}
