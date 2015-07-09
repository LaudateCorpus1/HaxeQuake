package quake;

class PRMacro {
    public static macro function SetEntVarField(field:String) {
        return macro {
            var def = ED.FindField($v{field});
            if (def != null) EntVarOfs.$field = def.ofs;
        };
    }
}
