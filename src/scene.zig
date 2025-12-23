const std = @import("std");
const zm = @import("zm");

const Interval = @import("math.zig").Interval;
const Material = @import("material.zig").Material;
const AABB = @import("aabb.zig").AABB;
const tracing = @import("tracing.zig");

pub const Sphere = struct {
    origin0: zm.Vec3,
    origin1: ?zm.Vec3 = null,
    radius: f64,
    material: Material,
    bbox: AABB,

    pub fn initStatic(
        origin: zm.Vec3,
        radius: f64,
        material: Material,
    ) tracing.Hittable {
        const radius_vec = zm.Vec3.init(radius);
        const neg_rad = origin.sub(radius_vec);
        const pos_rad = origin.add(radius_vec);
        const bbox: AABB = .{
            .x_interval = .{ .min = neg_rad.data[0], .max = pos_rad.data[0] },
            .y_interval = .{ .min = neg_rad.data[1], .max = pos_rad.data[1] },
            .z_interval = .{ .min = neg_rad.data[2], .max = pos_rad.data[2] },
        };
        return tracing.Hittable{ .sphere = Sphere{
            .origin0 = origin,
            .radius = radius,
            .material = material,
            .bbox = bbox,
        } };
    }

    pub fn initDynamic(
        origin0: zm.Vec3,
        origin1: zm.Vec3,
        radius: f64,
        material: Material,
    ) tracing.Hittable {
        const radius_vec = zm.Vec3.init(radius);
        var neg_rad = origin0.sub(radius_vec);
        var pos_rad = origin0.add(radius_vec);
        const bbox0: AABB = .{
            .x_interval = .{ .min = neg_rad.data[0], .max = pos_rad.data[0] },
            .y_interval = .{ .min = neg_rad.data[1], .max = pos_rad.data[1] },
            .z_interval = .{ .min = neg_rad.data[2], .max = pos_rad.data[2] },
        };
        neg_rad = origin1.sub(radius_vec);
        pos_rad = origin1.add(radius_vec);
        const bbox1: AABB = .{
            .x_interval = .{ .min = neg_rad.data[0], .max = pos_rad.data[0] },
            .y_interval = .{ .min = neg_rad.data[1], .max = pos_rad.data[1] },
            .z_interval = .{ .min = neg_rad.data[2], .max = pos_rad.data[2] },
        };
        return tracing.Hittable{ .sphere = Sphere{
            .origin0 = origin0,
            .origin1 = origin1,
            .radius = radius,
            .material = material,
            .bbox = AABB.initFromAABBs(bbox0, bbox1),
        } };
    }

    fn getOrigin(self: Sphere, time: f32) zm.Vec3 {
        if (self.origin1) |origin1| {
            return zm.Vec3.lerp(self.origin0, origin1, time);
        } else {
            return self.origin0;
        }
    }

    pub fn hit(self: Sphere, ray: tracing.Ray, ray_t: Interval) ?tracing.Hit {
        const sphere_center = self.getOrigin(ray.time);
        const oc = sphere_center.sub(ray.origin);
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
        const outward_normal = p.sub(sphere_center).scale(1 / self.radius);
        const is_front_face = ray.dir.dot(outward_normal) <= 0;
        const face_normal = if (is_front_face) outward_normal else outward_normal.scale(-1);
        return .{
            .point = p,
            .normal = face_normal,
            .at = root,
            .is_front_face = is_front_face,
            .material = self.material,
        };
    }

    pub fn normalAt(self: Sphere, p: zm.Vec3, t: f32) zm.Vec3 {
        return p.sub(self.getOrigin(t)).norm();
    }

    pub fn aabb(self: Sphere) AABB {
        return self.bbox;
    }
};
