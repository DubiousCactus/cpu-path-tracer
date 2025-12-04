const std = @import("std");
const zm = @import("zm");
const ray_tracer = @import("ray_tracer");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    const camera = ray_tracer.Camera.init(.{
        .img_width = 400,
        .img_aspect_ratio = 16.0 / 9.0,
        .focal_len = 1.0,
        .eye_pos = zm.Vec3{ .data = .{ 0, 0, 0 } },
        .viewport_height = 2.0,
        .samples_per_pixel = 100,
    });

    var img = try ray_tracer.PPMImage.init(
        "image.ppm",
        camera.img_width,
        camera.img_height,
        allocator,
    );
    defer img.deinit(allocator);

    var world = ray_tracer.scene.Hittable{
        .hittable_group = ray_tracer.scene.HittableGroup{},
    };
    defer world.hittable_group.deinit(allocator);
    try world.hittable_group.addOne(ray_tracer.scene.Hittable{
        .sphere = ray_tracer.scene.Sphere{
            .radius = 0.5,
            .origin = zm.Vec3{ .data = .{ 0, 0, -1 } },
        },
    }, allocator);
    try world.hittable_group.addOne(ray_tracer.scene.Hittable{
        .sphere = ray_tracer.scene.Sphere{
            .radius = 100,
            .origin = zm.Vec3{ .data = .{ 0, -100.5, -1 } },
        },
    }, allocator);

    try camera.render(world, &img);
}
