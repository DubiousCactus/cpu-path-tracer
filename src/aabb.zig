const zm = @import("zm");
const std = @import("std");

const Interval = @import("math.zig").Interval;
const Ray = @import("tracing.zig").Ray;

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

    pub fn initFromExtrema(a: zm.Vec3, b: zm.Vec3) AABB {
        return .{
            .x_interval = Interval{
                .min = @min(a.data[0], b.data[0]),
                .max = @max(a.data[0], b.data[0]),
            },
            .y_interval = Interval{
                .min = @min(a.data[1], b.data[1]),
                .max = @max(a.data[1], b.data[1]),
            },
            .z_interval = Interval{
                .min = @min(a.data[2], b.data[2]),
                .max = @max(a.data[2], b.data[2]),
            },
        };
    }

    pub fn initFromAABBs(bbox0: AABB, bbox1: AABB) AABB {
        return .{
            .x_interval = Interval.join(bbox0.x_interval, bbox1.x_interval),
            .y_interval = Interval.join(bbox0.y_interval, bbox1.y_interval),
            .z_interval = Interval.join(bbox0.z_interval, bbox1.z_interval),
        };
    }

    pub fn longestAxis(self: AABB) u8 {
        if (self.x_interval.size() > self.y_interval.size()) {
            return if (self.x_interval.size() > self.z_interval.size()) 0 else 2;
        } else {
            return if (self.y_interval.size() > self.z_interval.size()) 1 else 2;
        }
    }

    pub inline fn axisIntervals(self: AABB) [3]Interval {
        return .{
            self.x_interval,
            self.y_interval,
            self.z_interval,
        };
    }

    inline fn computeIntersection(
        comptime dim: u8,
        ray: Ray,
        interval: Interval,
    ) Interval {
        const dir_div: f64 = 1.0 / ray.dir.data[dim];
        const a: f64 = (interval.min - ray.origin.data[dim]) * dir_div;
        const b: f64 = (interval.max - ray.origin.data[dim]) * dir_div;
        return .{
            .min = @min(a, b),
            .max = @max(a, b),
        };
    }

    pub fn hit(self: AABB, ray: Ray, ray_t: Interval) bool {
        var ray_t_temp = Interval{ .min = ray_t.min, .max = ray_t.max };
        inline for (0..3) |axis| {
            const intersections: Interval = AABB.computeIntersection(
                axis,
                ray,
                self.axisIntervals()[axis],
            ).expand(1e-6);
            if (intersections.min > ray_t_temp.min) {
                ray_t_temp.min = intersections.min;
            }
            if (intersections.max < ray_t_temp.max) {
                ray_t_temp.max = intersections.max;
            }
            if (ray_t_temp.max <= ray_t_temp.min) {
                return false;
            }
        }
        return true;
    }
};
