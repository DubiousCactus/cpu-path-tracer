const std = @import("std");
const zm = @import("zm");
const image = @import("image.zig");
const camera = @import("camera.zig");
const scene = @import("scene.zig");

pub fn rayColor(object: scene.Hittable, ray: camera.Ray) zm.Vec3 {
    if (object.hit(ray, camera.Interval{ .min = 0, .max = std.math.inf(f64) })) |hit| {
        return hit.normal.add(zm.Vec3{ .data = .{ 1, 1, 1 } }).scale(0.5);
    }
    return zm.Vec3.lerp(
        zm.Vec3{ .data = .{ 1, 1, 1 } },
        zm.Vec3{ .data = .{ 0.5, 0.7, 1 } },
        0.5 * (ray.dir.data[1] + 1.0),
    );
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    const cam = camera.Camera.init(.{
        .img_width = 640,
        .img_aspect_ratio = 16.0 / 9.0,
        .focal_len = 1.0,
        .eye_pos = zm.Vec3{ .data = .{ 0, 0, 0 } },
        .viewport_height = 2.0,
    });
    // const empty_interval = camera.Interval{ .min = std.math.inf, .max = -std.math.inf};
    // const universe_interval = camera.Interval{ .min = -std.math.inf, .max = std.math.inf};

    var img = try image.PPMImage.init("image.ppm", cam.img_width, cam.img_height);
    defer img.close();

    var root_progress = std.Progress.start(
        .{ .estimated_total_items = cam.img_height, .root_name = "Rendering lines..." },
    );

    const sphere = scene.Hittable{
        .sphere = scene.Sphere{ .radius = 0.5, .origin = zm.Vec3{ .data = .{ 0, 0, -1 } } },
    };
    const pseudo_plane = scene.Hittable{
        .sphere = scene.Sphere{ .radius = 100, .origin = zm.Vec3{ .data = .{ 0, -100.5, -1 } } },
    };
    var world = scene.Hittable{ .hittable_group = scene.HittableGroup{} };
    defer world.hittable_group.deinit(allocator);
    try world.hittable_group.addOne(sphere, allocator);
    try world.hittable_group.addOne(pseudo_plane, allocator);

    for (0..cam.img_height) |j| {
        for (0..cam.img_width) |i| {
            const pixel_center = cam.pixel00_loc.add(
                cam.pixel_delta_u.scale(@floatFromInt(i)),
            ).add(cam.pixel_delta_v.scale(@floatFromInt(j)));
            const ray_direction = pixel_center.sub(cam.params.eye_pos);
            const ray = camera.Ray.init(cam.params.eye_pos, ray_direction);
            const c = rayColor(world, ray);
            try img.writePixelBuffered(c);
        }
        try img.flush();
        root_progress.completeOne();
    }
    try img.flush();
}
