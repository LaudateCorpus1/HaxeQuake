class Tools {
    public static inline function clear<T>(a:Array<T>):Void {
        #if js
        (cast a).length = 0;
        #else
        #error "TODO"
        #end
    }

    public static inline function toFixed(f:Float, p:Int):String {
        #if js
        return (cast f).toFixed(p);
        #else
        #error "TODO"
        #end
    }

    public static inline function toInt(b:Bool):Int {
        return if (b) 1 else 0;
    }
}
