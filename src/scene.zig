const std = @import("std");
const zm = @import("zm");
const render = @import("render.zig");

const Ray = render.Ray;
const Interval = render.Interval;

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

    pub fn hit(self: Hittable, ray: Ray, ray_t: Interval) ?Hit {
        switch (self) {
            inline else => |impl| return impl.hit(ray, ray_t),
        }
    }
};

pub const HittableGroup = struct {
    objects: std.ArrayList(Hittable) = std.ArrayList(Hittable).empty,

    pub fn addOne(
        self: *HittableGroup,
        object: Hittable,
        gpa: std.mem.Allocator,
    ) !void {
        try self.objects.append(gpa, object);
    }

    pub fn deinit(self: *HittableGroup, gpa: std.mem.Allocator) void {
        self.objects.deinit(gpa);
    }

    pub fn hit(self: HittableGroup, ray: Ray, ray_t: Interval) ?Hit {
        var last_hit: ?Hit = null;
        var closest_so_far = ray_t.max;

        for (self.objects.items) |obj| {
            if (obj.hit(
                ray,
                Interval{ .min = ray_t.min, .max = closest_so_far },
            )) |current_hit| {
                last_hit = current_hit;
                closest_so_far = current_hit.at;
            }
        }

        return last_hit;
    }
};

pub const Sphere = struct {
    origin: zm.Vec3,
    radius: f64,

    pub fn hit(self: Sphere, ray: Ray, ray_t: Interval) ?Hit {
        const oc = self.origin.sub(ray.origin);
        const a = ray.dir.lenSq();
        const h = ray.dir.dot(oc);
        const c = oc.lenSq() - (self.radius * self.radius);
        const discriminant = h * h - a * c;
        if (discriminant < 0) return null;

        const sqrt_d = @sqrt(discriminant);
        var root = (h - sqrt_d) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + sqrt_d) / a;
            if (!ray_t.surrounds(root)) {
                return null;
            }
        }
        const p = ray.at(root);
        const outward_normal = p.sub(self.origin).scale(1 / self.radius);
        const is_front_face = ray.dir.dot(outward_normal) <= 0;
        const face_normal = if (is_front_face) outward_normal else outward_normal.scale(-1);
        return .{
            .point = p,
            .normal = face_normal,
            .at = root,
            .is_front_face = is_front_face,
        };
    }

    pub fn normalAt(self: Sphere, p: zm.Vec3) zm.Vec3 {
        return p.sub(self.origin).norm();
    }
};
