const zm = @import("zm");
const std = @import("std");

const Interval = @import("math.zig").Interval;
const Ray = @import("rendering.zig").Ray;

pub const AABB = struct {
    x_interval: Interval,
    y_interval: Interval,
    z_interval: Interval,

    pub fn initEmpty() AABB {
        return .{
            .x_interval = Interval{},
            .y_interval = Interval{},
            .z_interval = Interval{},
        };
    }

    pub fn initFromAABBs(bbox0: AABB, bbox1: AABB) AABB {
        return .{
            .x_interval = Interval.join(bbox0.x_interval, bbox1.x_interval),
            .y_interval = Interval.join(bbox0.y_interval, bbox1.y_interval),
            .z_interval = Interval.join(bbox0.z_interval, bbox1.z_interval),
        };
    }

    fn computeIntersection(
        comptime dim: u8,
        ray: Ray,
        interval: Interval,
    ) Interval {
        const dir_div: f64 = 1.0 / ray.dir.data[dim];
        const a: f64 = (interval.min - ray.origin.data[dim]) * dir_div;
        const b: f64 = (interval.max - ray.origin.data[dim]) * dir_div;
        return .{
            .min = @min(a, b),
            .max = @max(b, b),
        };
    }

    pub fn hit(self: AABB, ray: Ray, ray_t: Interval) bool {
        const intervals: [3]Interval = .{
            self.x_interval,
            self.y_interval,
            self.z_interal,
        };
        inline for (0..3) |dim| {
            const t_interval: Interval = AABB.computeIntersection(
                dim,
                ray,
                intervals[dim],
            ).expand(1e-6);
            if (t_interval.min > ray_t.min) {
                ray_t.min = t_interval.min;
            }
            if (t_interval.max < ray_t.max) {
                ray_t.max = t_interval.max;
            }
            if (ray_t.max <= ray_t.min) {
                return false;
            }
        }
        return true;
    }
};
