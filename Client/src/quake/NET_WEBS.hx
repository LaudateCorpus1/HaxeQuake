package quake;

import js.Browser.document;
import js.Browser.window;
import js.html.ArrayBuffer;
import js.html.BinaryType;
import js.html.Uint8Array;
import quake.NET.NETSocket;

private class WebSocket extends js.html.WebSocket {
	public var data_socket:NETSocket;
}

@:expose("WEBS")
@:publicFields
class NET_WEBS {
	static var available = false;

	static function Init():Bool {
		if ((cast window).WebSocket == null || document.location.protocol == 'https:')
			return false;
		NET_WEBS.available = true;
		return true;
	}

	static function Connect(host:String):Int {
		if (host.length <= 5)
			return null;
		if (host.charCodeAt(5) == 47)
			return null;
		if (host.substring(0, 5) != 'ws://')
			return null;
		host = 'ws://' + host.split('/')[2];
		var sock:NETSocket = (untyped NET).NewQSocket();
		sock.disconnected = true;
		sock.receiveMessage = [];
		sock.address = host;
		try
			sock.driverdata = new WebSocket(host, 'quake')
		catch (e:Dynamic)
			return null;
		sock.driverdata.data_socket = sock;
		sock.driverdata.binaryType = BinaryType.ARRAYBUFFER;
		sock.driverdata.onerror = NET_WEBS.OnError.bind(sock);
		sock.driverdata.onmessage = NET_WEBS.OnMessage.bind(sock);
		(untyped NET).newsocket = sock;
		return 0;
	}

	static function CheckNewConnections() {
	}

	static function GetMessage(sock:NETSocket):Int {
		if (sock.driverdata == null)
			return -1;
		if (sock.driverdata.readyState != 1)
			return -1;
		if (sock.receiveMessage.length == 0)
			return 0;
		var message = sock.receiveMessage.shift();
		(untyped NET).message.cursize = message.length - 1;
		(new Uint8Array((untyped NET).message.data)).set(message.subarray(1));
		return message[0];
	}

	static function SendMessage(sock:NETSocket, data:MSG):Int {
		if (sock.driverdata == null)
			return -1;
		if (sock.driverdata.readyState != 1)
			return -1;
		var buf = new ArrayBuffer(data.cursize + 1), dest = new Uint8Array(buf);
		dest[0] = 1;
		dest.set(new Uint8Array(data.data, 0, data.cursize), 1);
		sock.driverdata.send(buf);
		return 1;
	}

	static function SendUnreliableMessage(sock:NETSocket, data:MSG):Int {
		if (sock.driverdata == null)
			return -1;
		if (sock.driverdata.readyState != 1)
			return -1;
		var buf = new ArrayBuffer(data.cursize + 1), dest = new Uint8Array(buf);
		dest[0] = 2;
		dest.set(new Uint8Array(data.data, 0, data.cursize), 1);
		sock.driverdata.send(buf);
		return 1;
	}

	static function CanSendMessage(sock:NETSocket):Bool {
		if (sock.driverdata == null)
			return false;
		if (sock.driverdata.readyState == 1)
			return true;
		return false;
	}

	static function Close(sock:NETSocket):Void {
		if (sock.driverdata != null)
			sock.driverdata.close(1000);
	}

	static function CheckForResend():Int {
		if ((untyped NET).newsocket.driverdata.readyState == 1)
			return 1;
		if ((untyped NET).newsocket.driverdata.readyState != 0)
			return -1;
		return null;
	}

	static function OnError(sock:NETSocket):Void {
		(untyped NET).Close(sock);
	}

	static function OnMessage(sock:NETSocket, message:MSG):Void {
		var data = message.data;
		if ((data is String))
			return;
		if (data.byteLength > 8000)
			return;
		sock.receiveMessage.push(new Uint8Array(data));
	}
}
