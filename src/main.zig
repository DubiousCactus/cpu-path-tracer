const std = @import("std");
const zm = @import("zm");
const image = @import("image.zig");
const render = @import("render.zig");
const scene = @import("scene.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    const cam = render.Camera.init(.{
        .img_width = 400,
        .img_aspect_ratio = 16.0 / 9.0,
        .focal_len = 1.0,
        .eye_pos = zm.Vec3{ .data = .{ 0, 0, 0 } },
        .viewport_height = 2.0,
        .samples_per_pixel = 100,
    });
    // const empty_interval = render.Interval{ .min = std.math.inf, .max = -std.math.inf};
    // const universe_interval = render.Interval{ .min = -std.math.inf, .max = std.math.inf};

    var img = try image.PPMImage.init("image.ppm", cam.img_width, cam.img_height, allocator);
    defer img.deinit(allocator);

    var world = scene.Hittable{ .hittable_group = scene.HittableGroup{} };
    defer world.hittable_group.deinit(allocator);
    try world.hittable_group.addOne(scene.Hittable{
        .sphere = scene.Sphere{
            .radius = 0.5,
            .origin = zm.Vec3{ .data = .{ 0, 0, -1 } },
        },
    }, allocator);
    try world.hittable_group.addOne(scene.Hittable{
        .sphere = scene.Sphere{
            .radius = 100,
            .origin = zm.Vec3{ .data = .{ 0, -100.5, -1 } },
        },
    }, allocator);

    try cam.render(world, &img);
}
