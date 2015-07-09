package quake;

import js.html.ArrayBuffer;
import js.html.DataView;
import js.html.Uint8Array;
import js.html.Int8Array;


@:publicFields
class MSG {
	var data:ArrayBuffer;
	var cursize:Int;
	var allowoverflow = false;
	var overflowed = false;

	function new(capacity:Int, size = 0) {
		data = new ArrayBuffer(capacity);
		cursize = size;
	}

	static var badread:Bool;
	static var readcount:Int;

	static function WriteChar(sb:MSG, c:Int):Void {
		(new DataView(sb.data)).setInt8(SZ.GetSpace(sb, 1), c);
	}

	static function WriteByte(sb:MSG, c:Int):Void {
		(new DataView(sb.data)).setUint8(SZ.GetSpace(sb, 1), c);
	}

	static function WriteShort(sb:MSG, c:Int):Void {
		(new DataView(sb.data)).setInt16(SZ.GetSpace(sb, 2), c, true);
	}

	static function WriteLong(sb:MSG, c:Int):Void {
		(new DataView(sb.data)).setInt32(SZ.GetSpace(sb, 4), c, true);
	}

	static function WriteFloat(sb:MSG, f:Float):Void {
		(new DataView(sb.data)).setFloat32(SZ.GetSpace(sb, 4), f, true);
	}

	static function WriteString(sb:MSG, s:String):Void {
		if (s != null)
			SZ.Write(sb, new Uint8Array(Q.strmem(s)), s.length);
		WriteChar(sb, 0);
	}

	static function WriteCoord(sb:MSG, f:Float):Void {
		WriteShort(sb, Std.int(f * 8));
	}

	static function WriteAngle(sb:MSG, f:Float):Void {
		WriteByte(sb, Std.int(f * 256 / 360) & 255);
	}

	static function BeginReading():Void {
		readcount = 0;
		badread = false;
	}

	static function ReadChar():Int {
		if (readcount >= NET.message.cursize) {
			badread = true;
			return -1;
		}
		var c = (new Int8Array(NET.message.data, readcount, 1))[0];
		++readcount;
		return c;
	}

	static function ReadByte():Int {
		if (readcount >= NET.message.cursize) {
			badread = true;
			return -1;
		}
		var c = (new Uint8Array(NET.message.data, readcount, 1))[0];
		++readcount;
		return c;
	}

	static function ReadShort():Int {
		if ((readcount + 2) > NET.message.cursize) {
			badread = true;
			return -1;
		}
		var c = (new DataView(NET.message.data)).getInt16(readcount, true);
		readcount += 2;
		return c;
	}

	static function ReadLong():Int {
		if ((readcount + 4) > NET.message.cursize) {
			badread = true;
			return -1;
		}
		var c = (new DataView(NET.message.data)).getInt32(readcount, true);
		readcount += 4;
		return c;
	}

	static function ReadFloat():Float {
		if ((readcount + 4) > NET.message.cursize) {
			badread = true;
			return -1;
		}
		var f = (new DataView(NET.message.data)).getFloat32(readcount, true);
		readcount += 4;
		return f;
	}

	static function ReadString():String {
		var string = [];
		for (l in 0...2048) {
			var c = ReadByte();
			if (c <= 0)
				break;
			string.push(String.fromCharCode(c));
		}
		return string.join('');
	}

	static function ReadCoord():Float {
		return ReadShort() * 0.125;
	}

	static function ReadAngle():Float {
		return ReadChar() * 1.40625;
	}
}
