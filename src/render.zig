const std = @import("std");
const zm = @import("zm");
const img = @import("image.zig");
const scene = @import("scene.zig");

const PPMImage = img.PPMImage;

pub fn rayColor(object: scene.Hittable, ray: Ray) zm.Vec3 {
    if (object.hit(ray, Interval{ .min = 0, .max = std.math.inf(f64) })) |hit| {
        return hit.normal.add(zm.Vec3{ .data = .{ 1, 1, 1 } }).scale(0.5);
    }
    return zm.Vec3.lerp(
        zm.Vec3{ .data = .{ 1, 1, 1 } },
        zm.Vec3{ .data = .{ 0.5, 0.7, 1 } },
        0.5 * (ray.dir.data[1] + 1.0),
    );
}

pub const CameraParams = struct {
    img_width: u16,
    img_height: ?u16 = null,
    img_aspect_ratio: ?f16 = null,
    focal_len: f64 = 1.0,
    eye_pos: zm.Vec3 = zm.Vec3{ .data = .{ 0, 0, 0 } },
    viewport_height: f64 = 2.0,
    samples_per_pixel: u16 = 10,
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

    rng: std.Random,

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
        const viewport_width = params.viewport_height * (@as(
            f64,
            @floatFromInt(params.img_width),
        ) / @as(f64, @floatFromInt(height)));
        const viewport_u = zm.Vec3{ .data = .{ viewport_width, 0, 0 } };
        const viewport_v = zm.Vec3{ .data = .{ 0, -params.viewport_height, 0 } }; // Image plane is inverted!
        const viewport_upper_left = cam_front.sub(
            viewport_u.scale(0.5),
        ).sub(viewport_v.scale(0.5)); // We offset the first pixel by half the inter-pixel distance
        const pix_delta_u = viewport_u.scale(1 / @as(f64, @floatFromInt(params.img_width)));
        const pix_delta_v = viewport_v.scale(1 / @as(f64, @floatFromInt(height)));
        var rng = std.Random.DefaultPrng.init(
            @as(u64, @intCast(@max(0, std.time.timestamp()))),
        );
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
            .rng = rng.random(),
        };
    }

    fn random_f64(self: Camera) f64 {
        return self.rng.float(f64);
    }

    fn random_ab_f64(self: Camera, a: f64, b: f64) f64 {
        return a + (b - a) * self.rng.float(f64);
    }

    fn getRay(self: Camera, x: u16, y: u16) Ray {
        const sample = zm.Vec3{ .data = .{
            self.random_ab_f64(-1, 1),
            self.random_ab_f64(-1, 1),
            0,
        } };
        var local_pixel_origin = zm.Vec3{ .data = .{
            @floatFromInt(x),
            @floatFromInt(y),
            0,
        } };
        local_pixel_origin.addAssign(sample);

        const pixel_center = self.pixel00_loc.add(
            self.pixel_delta_u.scale(local_pixel_origin.data[0]),
        ).add(self.pixel_delta_v.scale(local_pixel_origin.data[1]));
        const ray_direction = pixel_center.sub(self.params.eye_pos);
        return Ray.init(self.params.eye_pos, ray_direction);
    }

    pub fn render(self: Camera, world: scene.Hittable, image: *PPMImage) !void {
        var progress = std.Progress.start(
            .{ .estimated_total_items = self.img_height, .root_name = "Tracing light paths..." },
        );
        for (0..self.img_height) |j| {
            for (0..self.img_width) |i| {
                var c = zm.Vec3.zero();
                for (0..self.params.samples_per_pixel) |_| {
                    c.addAssign(rayColor(world, self.getRay(
                        @as(u16, @intCast(i)),
                        @as(u16, @intCast(j)),
                    )));
                }
                try image.writePixelBuffered(
                    c.scale(1 / @as(f64, @floatFromInt(self.params.samples_per_pixel))),
                );
            }
            try image.flush();
            progress.completeOne();
        }
        try image.flush();
        progress.end();
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

    pub fn clamp(self: Interval, x: f64) f64 {
        return std.math.clamp(x, self.min, self.max);
    }
};
