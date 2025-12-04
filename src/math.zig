const zm = @import("zm");
const std = @import("std");

pub fn randomF64(rng: std.Random) f64 {
    return rng.float(f64);
}

pub fn randomF64MinMax(rng: std.Random, a: f64, b: f64) f64 {
    return a + (b - a) * rng.float(f64);
}

pub fn randomVec3(rng: std.Random) zm.Vec3 {
    return zm.Vec3{ .data = .{
        randomF64(rng),
        randomF64(rng),
        randomF64(rng),
    } };
}
pub fn randomVec3MinMax(rng: std.Random, min: f64, max: f64) zm.Vec3 {
    return zm.Vec3{ .data = .{
        randomF64MinMax(rng, min, max),
        randomF64MinMax(rng, min, max),
        randomF64MinMax(rng, min, max),
    } };
}

pub fn randomUnitVec3(rng: std.Random) zm.Vec3 {
    // IMO, we can just do this to get a vector on the unit sphere:
    // var vec = randomVec3MinMax(rng, -1, 1).norm();
    // But for now I'll follow the reference implementation, because ZM doesn't handle
    // the edge case of very small valued vectors in the norm() computation!
    while (true) {
        const v = randomVec3MinMax(rng, -1, 1);
        const lensq = v.lenSq();
        if (lensq > 1e-160 and lensq <= 1) {
            return v.norm();
        }
    }
}

pub fn randomHemisphereVec3(rng: std.Random, surface_normal: zm.Vec3) zm.Vec3 {
    const v = randomUnitVec3(rng);
    if (v.dot(surface_normal) >= 0) {
        return v;
    } else {
        return v.scale(-1);
    }
}

pub fn isVec3NearZero(v: zm.Vec3) bool {
    const tol = 3 * std.math.floatEps(f64);
    return (std.math.approxEqAbs(f64, v.data[0], 0, tol) and
        std.math.approxEqAbs(f64, v.data[1], 0, tol) and
        std.math.approxEqAbs(f64, v.data[2], 0, tol));
}

pub fn reflect(v: zm.Vec3, normal: zm.Vec3) zm.Vec3 {
    const v_proj_n = -v.dot(normal);
    const b = normal.scale(v_proj_n);
    return v.add(b.scale(2.0));
}

pub fn refract(v: zm.Vec3, normal: zm.Vec3, refractive_ratio: f64) zm.Vec3 {
    const cos_theta = @min(normal.dot(v.scale(-1)), 1.0);
    const v_perp = v.add(normal.scale(cos_theta)).scale(refractive_ratio);
    const v_parall = normal.scale(-std.math.sqrt(1.0 - v_perp.lenSq()));
    return v_perp.add(v_parall);
}

pub fn mulVec3(a: zm.Vec3, b: zm.Vec3) zm.Vec3 {
    return .{ .data = .{
        a.data[0] * b.data[0],
        a.data[1] * b.data[1],
        a.data[2] * b.data[2],
    } };
}

pub const Interval = struct {
    // Default interval is empty, so min=inf, max=-inf
    min: f64 = std.math.inf(f64),
    max: f64 = -std.math.inf(f64),

    pub fn size(self: Interval) f64 {
        return self.max - self.min;
    }

    pub fn contains(self: Interval, x: f64) bool {
        return self.min <= x and self.max >= x;
    }

    pub fn surrounds(self: Interval, x: f64) bool {
        return self.min < x and self.max > x;
    }

    pub fn clamp(self: Interval, x: f64) f64 {
        return std.math.clamp(x, self.min, self.max);
    }
};
