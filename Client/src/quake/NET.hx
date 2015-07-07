package quake;

import js.html.Uint8Array;

@:publicFields
extern class NETSocket<T> {
    var disconnected:Bool;
    var address:String;
    var driverdata:T;
}