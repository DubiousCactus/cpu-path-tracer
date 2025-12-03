const std = @import("std");
const ray_tracer = @import("ray_tracer");
const zm = @import("zm");

pub const PPMImage = struct {
    width: u16,
    height: u16,
    file: std.fs.File,
    file_buffer: [1024]u8 = undefined,
    file_writer: std.fs.File.Writer,
    out: *std.Io.Writer,

    pub fn init(name: []const u8, width: u16, height: u16) !PPMImage {
        var image = PPMImage{
            .width = width,
            .height = height,
            .file = undefined,
            .file_writer = undefined,
            .out = undefined,
        };
        image.file = try std.fs.cwd().createFile(name, .{});
        image.file_writer = std.fs.File.Writer.init(image.file, &image.file_buffer);
        image.out = &image.file_writer.interface;
        // Header of PPM image: P3 for ASCII colours, then widht height, then max color
        // value (255).
        try image.out.print("P3\n{d} {d}\n255\n", .{ width, height });
        return image;
    }

    pub fn close(self: *PPMImage) void {
        self.file.close();
    }

    pub fn writePixelBuffered(self: *PPMImage, pixel: zm.Vec3) !void {
        try self.out.print("{d} {d} {d}\n", .{
            @as(u8, @intFromFloat(255.999 * pixel.data[0])),
            @as(u8, @intFromFloat(255.999 * pixel.data[1])),
            @as(u8, @intFromFloat(255.999 * pixel.data[2])),
        });
    }

    pub fn flush(self: *PPMImage) !void {
        try self.out.flush();
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

pub fn Hits(max_count: comptime_int) type {
    if (max_count < 1) {
        @compileError("Intersections count must be > 1!");
    }

    return struct {
        const Self = @This();

        count: u16,
        where: [max_count]zm.Vec3,
        normals: [max_count]zm.Vec3,

        pub fn whereSlice(self: Self) []zm.Vec3 {
            return self.where[0..self.count];
        }

        pub fn normalSlice(self: Self) []zm.Vec3 {
            return self.normals[0..self.count];
        }
    };
}

pub const Hit = struct {
    point: zm.Vec3,
    normal: zm.Vec3,
    at: f64,
    is_front_face: bool,
};

pub const Hittable = union(enum) {
    sphere: Sphere,
    hittable_group: HittableGroup,

    pub fn hit(self: Hittable, ray: Ray, ray_tmin: f64, ray_tmax: f64) ?Hit {
        switch (self) {
            inline else => |impl| return impl.hit(ray, ray_tmin, ray_tmax),
        }
    }
};

pub const Sphere = struct {
    origin: zm.Vec3,
    radius: f64,

    pub fn hit(self: Sphere, ray: Ray, ray_tmin: f64, ray_tmax: f64) ?Hit {
        const oc = self.origin.sub(ray.origin);
        const a = ray.dir.lenSq();
        const h = ray.dir.dot(oc);
        const c = oc.lenSq() - (self.radius * self.radius);
        const discriminant = h * h - a * c;
        if (discriminant < 0) return null;

        const sqrt_d = @sqrt(discriminant);
        var root = (h - sqrt_d) / a;
        if (root <= ray_tmin or root >= ray_tmax) {
            root = (h + sqrt_d) / a;
            if (root <= ray_tmin or root >= ray_tmax) {
                return null;
            }
        }
        const p = ray.at(root);
        const outward_normal = p.sub(self.origin).scale(1 / self.radius);
        const is_front_face = ray.dir.dot(outward_normal) <= 0;
        return .{
            .point = p,
            .normal = if (is_front_face) outward_normal else outward_normal.scale(-1),
            .at = root,
            .is_front_face = is_front_face,
        };
    }

    pub fn normalAt(self: Sphere, p: zm.Vec3) zm.Vec3 {
        return p.sub(self.origin).norm();
    }
};

pub fn rayColor(object: Hittable, ray: Ray) zm.Vec3 {
    if (object.hit(ray, 0.001, 1000.0)) |hit| {
        return hit.normal.add(zm.Vec3{ .data = .{ 1, 1, 1 } }).scale(0.5);
    }
    return zm.Vec3.lerp(
        zm.Vec3{ .data = .{ 1, 1, 1 } },
        zm.Vec3{ .data = .{ 0.5, 0.7, 1 } },
        0.5 * (ray.dir.data[1] + 1.0),
    );
}

pub const HittableGroup = struct {
    objects: std.ArrayList(Hittable) = std.ArrayList(Hittable).empty,

    pub fn addOne(self: *HittableGroup, object: Hittable, gpa: std.mem.Allocator) !void {
        try self.objects.append(gpa, object);
    }

    pub fn deinit(self: *HittableGroup, gpa: std.mem.Allocator) void {
        self.objects.deinit(gpa);
    }

    pub fn hit(self: HittableGroup, ray: Ray, ray_tmin: f64, ray_tmax: f64) ?Hit {
        var last_hit: ?Hit = null;
        var closest_so_far = ray_tmax;

        for (self.objects.items) |obj| {
            if (obj.hit(ray, ray_tmin, closest_so_far)) |current_hit| {
                last_hit = current_hit;
                closest_so_far = current_hit.at;
            }
        }

        return last_hit;
    }
};

pub fn main() !void { // Image
    const width: u16 = 640;
    const aspect_ratio: f32 = 16.0 / 9.0;
    const height = @max(1, @as(u16, @intFromFloat(@as(f32, @floatFromInt(width)) / aspect_ratio)));

    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    // defer gpa.deinit();

    // Camera
    const viewport_height: f32 = 2.0;
    // The *actual* aspect ratio isn't the desired aspect ratio due to float-int
    // conversions, so we use the actual aspect ratio for the viewport.
    const viewport_width = viewport_height * (@as(f64, @floatFromInt(width)) / @as(f64, @floatFromInt(height)));
    const focal_len: f64 = 1.0;
    const cam_eye: zm.Vec3 = zm.Vec3{ .data = .{ 0, 0, 0 } };
    // const cam_up: zm.Vec3 = zm.Vec3{ .data = .{ 0, 1, 0 } };
    const cam_front: zm.Vec3 = cam_eye.sub(
        zm.Vec3{ .data = .{ 0, 0, focal_len } },
    ); // Remember cam_front is *negative* Z, so it's eye - vec3(0, 0, flen)!
    // const cam_right: zm.Vec3 = cam_front.crossRH(cam_up);
    const viewport_u = zm.Vec3{ .data = .{ viewport_width, 0, 0 } };
    const viewport_v = zm.Vec3{ .data = .{ 0, -viewport_height, 0 } }; // Image plane is inverted!
    const pixel_delta_u: zm.Vec3 = viewport_u.scale(1 / @as(f64, @floatFromInt(width)));
    const pixel_delta_v: zm.Vec3 = viewport_v.scale(1 / @as(f64, @floatFromInt(height)));
    const viewport_upper_left: zm.Vec3 = cam_front.sub(viewport_u.scale(0.5)).sub(viewport_v.scale(0.5));
    // We offset the first pixel by half the inter-pixel distance
    const pixel00_loc: zm.Vec3 = pixel_delta_u.add(pixel_delta_v).scale(0.5).add(viewport_upper_left);

    // File output
    var image = try PPMImage.init("image.ppm", width, height);
    defer image.close();

    // Progress bar
    var root_progress = std.Progress.start(
        .{ .estimated_total_items = height, .root_name = "Rendering lines..." },
    );

    // Rendering!
    const sphere = Hittable{ .sphere = Sphere{ .radius = 0.5, .origin = zm.Vec3{ .data = .{ 0, 0, -1 } } } };
    const pseudo_plane = Hittable{ .sphere = Sphere{ .radius = 100, .origin = zm.Vec3{ .data = .{ 0, -100.5, -1 } } } };
    var scene = Hittable{ .hittable_group = HittableGroup{} };
    defer scene.hittable_group.deinit(allocator);
    try scene.hittable_group.addOne(sphere, allocator);
    try scene.hittable_group.addOne(pseudo_plane, allocator);
    for (0..height) |j| {
        for (0..width) |i| {
            const pixel_center = pixel00_loc.add(pixel_delta_u.scale(@floatFromInt(i))).add(pixel_delta_v.scale(@floatFromInt(j)));
            const ray_direction = pixel_center.sub(cam_eye);
            const ray = Ray.init(cam_eye, ray_direction);
            const c = rayColor(scene, ray);
            try image.writePixelBuffered(c);
        }
        try image.flush();
        root_progress.completeOne();
    }
    try image.flush();
}
