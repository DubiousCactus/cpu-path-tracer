const std = @import("std");
const zm = @import("zm");

const AABB = @import("aabb.zig").AABB;
const Interval = @import("math.zig").Interval;
const Material = @import("material.zig").Material;
const scene = @import("scene.zig");
const bvh = @import("bvh.zig");

pub const Ray = struct {
    origin: zm.Vec3,
    dir: zm.Vec3,
    time: f32,

    pub fn init(origin: zm.Vec3, dir: zm.Vec3, time: ?f32) Ray {
        return .{
            .origin = origin,
            .dir = dir.norm(),
            .time = time orelse 0,
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
    material: Material,
};

pub const Hittable = union(enum) {
    sphere: scene.Sphere,
    hittable_group: HittableGroup,
    bvh_node: bvh.Node,

    pub fn hit(self: Hittable, ray: Ray, ray_t: Interval) ?Hit {
        switch (self) {
            inline else => |impl| return impl.hit(ray, ray_t),
        }
    }

    pub fn deinit(self: *Hittable, gpa: std.mem.Allocator) void {
        switch (self.*) {
            .bvh_node => |node| node.deinit(gpa),
            // .hittable_group => |group| group.deinit(gpa),
            else => {},
        }
    }

    pub fn aabb(self: Hittable) AABB {
        switch (self) {
            inline else => |impl| return impl.aabb(),
        }
    }
};

pub const HittableGroup = struct {
    objects: std.ArrayList(Hittable) = std.ArrayList(Hittable).empty,
    bbox: AABB = AABB.initEmpty(),

    pub fn init() Hittable {
        return Hittable{ .hittable_group = .{} };
    }

    pub fn addOne(
        self: *HittableGroup,
        object: Hittable,
        gpa: std.mem.Allocator,
    ) !void {
        try self.objects.append(gpa, object);
        self.bbox = AABB.initFromAABBs(self.bbox, object.aabb());
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

    pub fn aabb(self: HittableGroup) AABB {
        return self.bbox;
    }
};
