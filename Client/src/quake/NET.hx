package quake;

import js.html.Uint8Array;

@:publicFields
extern class NETSocket {
    var disconnected:Bool;
    var receiveMessage:Array<Uint8Array>;
    var address:String;
    var driverdata:Dynamic;
}