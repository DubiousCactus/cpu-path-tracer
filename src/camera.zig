const std = @import("std");
const zm = @import("zm");

pub const CameraParams = struct {
    img_width: u16,
    img_height: ?u16 = null,
    img_aspect_ratio: ?f16 = null,
    focal_len: f64,
    eye_pos: zm.Vec3,
    viewport_height: f64,
};

pub const Camera = struct {
    params: CameraParams,
    front_vec: zm.Vec3,

    img_width: u16,
    img_height: u16,

    viewport_width: f64,
    viewport_u: zm.Vec3,
    viewport_v: zm.Vec3,
    viewport_upper_left: zm.Vec3,

    pixel_delta_u: zm.Vec3,
    pixel_delta_v: zm.Vec3,
    pixel00_loc: zm.Vec3,

    pub fn init(params: CameraParams) Camera {
        var height: u16 = 0;
        if (params.img_height) |h| {
            height = h;
        } else if (params.img_aspect_ratio) |ratio| {
            height = @max(1, @as(u16, @intFromFloat(@as(f32, @floatFromInt(params.img_width)) / ratio)));
        } else {
            unreachable;
            // @compileError("Either img_height or img_aspect_ratio must be passed to Camera.init()\n");
        }
        const cam_front = params.eye_pos.sub(
            zm.Vec3{ .data = .{ 0, 0, params.focal_len } },
        ); // Remember cam_front is *negative* Z, so it's eye - vec3(0, 0, flen)!
        const viewport_width = params.viewport_height * (@as(f64, @floatFromInt(params.img_width)) / @as(f64, @floatFromInt(height)));
        const viewport_u = zm.Vec3{ .data = .{ viewport_width, 0, 0 } };
        const viewport_v = zm.Vec3{ .data = .{ 0, -params.viewport_height, 0 } }; // Image plane is inverted!
        const viewport_upper_left = cam_front.sub(
            viewport_u.scale(0.5),
        ).sub(viewport_v.scale(0.5)); // We offset the first pixel by half the inter-pixel distance
        const pix_delta_u = viewport_u.scale(1 / @as(f64, @floatFromInt(params.img_width)));
        const pix_delta_v = viewport_v.scale(1 / @as(f64, @floatFromInt(height)));
        return .{
            .img_width = params.img_width,
            .img_height = height,
            .params = params,
            .front_vec = cam_front,
            .viewport_width = viewport_width,
            .viewport_u = viewport_u,
            .viewport_v = viewport_v,
            .pixel_delta_u = pix_delta_u,
            .pixel_delta_v = pix_delta_v,
            .viewport_upper_left = viewport_upper_left,
            .pixel00_loc = pix_delta_u.add(pix_delta_v).scale(0.5).add(viewport_upper_left),
        };
    }
};

pub const Ray = struct {
    origin: zm.Vec3,
    dir: zm.Vec3,

    pub fn init(origin: zm.Vec3, dir: zm.Vec3) Ray {
        return .{
            .origin = origin,
            .dir = dir.norm(),
        };
    }

    pub fn at(self: Ray, t: f64) zm.Vec3 {
        return self.origin.add(self.dir.scale(t));
    }
};

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
};
