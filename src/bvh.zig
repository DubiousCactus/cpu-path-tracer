const zm = @import("zm");
const std = @import("std");

const math = @import("math.zig");
const Interval = @import("math.zig").Interval;
const Ray = @import("tracing.zig").Ray;
const AABB = @import("aabb.zig").AABB;
const Hit = @import("tracing.zig").Hit;
const Hittable = @import("tracing.zig").Hittable;
const HittableGroup = @import("tracing.zig").HittableGroup;

const SortAxis = struct {
    axis: u8,
};

fn lessThanOnAxis(context: SortAxis, lhs: Hittable, rhs: Hittable) bool {
    const lhs_interval: Interval = lhs.aabb().axisIntervals()[context.axis];
    const rhs_interval: Interval = rhs.aabb().axisIntervals()[context.axis];
    return lhs_interval.min < rhs_interval.min;
}

pub const Node = struct {
    bbox: AABB,
    left: *Hittable,
    right: *Hittable,

    pub fn init(
        hittable_group: HittableGroup,
        rng: std.Random,
        start: usize,
        end: usize,
        allocator: std.mem.Allocator,
    ) !Hittable {
        // INFO: randomly pick an axis, then sort elements along that axis, then split
        // the sorted elements in half, and construct a Node for each half, which will
        // recursively apply the same formula.
        const axis: u8 = math.randomIntMinMax(u8, rng, 0, 3);
        const span = end - start;
        var left: *Hittable = try allocator.create(Hittable);
        var right: *Hittable = try allocator.create(Hittable);

        switch (span) {
            1 => {
                left.* = hittable_group.objects.items[start];
                right.* = left.*;
            },
            2 => {
                left.* = hittable_group.objects.items[start];
                right.* = hittable_group.objects.items[start + 1];
            },
            else => {
                std.mem.sort(
                    Hittable,
                    hittable_group.objects.items[start .. end + 1],
                    SortAxis{ .axis = axis },
                    lessThanOnAxis,
                );
                const mid = start + @divTrunc(span, 2);
                left.* = try Node.init(hittable_group, rng, start, mid, allocator);
                right.* = try Node.init(hittable_group, rng, mid, end, allocator);
            },
        }
        return Hittable{
            .bvh_node = .{
                .bbox = AABB.initFromAABBs(left.aabb(), right.aabb()),
                .left = left,
                .right = right,
            },
        };
    }

    pub fn deinit(self: Node, allocator: std.mem.Allocator) void {
        self.left.deinit(allocator);
        self.right.deinit(allocator);
        allocator.destroy(self.left);
        allocator.destroy(self.right);
    }

    pub fn hit(self: Node, ray: Ray, ray_t: Interval) ?Hit {
        if (self.bbox.hit(ray, ray_t)) {
            var final_hit: ?Hit = null;
            var max_t = ray_t.max;
            if (self.left.hit(ray, ray_t)) |left| {
                max_t = left.at;
                final_hit = left;
            }
            const right_intvl = Interval{
                .min = ray_t.min,
                .max = max_t,
            };
            if (self.right.hit(ray, right_intvl)) |right| {
                final_hit = right;
            }
            return final_hit;
        }
        return null;
    }

    pub fn aabb(self: Node) AABB {
        return self.bbox;
    }
};
