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
    metallic: Metallic,
    refractive: Dielectric,

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
                in_ray.time,
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
        var scatter_direction = hit.normal.add(math.randomUnitVec3(rng));
        if (math.isVec3NearZero(scatter_direction)) {
            scatter_direction = hit.normal;
        }
        return .{
            .ray = Ray.init(hit.point, scatter_direction, in_ray.time),
            .attenuation = self.albedo,
        };
    }
};

pub const Metallic = struct {
    albedo: zm.Vec3,
    fuzz: f64,

    pub fn init(albedo: zm.Vec3, fuzz: f64) Material {
        return Material{ .metallic = Metallic{
            .albedo = albedo,
            .fuzz = fuzz,
        } };
    }

    pub fn scatter(
        self: Metallic,
        rng: std.Random,
        in_ray: Ray,
        hit: Hit,
    ) ?Scattering {
        var scattered_dir = math.reflect(in_ray.dir, hit.normal);
        if (self.fuzz > 0) {
            scattered_dir = scattered_dir.norm().add(math.randomUnitVec3(rng).scale(self.fuzz));
            if (scattered_dir.dot(hit.normal) <= 0) {
                return null;
            }
        }
        return .{
            .ray = Ray.init(hit.point, scattered_dir, in_ray.time),
            .attenuation = self.albedo,
        };
    }
};

pub const Dielectric = struct {
    index: f64,

    pub fn init(index: f64) Material {
        return Material{ .refractive = Dielectric{ .index = index } };
    }

    pub fn scatter(
        self: Dielectric,
        rng: std.Random,
        in_ray: Ray,
        hit: Hit,
    ) ?Scattering {
        // NOTE: We use the ratio of the material's refractive index over the
        // refractive index of the enclosing meddia as self.index, instead of the
        // material's refractive index itself. Because that's much easier when setting
        // up the scene. But note that we also invert this index here, that's because
        // Snell's law defines the ratio as (eta/eta_prime) where eta is the refractive
        // index of the medium of the incident ray, and eta_prime is the index of the
        // medium of the refracted ray!
        const refractive_index = if (hit.is_front_face) 1.0 / self.index else self.index;
        const cos_theta = @min(in_ray.dir.scale(-1).dot(hit.normal), 1.0);
        const sin_theta = std.math.sqrt(1.0 - cos_theta * cos_theta);
        const cannot_refract = refractive_index * sin_theta > 1.0;
        var bounce_dir: zm.Vec3 = undefined;
        if (cannot_refract or Dielectric.reflectance(cos_theta, refractive_index) > math.randomF64(rng)) {
            bounce_dir = math.reflect(in_ray.dir, hit.normal);
        } else {
            bounce_dir = math.refract(in_ray.dir, hit.normal, refractive_index);
        }
        return .{
            .ray = Ray.init(hit.point, bounce_dir, in_ray.time),
            .attenuation = zm.Vec3{ .data = .{ 1, 1, 1 } },
        };
    }

    fn reflectance(cos_theta: f64, refractive_index: f64) f64 {
        // Shlick's approximation for reflectance
        var r0 = (1.0 - refractive_index) / (1.0 + refractive_index);
        r0 = r0 * r0;
        return r0 + (1.0 - r0) * std.math.pow(f64, 1.0 - cos_theta, 5);
    }
};
