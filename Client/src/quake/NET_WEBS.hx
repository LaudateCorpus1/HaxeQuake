package quake;

import js.Browser.document;
import js.Browser.window;
import js.html.ArrayBuffer;
import js.html.BinaryType;
import js.html.Uint8Array;
import quake.NET.INETSocket;

@:native("WebSocket")
extern class WebSocket extends js.html.WebSocket {
	public var data_socket:WEBSNETSocket;
}

private class WEBSNETSocket extends quake.NET.NETSocket<WebSocket> {
    var receiveMessage:Array<Uint8Array>;
}


@:publicFields
class NET_WEBS {
	static var available = false;
	static var initialized = false;

	static function Init():Bool {
		if ((cast window).WebSocket == null || document.location.protocol == 'https:')
			return false;
		available = true;
		return true;
	}

	static function Connect(host:String):INETSocket {
		if (host.length <= 5)
			return null;
		if (host.charCodeAt(5) == 47)
			return null;
		if (host.substring(0, 5) != 'ws://')
			return null;
		host = 'ws://' + host.split('/')[2];
		var sock:WEBSNETSocket = NET.NewQSocket();
		sock.disconnected = true;
		sock.receiveMessage = [];
		sock.address = host;
		try
			sock.driverdata = new WebSocket(host, 'quake')
		catch (e:Dynamic)
			return null;
		sock.driverdata.data_socket = sock;
		sock.driverdata.binaryType = BinaryType.ARRAYBUFFER;
		sock.driverdata.onerror = OnError.bind(sock);
		sock.driverdata.onmessage = OnMessage.bind(sock);
		NET.newsocket = sock;
		return cast 0;
	}

	static function CheckNewConnections():INETSocket {
		return null;
	}

	static function GetMessage(sock:INETSocket):Int {
		var sock:WEBSNETSocket = cast sock;
		if (sock.driverdata == null)
			return -1;
		if (sock.driverdata.readyState != 1)
			return -1;
		if (sock.receiveMessage.length == 0)
			return 0;
		var message = sock.receiveMessage.shift();
		NET.message.cursize = message.length - 1;
		(new Uint8Array(NET.message.data)).set(message.subarray(1));
		return message[0];
	}

	static function SendMessage(sock:INETSocket, data:MSG):Int {
		var sock:WEBSNETSocket = cast sock;
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

	static function SendUnreliableMessage(sock:INETSocket, data:MSG):Int {
		var sock:WEBSNETSocket = cast sock;
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

	static function CanSendMessage(sock:INETSocket):Bool {
		var sock:WEBSNETSocket = cast sock;
		if (sock.driverdata == null)
			return false;
		if (sock.driverdata.readyState == 1)
			return true;
		return false;
	}

	static function Close(sock:INETSocket):Void {
		var sock:WEBSNETSocket = cast sock;
		if (sock.driverdata != null)
			sock.driverdata.close(1000);
	}

	static function CheckForResend():Int {
		var sock:WEBSNETSocket = cast NET.newsocket;
		if (sock.driverdata.readyState == 1)
			return 1;
		if (sock.driverdata.readyState != 0)
			return -1;
		return null;
	}

	static function OnError(sock:WEBSNETSocket):Void {
		NET.Close(sock);
	}

	static function OnMessage(sock:WEBSNETSocket, message:MSG):Void {
		var data = message.data;
		if ((data is String))
			return;
		if (data.byteLength > 8000)
			return;
		sock.receiveMessage.push(new Uint8Array(data));
	}
}
