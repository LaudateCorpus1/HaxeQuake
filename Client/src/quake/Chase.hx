package quake;

import quake.Mod.MTrace;


@:publicFields
class Chase {
    static var back:Cvar;
    static var up:Cvar;
    static var right:Cvar;
    static var active:Cvar;

    static function Init():Void {
        back = Cvar.RegisterVariable('chase_back', '100');
        up = Cvar.RegisterVariable('chase_up', '16');
        right = Cvar.RegisterVariable('chase_right', '0');
        active = Cvar.RegisterVariable('chase_active', '0');
    }

    static function Update():Void {
        var forward:Vec = [];
        var r:Vec = [];
        Vec.AngleVectors(CL.state.viewangles, forward, r);
        var trace = new MTrace();
        trace.plane = new Plane();
        var org:Vec = R.refdef.vieworg;
        SV.RecursiveHullCheck(CL.state.worldmodel.hulls[0], 0, 0.0, 1.0, org, [
            org[0] + 4096.0 * forward[0],
            org[1] + 4096.0 * forward[1],
            org[2] + 4096.0 * forward[2]], trace);
        var stop:Vec = trace.endpos;
        stop[2] -= org[2];
        var dist = (stop[0] - org[0]) * forward[0] + (stop[1] - org[1]) * forward[1] + stop[2] * forward[2];
        if (dist < 1.0)
            dist = 1.0;
        R.refdef.viewangles[0] = Math.atan(stop[2] / dist) / Math.PI * -180.0;
        org[0] -= forward[0] * back.value + r[0] * right.value;
        org[1] -= forward[1] * back.value + r[1] * right.value;
        org[2] += up.value;
    }    
}
