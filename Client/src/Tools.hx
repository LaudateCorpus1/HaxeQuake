class Tools {
    public static inline function toFixed(f:Float, p:Int):String {
        return (cast f).toFixed(p);
    }

    public static inline function toInt(b:Bool):Int {
        return if (b) 1 else 0;
    }
}
