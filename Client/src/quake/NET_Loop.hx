package quake;

import js.html.ArrayBuffer;
import js.html.Uint8Array;
import quake.NET.INETSocket;

private class LoopNETSocket extends quake.NET.NETSocket<LoopNETSocket> {
    var receiveMessage:Uint8Array;
    var receiveMessageLength:Int;
    var canSend:Bool;
}


@:publicFields
class NET_Loop {
	static var localconnectpending = false;
	static var client:LoopNETSocket;
	static var server:LoopNETSocket;
	static var initialized = false;

	static function Init():Bool {
		return true;
	}

	static function Connect(host:String):INETSocket {
		if (host != 'local')
			return null;

		localconnectpending = true;

		if (client == null) {
			client = NET.NewQSocket();
			client.receiveMessage = new Uint8Array(new ArrayBuffer(8192));
			client.address = 'localhost';
		}
		client.receiveMessageLength = 0;
		client.canSend = true;

		if (server == null) {
			server = NET.NewQSocket();
			server.receiveMessage = new Uint8Array(new ArrayBuffer(8192));
			server.address = 'LOCAL';
		}
		server.receiveMessageLength = 0;
		server.canSend = true;

		client.driverdata = server;
		server.driverdata = client;

		return client;
	}

	static function CheckNewConnections():INETSocket {
		if (localconnectpending != true)
			return null;
		localconnectpending = false;
		server.receiveMessageLength = 0;
		server.canSend = true;
		client.receiveMessageLength = 0;
		client.canSend = true;
		return server;
	}

	static function GetMessage(sock:INETSocket):Int {
		var sock:LoopNETSocket = cast sock;
		if (sock.receiveMessageLength == 0)
			return 0;
		var ret = sock.receiveMessage[0];
		var length = sock.receiveMessage[1] + (sock.receiveMessage[2] << 8);
		if (length > NET.message.data.byteLength)
			Sys.Error('GetMessage: overflow');
		NET.message.cursize = length;
		(new Uint8Array(NET.message.data)).set(sock.receiveMessage.subarray(3, length + 3));
		sock.receiveMessageLength -= length;
		if (sock.receiveMessageLength >= 4) {
			for (i in 0...sock.receiveMessageLength)
				sock.receiveMessage[i] = sock.receiveMessage[length + 3 + i];
		}
		sock.receiveMessageLength -= 3;
		if ((sock.driverdata != null) && (ret == 1))
			sock.driverdata.canSend = true;
		return ret;
	}

	static function SendMessage(sock:INETSocket, data:MSG):Int {
		var sock:LoopNETSocket = cast sock;
		if (sock.driverdata == null)
			return -1;
		var bufferLength = sock.driverdata.receiveMessageLength;
		sock.driverdata.receiveMessageLength += data.cursize + 3;
		if (sock.driverdata.receiveMessageLength > 8192)
			Sys.Error('SendMessage: overflow');
		var buffer = sock.driverdata.receiveMessage;
		buffer[bufferLength] = 1;
		buffer[bufferLength + 1] = data.cursize & 0xff;
		buffer[bufferLength + 2] = data.cursize >> 8;
		buffer.set(new Uint8Array(data.data, 0, data.cursize), bufferLength + 3);
		sock.canSend = false;
		return 1;
	}

	static function SendUnreliableMessage(sock:INETSocket, data:MSG):Int {
		var sock:LoopNETSocket = cast sock;
		if (sock.driverdata == null)
			return -1;
		var bufferLength = sock.driverdata.receiveMessageLength;
		sock.driverdata.receiveMessageLength += data.cursize + 3;
		if (sock.driverdata.receiveMessageLength > 8192)
			Sys.Error('SendMessage: overflow');
		var buffer = sock.driverdata.receiveMessage;
		buffer[bufferLength] = 2;
		buffer[bufferLength + 1] = data.cursize & 0xff;
		buffer[bufferLength + 2] = data.cursize >> 8;
		buffer.set(new Uint8Array(data.data, 0, data.cursize), bufferLength + 3);
		return 1;
	}

	static function CanSendMessage(sock:INETSocket):Bool {
		var sock:LoopNETSocket = cast sock;
		if (sock.driverdata != null)
			return sock.canSend;
		return false;
	}

	static function Close(sock:INETSocket):Void {
		var sock:LoopNETSocket = cast sock;
		if (sock.driverdata != null)
			sock.driverdata.driverdata = null;
		sock.receiveMessageLength = 0;
		sock.canSend = false;
		if (sock == client)
			client = null;
		else
			server = null;
	}	

	static function CheckForResend():Int throw "Not implemented";
}
