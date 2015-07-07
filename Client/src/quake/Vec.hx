package quake;

typedef Matrix = Array<Array<Float>>;

@:publicFields
class Plane {
    var type:Int;
    var normal:Vec;
    var dist:Float;
    var signbits:Int;
}

@:expose("Vec")
abstract Vec(Array<Float>) from Array<Float> {
    static var origin:Vec = [0.0, 0.0, 0.0];

    @:arrayAccess inline function get(i:Int):Float return this[i];
    @:arrayAccess inline function set(i:Int, v:Float):Float return this[i] = v;

    static function Perpendicular(v:Vec):Vec {
        var pos = 0;
        var minelem = 1.0;
        if (Math.abs(v[0]) < minelem) {
            pos = 0;
            minelem = Math.abs(v[0]);
        }
        if (Math.abs(v[1]) < minelem) {
            pos = 1;
            minelem = Math.abs(v[1]);
        }
        if (Math.abs(v[2]) < minelem) {
            pos = 2;
            minelem = Math.abs(v[2]);
        }
        var tempvec = [0.0, 0.0, 0.0];
        tempvec[pos] = 1.0;
        var inv_denom = 1.0 / (v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
        var d = (tempvec[0] * v[0] + tempvec[1] * v[1] + tempvec[2] * v[2]) * inv_denom;
        var dst = [
            tempvec[0] - d * v[0] * inv_denom,
            tempvec[1] - d * v[1] * inv_denom,
            tempvec[2] - d * v[2] * inv_denom
        ];
        Normalize(dst);
        return dst;
    }

    static function RotatePointAroundVector(dir:Vec, point:Vec, degrees:Float):Vec {
        var r = Perpendicular(dir);
        var up = CrossProduct(r, dir);
        var m = [
            [r[0], up[0], dir[0]],
            [r[1], up[1], dir[1]],
            [r[2], up[2], dir[2]]
        ];
        var im = [
            [m[0][0], m[1][0], m[2][0]],
            [m[0][1], m[1][1], m[2][1]],
            [m[0][2], m[1][2], m[2][2]]
        ];
        var s = Math.sin(degrees * Math.PI / 180.0);
        var c = Math.cos(degrees * Math.PI / 180.0);
        var zrot = [[c, s, 0], [-s, c, 0], [0.0, 0.0, 1.0]];
        var rot = ConcatRotations(ConcatRotations(m, zrot), im);
        return [
            rot[0][0] * point[0] + rot[0][1] * point[1] + rot[0][2] * point[2],
            rot[1][0] * point[0] + rot[1][1] * point[1] + rot[1][2] * point[2],
            rot[2][0] * point[0] + rot[2][1] * point[1] + rot[2][2] * point[2]
        ];
    }

    static function Anglemod(a:Float):Float {
        return (a % 360.0 + 360.0) % 360.0;
    }

    static function BoxOnPlaneSide(emins:Vec, emaxs:Vec, p:Plane) {
        if (p.type <= 2) {
            if (p.dist <= emins[p.type])
                return 1;
            if (p.dist >= emaxs[p.type])
                return 2;
            return 3;
        }
        var dist1, dist2;
        switch (p.signbits) {
            case 0:
                dist1 = p.normal[0] * emaxs[0] + p.normal[1] * emaxs[1] + p.normal[2] * emaxs[2];
                dist2 = p.normal[0] * emins[0] + p.normal[1] * emins[1] + p.normal[2] * emins[2];
            case 1:
                dist1 = p.normal[0] * emins[0] + p.normal[1] * emaxs[1] + p.normal[2] * emaxs[2];
                dist2 = p.normal[0] * emaxs[0] + p.normal[1] * emins[1] + p.normal[2] * emins[2];
            case 2:
                dist1 = p.normal[0] * emaxs[0] + p.normal[1] * emins[1] + p.normal[2] * emaxs[2];
                dist2 = p.normal[0] * emins[0] + p.normal[1] * emaxs[1] + p.normal[2] * emins[2];
            case 3:
                dist1 = p.normal[0] * emins[0] + p.normal[1] * emins[1] + p.normal[2] * emaxs[2];
                dist2 = p.normal[0] * emaxs[0] + p.normal[1] * emaxs[1] + p.normal[2] * emins[2];
            case 4:
                dist1 = p.normal[0] * emaxs[0] + p.normal[1] * emaxs[1] + p.normal[2] * emins[2];
                dist2 = p.normal[0] * emins[0] + p.normal[1] * emins[1] + p.normal[2] * emaxs[2];
            case 5:
                dist1 = p.normal[0] * emins[0] + p.normal[1] * emaxs[1] + p.normal[2] * emins[2];
                dist2 = p.normal[0] * emaxs[0] + p.normal[1] * emins[1] + p.normal[2] * emaxs[2];
            case 6:
                dist1 = p.normal[0] * emaxs[0] + p.normal[1] * emins[1] + p.normal[2] * emins[2];
                dist2 = p.normal[0] * emins[0] + p.normal[1] * emaxs[1] + p.normal[2] * emaxs[2];
            case 7:
                dist1 = p.normal[0] * emins[0] + p.normal[1] * emins[1] + p.normal[2] * emins[2];
                dist2 = p.normal[0] * emaxs[0] + p.normal[1] * emaxs[1] + p.normal[2] * emaxs[2];
            default:
                Sys.Error('Vec.BoxOnPlaneSide: Bad signbits');
        }
        var sides = 0;
        if (dist1 >= p.dist)
            sides = 1;
        if (dist2 < p.dist)
            sides += 2;
        return sides;
    }

    public static function AngleVectors(angles:Vec, ?forward:Vec, ?right:Vec, ?up:Vec):Void {
        var angle;
        
        angle = angles[0] * Math.PI / 180.0;
        var sp = Math.sin(angle);
        var cp = Math.cos(angle);
        angle = angles[1] * Math.PI / 180.0;
        var sy = Math.sin(angle);
        var cy = Math.cos(angle);
        angle = angles[2] * Math.PI / 180.0;
        var sr = Math.sin(angle);
        var cr = Math.cos(angle);

        if (forward != null) {
            forward[0] = cp * cy;
            forward[1] = cp * sy;
            forward[2] = -sp;
        }
        if (right != null) {
            right[0] = cr * sy - sr * sp * cy;
            right[1] = -sr * sp * sy - cr * cy;
            right[2] = -sr * cp;
        }
        if (up != null) {
            up[0] = cr * sp * cy + sr * sy;
            up[1] = cr * sp * sy - sr * cy;
            up[2] = cr * cp;
        }
    }

    static function DotProduct(v1:Vec, v2:Vec):Float {
        return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
    }

    static function Copy(v1:Vec, v2:Vec):Void {
        v2[0] = v1[0];
        v2[1] = v1[1];
        v2[2] = v1[2];
    }

    static function CrossProduct(v1:Vec, v2:Vec):Vec {
        return [
            v1[1] * v2[2] - v1[2] * v2[1],
            v1[2] * v2[0] - v1[0] * v2[2],
            v1[0] * v2[1] - v1[1] * v2[0]
        ];
    }

    static function Length(v:Vec):Float {
        return Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    }

    public static function Normalize(v:Vec):Float {
        var length = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
        if (length == 0.0) {
            v[0] = v[1] = v[2] = 0.0;
            return 0.0;
        }
        v[0] /= length;
        v[1] /= length;
        v[2] /= length;
        return length;
    }

    static function ConcatRotations(m1:Matrix, m2:Matrix):Matrix {
        return [
            [
                m1[0][0] * m2[0][0] + m1[0][1] * m2[1][0] + m1[0][2] * m2[2][0],
                m1[0][0] * m2[0][1] + m1[0][1] * m2[1][1] + m1[0][2] * m2[2][1],
                m1[0][0] * m2[0][2] + m1[0][1] * m2[1][2] + m1[0][2] * m2[2][2]
            ],
            [
                m1[1][0] * m2[0][0] + m1[1][1] * m2[1][0] + m1[1][2] * m2[2][0],
                m1[1][0] * m2[0][1] + m1[1][1] * m2[1][1] + m1[1][2] * m2[2][1],
                m1[1][0] * m2[0][2] + m1[1][1] * m2[1][2] + m1[1][2] * m2[2][2]
            ],
            [
                m1[2][0] * m2[0][0] + m1[2][1] * m2[1][0] + m1[2][2] * m2[2][0],
                m1[2][0] * m2[0][1] + m1[2][1] * m2[1][1] + m1[2][2] * m2[2][1],
                m1[2][0] * m2[0][2] + m1[2][1] * m2[1][2] + m1[2][2] * m2[2][2]
            ]
        ];
    }
}
