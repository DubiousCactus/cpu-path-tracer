const std = @import("std");
const zm = @import("zm");
const Image = @import("image.zig").Image;
const scene = @import("scene.zig");
const math = @import("math.zig");
const tracing = @import("tracing.zig");
const Ray = tracing.Ray;
const LiveViewer = @import("viewer.zig").LiveViewer;

pub const CameraParams = struct {
    img_width: u16,
    img_height: ?u16 = null,
    img_aspect_ratio: ?f16 = null,
    vfov: f32, // Degrees
    samples_per_pixel: u16 = 10,
    max_bounces: u16 = 10,

    look_from: zm.Vec3 = zm.Vec3{ .data = .{ 0, 0, 0 } },
    look_at: zm.Vec3 = zm.Vec3{ .data = .{ 0, 0, -1 } },
    v_up: zm.Vec3 = zm.Vec3{ .data = .{ 0, 1, 0 } }, // Camera-relative up vector

    focus_dist: f32 = 10, // Distance from camera to focus plane
    defocus_angle: f32 = 0, // Variation angle of rays through each pixel
};

pub const Camera = struct {
    params: CameraParams,
    u: zm.Vec3,
    v: zm.Vec3,
    w: zm.Vec3,

    img_width: u16,
    img_height: u16,

    viewport_width: f64,
    viewport_u: zm.Vec3,
    viewport_v: zm.Vec3,
    viewport_upper_left: zm.Vec3,

    pixel_delta_u: zm.Vec3,
    pixel_delta_v: zm.Vec3,
    pixel00_loc: zm.Vec3,

    defocus_disk_u: zm.Vec3,
    defocus_disk_v: zm.Vec3,

    rng: std.Random.DefaultPrng,

    pub fn init(params: CameraParams) Camera {
        var height: u16 = 0;
        if (params.img_height) |h| {
            height = h;
        } else if (params.img_aspect_ratio) |ratio| {
            height = @max(1, @as(u16, @intFromFloat(
                @as(f32, @floatFromInt(params.img_width)) / ratio,
            )));
        } else {
            unreachable;
        }
        const w = params.look_from.sub(params.look_at).norm();
        const u = params.v_up.crossRH(w).norm();
        const v = w.crossRH(u);
        const vfov_rad = std.math.degreesToRadians(params.vfov);
        const viewport_height = 2.0 * std.math.tan(vfov_rad / 2.0) * params.focus_dist;
        const viewport_width = viewport_height * (@as(
            f64,
            @floatFromInt(params.img_width),
        ) / @as(f64, @floatFromInt(height)));
        const viewport_u = u.scale(viewport_width);
        const viewport_v = v.scale(-viewport_height); // Image plane is inverted!
        const viewport_upper_left = params.look_from.sub(w.scale(params.focus_dist)).sub(
            viewport_u.scale(0.5),
        ).sub(viewport_v.scale(0.5)); // We offset the first pixel by half the inter-pixel distance
        const pix_delta_u = viewport_u.scale(1 / @as(f64, @floatFromInt(params.img_width)));
        const pix_delta_v = viewport_v.scale(1 / @as(f64, @floatFromInt(height)));
        const pixel00_loc = pix_delta_u.add(pix_delta_v).scale(0.5).add(viewport_upper_left);
        const defocus_radius = params.focus_dist * std.math.tan(
            std.math.degreesToRadians(params.defocus_angle / 2.0),
        );
        const defocus_disk_u = u.scale(defocus_radius);
        const defocus_disk_v = v.scale(defocus_radius);
        return .{
            .img_width = params.img_width,
            .img_height = height,
            .params = params,
            .u = u,
            .v = v,
            .w = w,
            .viewport_width = viewport_width,
            .viewport_u = viewport_u,
            .viewport_v = viewport_v,
            .pixel_delta_u = pix_delta_u,
            .pixel_delta_v = pix_delta_v,
            .viewport_upper_left = viewport_upper_left,
            .pixel00_loc = pixel00_loc,
            .rng = std.Random.DefaultPrng.init(
                @as(u64, @bitCast(std.time.milliTimestamp())),
            ),
            .defocus_disk_u = defocus_disk_u,
            .defocus_disk_v = defocus_disk_v,
        };
    }
    fn getRay(self: *Camera, x: u16, y: u16) Ray {
        const random_if = self.rng.random();
        // Sample a random ray origin on the defocus disk
        var ray_origin = self.params.look_from;
        if (self.params.defocus_angle > 0) {
            const disk_sample = math.randomVec3InUnitDisk(random_if);
            ray_origin.addAssign(self.defocus_disk_u.scale(disk_sample.data[0]));
            ray_origin.addAssign(self.defocus_disk_v.scale(disk_sample.data[1]));
        }
        // Pick a random location around the pixel center (x,y)
        const unit_square_sample = zm.Vec3{ .data = .{
            math.randomF64MinMax(random_if, -1, 1),
            math.randomF64MinMax(random_if, -1, 1),
            0,
        } };
        var local_pixel_origin = zm.Vec3{ .data = .{
            @floatFromInt(x),
            @floatFromInt(y),
            0,
        } };
        local_pixel_origin.addAssign(unit_square_sample);

        const pixel_center = self.pixel00_loc.add(
            self.pixel_delta_u.scale(local_pixel_origin.data[0]),
        ).add(self.pixel_delta_v.scale(local_pixel_origin.data[1]));
        const ray_direction = pixel_center.sub(ray_origin);
        const ray_time: f32 = @as(f32, @floatCast(math.randomF64(self.rng.random())));
        return Ray.init(ray_origin, ray_direction, ray_time);
    }

    fn rayColor(
        self: *Camera,
        object: tracing.Hittable,
        ray: Ray,
        bounce: u16,
    ) zm.Vec3 {
        if (bounce > self.params.max_bounces) {
            return zm.Vec3.zero();
        } else if (object.hit(
            ray,
            math.Interval{ .min = 0.001, .max = std.math.inf(f64) },
        )) |hit| {
            if (hit.material.scatter(
                self.rng.random(),
                ray,
                hit,
            )) |scattering| {
                return self.rayColor(
                    object,
                    Ray.init(hit.point, scattering.ray.dir, ray.time),
                    bounce + 1,
                ).mul(scattering.attenuation);
            } else {
                return zm.Vec3.zero();
            }
        } else {
            return zm.Vec3.lerp(
                zm.Vec3{ .data = .{ 1, 1, 1 } },
                zm.Vec3{ .data = .{ 0.5, 0.7, 1 } },
                0.5 * (ray.dir.data[1] + 1.0),
            );
        }
    }

    fn renderPixel(
        self: *Camera,
        image: *Image,
        world: tracing.Hittable,
        x: usize,
        y: usize,
        progress: std.Progress.Node,
    ) void {
        var c = zm.Vec3.zero();
        for (0..self.params.samples_per_pixel) |_| {
            c.addAssign(self.rayColor(
                world,
                self.getRay(
                    @as(u16, @intCast(x)),
                    @as(u16, @intCast(y)),
                ),
                0,
            ));
        }
        image.write(
            @as(u16, @intCast(x)),
            @as(u16, @intCast(y)),
            c.scale(1 / @as(f64, @floatFromInt(self.params.samples_per_pixel))),
        );
        progress.completeOne();
    }

    fn renderSample(
        self: *Camera,
        image: *Image,
        world: tracing.Hittable,
        x: usize,
        y: usize,
        sample_idx: usize,
    ) void {
        const c = self.rayColor(
            world,
            self.getRay(
                @as(u16, @intCast(x)),
                @as(u16, @intCast(y)),
            ),
            0,
        );
        image.accumulate(
            @as(u16, @intCast(x)),
            @as(u16, @intCast(y)),
            c,
            sample_idx,
            self.params.samples_per_pixel,
        );
    }

    pub fn render(
        self: *Camera,
        world: tracing.Hittable,
        image: *Image,
        allocator: std.mem.Allocator,
        viewer: ?LiveViewer,
    ) !void {
        var progress = std.Progress.start(
            .{
                .estimated_total_items = @as(usize, @intCast(self.img_height)) * @as(usize, @intCast(self.img_width)),
                .root_name = "Tracing light paths...",
            },
        );
        var thread_pool: std.Thread.Pool = undefined;
        try thread_pool.init(.{ .n_jobs = 16, .allocator = allocator });
        errdefer thread_pool.deinit();
        for (0..self.img_height) |j| {
            for (0..self.img_width) |i| {
                try thread_pool.spawn(Camera.renderPixel, .{
                    self,
                    image,
                    world,
                    i,
                    j,
                    progress,
                });
            }
        }
        if (viewer) |v| {
            try v.run();
        }
        thread_pool.deinit();
        progress.end();
    }
};
