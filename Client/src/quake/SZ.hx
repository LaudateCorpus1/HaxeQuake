package quake;

import js.html.ArrayBuffer;
import js.html.Uint8Array;

@:expose("SZ")
@:publicFields
class SZ {

	static function GetSpace(buf:MSG, length:Int):Int {
		if ((buf.cursize + length) > buf.data.byteLength) {
			if (buf.allowoverflow != true)
				Sys.Error('SZ.GetSpace: overflow without allowoverflow set');
			if (length > buf.data.byteLength)
				Sys.Error('SZ.GetSpace: ' + length + ' is > full buffer size');
			buf.overflowed = true;
			Console.Print('SZ.GetSpace: overflow\n');
			buf.cursize = 0;
		}
		var cursize = buf.cursize;
		buf.cursize += length;
		return cursize;
	}

	static function Write(sb:MSG, data:Uint8Array, length:Int):Void {
		(new Uint8Array(sb.data, SZ.GetSpace(sb, length), length)).set(data.subarray(0, length));
	}

	static function Print(sb:MSG, data:String):Void {
		var buf = new Uint8Array(sb.data);
		var dest;
		if (sb.cursize != 0) {
			if (buf[sb.cursize - 1] == 0)
				dest = SZ.GetSpace(sb, data.length - 1) - 1;
			else
				dest = SZ.GetSpace(sb, data.length);
		} else {
			dest = SZ.GetSpace(sb, data.length);
		}
		for (i in 0...data.length)
			buf[dest + i] = data.charCodeAt(i);
	}
}