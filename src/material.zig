const zm = @import("zm");
const std = @import("std");
const math = @import("math.zig");
const Ray = @import("rendering.zig").Ray;
const Hit = @import("scene.zig").Hit;

pub const Scattering = struct {
    ray: Ray,
    attenuation: zm.Vec3,
};

pub const Material = union(enum) {
    diffuse: Diffuse,
    lambertian: Lambertian,
    metal: Metal,

    pub fn scatter(self: Material, rng: std.Random, in_ray: Ray, hit: Hit) ?Scattering {
        switch (self) {
            inline else => |impl| return impl.scatter(rng, in_ray, hit),
        }
    }
};

pub const Diffuse = struct {
    pub fn init() Material {
        return Material{ .diffuse = Diffuse{} };
    }

    pub fn scatter(
        self: Diffuse,
        rng: std.Random,
        in_ray: Ray,
        hit: Hit,
    ) ?Scattering {
        _ = self;
        _ = in_ray;
        // INFO: For basic diffuse material, we can sample uniformly on the hemisphere defined
        // by the surface normal where the ray hit the object:
        // return randomHemisphereVec3(rng, hit.normal);
        // // But for true Lambertian materials, we need to weight the samples by the cosine of the angle between
        // the normal and the random direction. We can approximate this by sampling
        // uniformly from a unit sphere defined at the tip of the normal vector.
        return .{
            .ray = Ray.init(
                hit.point,
                hit.normal.add(math.randomUnitVec3(rng)),
            ),
            .attenuation = zm.Vec3.zero(),
        };
    }
};

pub const Lambertian = struct {
    albedo: zm.Vec3,

    pub fn init(albedo: zm.Vec3) Material {
        return Material{ .lambertian = Lambertian{ .albedo = albedo } };
    }

    pub fn scatter(
        self: Lambertian,
        rng: std.Random,
        in_ray: Ray,
        hit: Hit,
    ) ?Scattering {
        _ = in_ray;
        var scatter_direction = hit.normal.add(math.randomUnitVec3(rng));
        if (math.isVec3NearZero(scatter_direction)) {
            scatter_direction = hit.normal;
        }
        return .{
            .ray = Ray.init(hit.point, scatter_direction),
            .attenuation = self.albedo,
        };
    }
};

pub const Metal = struct {
    albedo: zm.Vec3,

    pub fn init(albedo: zm.Vec3) Material {
        return Material{ .metal = Metal{ .albedo = albedo } };
    }

    pub fn scatter(
        self: Metal,
        rng: std.Random,
        in_ray: Ray,
        hit: Hit,
    ) ?Scattering {
        _ = rng;
        return .{
            .ray = Ray.init(
                hit.point,
                math.reflect(in_ray.dir, hit.normal),
            ),
            .attenuation = self.albedo,
        };
    }
};
