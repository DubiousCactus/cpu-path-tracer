const std = @import("std");
const zm = @import("zm");
const ray_tracer = @import("ray_tracer");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    var camera = ray_tracer.Camera.init(.{
        .img_width = 640,
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

    var world = ray_tracer.scene.HittableGroup.init();
    defer world.hittable_group.deinit(allocator);
    // Main Lambertian sphere:
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.init(
        zm.Vec3{ .data = .{ 0, 0, -1 } },
        0.5,
        ray_tracer.material.Lambertian.init(
            zm.Vec3{ .data = .{ 0.1, 0.4, 0.8 } },
        ),
    ), allocator);
    // Glass sphere (made of one outer glass sphere, one inner air sphere)
    const glass_sphere_pos = zm.Vec3{ .data = .{ -0.8, -0.2, -0.75 } };
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.init(
        glass_sphere_pos,
        0.15,
        ray_tracer.material.Dielectric.init(1.5), // Index of glass
    ), allocator);
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.init(
        glass_sphere_pos,
        0.10,
        ray_tracer.material.Dielectric.init(1.0 / 1.5), // Index of air over glass
    ), allocator);
    // Metallic sphere 1:
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.init(
        zm.Vec3{ .data = .{ -1.2, 0, -1.5 } },
        0.5,
        ray_tracer.material.Metallic.init(
            zm.Vec3{ .data = .{ 0.8, 0.8, 0.8 } },
            0,
        ),
    ), allocator);
    // Metallic sphere 2:
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.init(
        zm.Vec3{ .data = .{ 0.9, -0.1, -0.9 } },
        0.3,
        ray_tracer.material.Metallic.init(
            zm.Vec3{ .data = .{ 0.3, 0.9, 0.09 } },
            0.1,
        ),
    ), allocator);
    // Ground:
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.init(
        zm.Vec3{ .data = .{ 0, -100.5, -1 } },
        100,
        ray_tracer.material.Lambertian.init(
            zm.Vec3{ .data = .{ 0.4, 0.2, 0.05 } },
        ),
    ), allocator);

    try camera.render(world, &img);
}
