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
        const file = try std.fs.cwd().createFile(name, .{});
        var file_buffer: [1024]u8 = undefined;
        var file_writer = std.fs.File.Writer.init(file, &file_buffer);
        const out = &file_writer.interface;
        try out.print("P3\n{d} {d}\n255\n", .{ width, height });
        return .{
            .width = width,
            .height = height,
            .file = file,
            .file_writer = file_writer,
            .out = out,
        };
    }

    pub fn close(self: *PPMImage) void {
        self.file.close();
    }

    pub fn write_pixel_buffered(self: *PPMImage, pixel: zm.Vec3) !void {
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

pub fn Intersections(max_count: comptime_int) type {
    if (max_count < 1) {
        @compileError("Intersections count must be > 1!");
    }

    return struct {
        const Self = @This();

        count: u16,
        where: [max_count]zm.Vec3,

        pub fn slice(self: Self) []zm.Vec3 {
            return self.where[0..self.count];
        }
    };
}

pub const Sphere = struct {
    origin: zm.Vec3,
    radius: f64,

    pub fn ray_intersections(self: Sphere, ray: Ray) Intersections(256) {
        const oc = self.origin.sub(ray.origin);
        const a = ray.dir.dot(ray.dir);
        const b = -2.0 * ray.dir.dot(oc);
        const c = oc.dot(oc) - (self.radius * self.radius);
        const discriminant = b * b - 4 * a * c;
        var count: u16 = 0;
        var intersection_pts: [256]zm.Vec3 = undefined;
        if (discriminant > 0) {
            count = 2;
            intersection_pts[0] = ray.at((-b - @sqrt(discriminant)) / (2.0 * a));
            intersection_pts[1] = ray.at((-b + @sqrt(discriminant)) / (2.0 * a));
        } else if (discriminant == 0) {
            count = 1;
            intersection_pts[0] = ray.at((-b) / (2.0 * a));
        }
        return Intersections(256){
            .count = count,
            .where = intersection_pts,
        };
    }

    pub fn normal_at(self: Sphere, p: zm.Vec3) zm.Vec3 {
        return p.sub(self.origin).norm();
    }
};

pub fn write_pixel(writer: *std.io.Writer, pixel: zm.Vec3) !void {
    try writer.print("{d} {d} {d}\n", .{
        @as(u8, @intFromFloat(255.999 * pixel.data[0])),
        @as(u8, @intFromFloat(255.999 * pixel.data[1])),
        @as(u8, @intFromFloat(255.999 * pixel.data[2])),
    });
}

pub fn ray_color(sphere: Sphere, ray: Ray) zm.Vec3 {
    const intersections = sphere.ray_intersections(ray);
    if (intersections.count > 0) {
        return sphere.normal_at(intersections.where[0]).add(zm.Vec3{ .data = .{1,1,1}}).scale(0.5);
    }
    return zm.Vec3.lerp(
        zm.Vec3{ .data = .{ 1, 1, 1 } },
        zm.Vec3{ .data = .{ 0.5, 0.7, 1 } },
        0.5 * (ray.dir.data[1] + 1.0),
    );
}

pub fn main() !void {
    // Image
    const width: u16 = 640;
    const aspect_ratio: f32 = 16.0 / 9.0;
    const height = @max(1, @as(u16, @intFromFloat(@as(f32, @floatFromInt(width)) / aspect_ratio)));

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
    const file = try std.fs.cwd().createFile("image.ppm", .{});
    defer file.close();
    var file_buffer: [1024]u8 = undefined;
    var file_writer = std.fs.File.Writer.init(file, &file_buffer);
    const out = &file_writer.interface;

    // var image = try PPMImage.init("image.ppm", 256, 256);
    // defer image.close();

    // Progress bar
    var root_progress = std.Progress.start(
        .{ .estimated_total_items = height, .root_name = "Rendering lines..." },
    );

    // Header of PPM image: P3 for ASCII colours, then widht height, then max color
    // value (255).
    try out.print("P3\n{d} {d}\n255\n", .{ width, height });

    // Rendering!
    const sphere = Sphere{ .radius = 0.5, .origin = zm.Vec3{ .data = .{ 0, 0, -1 } } };
    for (0..height) |j| {
        for (0..width) |i| {
            // const r_f = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(width - 1));
            // const g_f = @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(height - 1));
            // const b_f = 0;
            const pixel_center = pixel00_loc.add(pixel_delta_u.scale(@floatFromInt(i))).add(pixel_delta_v.scale(@floatFromInt(j)));
            const ray_direction = pixel_center.sub(cam_eye);
            const ray = Ray.init(cam_eye, ray_direction);
            const c = ray_color(sphere, ray);
            try write_pixel(out, c);
        }
        try out.flush();
        root_progress.completeOne();
    }
    try out.flush();
}
