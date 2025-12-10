const std = @import("std");
const zm = @import("zm");
const ray_tracer = @import("ray_tracer");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    var camera = ray_tracer.Camera.init(.{
        .img_width = 1920,
        .img_aspect_ratio = 16.0 / 9.0,
        .vfov = 30,
        .look_from = zm.Vec3{ .data = .{ 13, 2, 3 } },
        .look_at = zm.Vec3{ .data = .{ 0, 0, 0 } },
        .samples_per_pixel = 100,
        .max_bounces = 50,
        .defocus_angle = 0.6,
        .focus_dist = 10.0,
    });

    var img = try ray_tracer.Image.init(
        "image.ppm",
        camera.img_width,
        camera.img_height,
        3,
        allocator,
    );
    defer img.deinit(allocator);

    var world = ray_tracer.scene.HittableGroup.init();
    defer world.hittable_group.deinit(allocator);
    // Main Lambertian sphere:
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.initStatic(
        zm.Vec3{ .data = .{ -4, 1, 2.5 } },
        1.0,
        ray_tracer.material.Lambertian.init(
            zm.Vec3{ .data = .{ 0.1, 0.4, 0.8 } },
        ),
    ), allocator);
    // Glass sphere (made of one outer glass sphere, one inner air sphere)
    const glass_sphere_pos = zm.Vec3{ .data = .{ 0, 2, 0 } };
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.initStatic(
        glass_sphere_pos,
        2.0,
        ray_tracer.material.Dielectric.init(1.5), // Index of glass
    ), allocator);
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.initStatic(
        glass_sphere_pos,
        1.7,
        ray_tracer.material.Dielectric.init(1.0 / 1.5), // Index of air over glass
    ), allocator);
    // Metallic sphere 1:
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.initStatic(
        zm.Vec3{ .data = .{ -8, 1.5, -5.5 } },
        1.5,
        ray_tracer.material.Metallic.init(
            zm.Vec3{ .data = .{ 0.8, 0.8, 0.8 } },
            0,
        ),
    ), allocator);
    // Metallic sphere 2:
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.initStatic(
        zm.Vec3{ .data = .{ 0.9, 0.3, -0.3 } },
        0.3,
        ray_tracer.material.Metallic.init(
            zm.Vec3{ .data = .{ 0.3, 0.9, 0.09 } },
            0.1,
        ),
    ), allocator);
    // Ground:
    try world.hittable_group.addOne(ray_tracer.scene.Sphere.initStatic(
        zm.Vec3{ .data = .{ 0, -1000, 0 } },
        1000,
        ray_tracer.material.Lambertian.init(
            zm.Vec3{ .data = .{ 0.5, 0.5, 0.5 } },
        ),
    ), allocator);

    const random_if = camera.rng.random();
    for (0..22) |a| {
        for (0..22) |b| {
            const mat_choice = ray_tracer.math.randomF64(random_if);
            const x = @as(f64, @floatFromInt(@as(i32, @intCast(a)))) - 11;
            const z = @as(f64, @floatFromInt(@as(i32, @intCast(b)))) - 11;
            const radius = ray_tracer.math.randomF64MinMax(random_if, 0.1, 0.35);
            const center = zm.Vec3{ .data = .{
                x + 1.9 * ray_tracer.math.randomF64(random_if),
                radius,
                z + 1.9 * ray_tracer.math.randomF64(random_if),
            } };

            if (center.sub(zm.Vec3{ .data = .{ 0, radius, -1 } }).lenSq() > 1.9) {
                var mat: ray_tracer.material.Material = undefined;
                var albedo: zm.Vec3 = undefined;
                if (mat_choice < 0.8) {
                    // diffuse
                    albedo = ray_tracer.math.randomVec3MinMax(random_if, 0.1, 1);
                    mat = ray_tracer.material.Lambertian.init(albedo);
                    try world.hittable_group.addOne(
                        ray_tracer.scene.Sphere.initDynamic(
                            center,
                            center.add(zm.Vec3{ .data = .{
                                0,
                                ray_tracer.math.randomF64MinMax(random_if, 0.0, 0.5),
                                0,
                            } }),
                            radius,
                            mat,
                        ),
                        allocator,
                    );
                } else if (mat_choice < 0.95) {
                    // metal
                    albedo = ray_tracer.math.randomVec3MinMax(random_if, 0.5, 1);
                    const fuzz = ray_tracer.math.randomF64MinMax(random_if, 0, 0.5);
                    mat = ray_tracer.material.Metallic.init(albedo, fuzz);
                    try world.hittable_group.addOne(
                        ray_tracer.scene.Sphere.initStatic(center, radius, mat),
                        allocator,
                    );
                } else {
                    // glass
                    mat = ray_tracer.material.Dielectric.init(1.5);
                    try world.hittable_group.addOne(
                        ray_tracer.scene.Sphere.initStatic(center, radius, mat),
                        allocator,
                    );
                }
            }
        }
    }

    try camera.render(world, &img, allocator);
    std.debug.print("Saving image as {s}...\n", .{img.file_name});
    try img.save();
    std.debug.print("Done!\n", .{});
}
