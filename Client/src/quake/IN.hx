package quake;

import js.Browser.document;
import js.html.MouseEvent;

@:expose("IN")
@:publicFields
class IN {

    static var mouse_x = 0.0;
    static var mouse_y = 0.0;
    static var old_mouse_x = 0.0;
    static var old_mouse_y = 0.0;
    static var mouse_avail = false;
    static var m_filter:Cvar;

    static function StartupMouse():Void {
        m_filter = Cvar.RegisterVariable('m_filter', '1');
        if (COM.CheckParm('-nomouse') != null)
            return;
        VID.mainwindow.onclick = onclick;
        document.onmousemove = onmousemove;
        document.onpointerlockchange = onpointerlockchange;
        mouse_avail = true;
    }

    static function Init():Void {
        StartupMouse();
    }

    static function Shutdown():Void {
        if (mouse_avail) {
            VID.mainwindow.onclick = null;
            document.onmousemove = null;
            document.onpointerlockchange = null;
        }
    }

    static function MouseMove():Void {
        if (!mouse_avail)
            return;

        var mouse_x, mouse_y;
        if (m_filter.value != 0)
        {
            mouse_x = (IN.mouse_x + old_mouse_x) * 0.5;
            mouse_y = (IN.mouse_y + old_mouse_y) * 0.5;
        }
        else
        {
            mouse_x = IN.mouse_x;
            mouse_y = IN.mouse_y;
        }
        old_mouse_x = IN.mouse_x;
        old_mouse_y = IN.mouse_y;
        mouse_x *= (untyped CL).sensitivity.value;
        mouse_y *= (untyped CL).sensitivity.value;

        var strafe = (untyped CL).kbuttons[(untyped CL).kbutton.strafe].state & 1;
        var mlook = (untyped CL).kbuttons[(untyped CL).kbutton.mlook].state & 1;
        var angles:Vec = (untyped CL).state.viewangles;

        if ((strafe != 0) || (((untyped CL).lookstrafe.value != 0) && (mlook != 0)))
            (untyped CL).state.cmd.sidemove += (untyped CL).m_side.value * mouse_x;
        else
            angles[1] -= (untyped CL).m_yaw.value * mouse_x;

        if (mlook != 0)
            V.StopPitchDrift();

        if ((mlook != 0) && (strafe == 0))
        {
            angles[0] += (untyped CL).m_pitch.value * mouse_y;
            if (angles[0] > 80.0)
                angles[0] = 80.0;
            else if (angles[0] < -70.0)
                angles[0] = -70.0;
        }
        else
        {
            if ((strafe != 0) && (Host.noclip_anglehack))
                (untyped CL).state.cmd.upmove -= (untyped CL).m_forward.value * mouse_y;
            else
                (untyped CL).state.cmd.forwardmove -= (untyped CL).m_forward.value * mouse_y;
        }

        IN.mouse_x = IN.mouse_y = 0;
    }

    static function Move():Void
    {
        MouseMove();
    }

    static function onclick():Void
    {
        if (document.pointerLockElement != VID.mainwindow)
            VID.mainwindow.requestPointerLock();
    }

    static function onmousemove(e:MouseEvent):Void
    {
        if (document.pointerLockElement != VID.mainwindow)
            return;
        mouse_x += e.movementX;
        mouse_y += e.movementY;
    }

    static function onpointerlockchange():Void
    {
        if (document.pointerLockElement == VID.mainwindow)
            return;
        Key.Event(escape, true);
        Key.Event(escape);
    }
}
