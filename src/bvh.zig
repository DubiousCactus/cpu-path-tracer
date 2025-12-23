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

pub const BVHBuildStrategy = enum {
    RANDOM_AXIS,
    LONGEST_AXIS,
};

fn lessThanOnAxis(context: SortAxis, lhs: Hittable, rhs: Hittable) bool {
    const lhs_interval: Interval = lhs.aabb().axisIntervals()[context.axis];
    const rhs_interval: Interval = rhs.aabb().axisIntervals()[context.axis];
    return lhs_interval.min < rhs_interval.min;
}

pub const Node = struct {
    bbox: AABB,
    sub_a: *Hittable,
    sub_b: *Hittable,

    pub fn init(
        hittable_group: HittableGroup,
        rng: std.Random,
        start: usize,
        end: usize,
        allocator: std.mem.Allocator,
        strategy: BVHBuildStrategy,
    ) !Hittable {
        var axis: u8 = undefined;
        var bbox: AABB = undefined;
        switch (strategy) {
            .RANDOM_AXIS => {
                // INFO: randomly pick an axis, then sort elements along that axis, then
                // split the sorted elements in half, and construct a Node for each
                // half, which will recursively apply the same formula.
                axis = math.randomIntMinMax(u8, rng, 0, 3);
            },
            .LONGEST_AXIS => {
                // INFO: build the AABB of the entire span of objects, then pick the
                // longest axis, then sort elements along that axis, then split the
                // sorted elements in half, and construct a Node for each half, which
                // will recursively apply the same formula.
                bbox = AABB.initEmpty();
                for (start..end) |i| {
                    bbox = AABB.initFromAABBs(
                        bbox,
                        hittable_group.objects.items[i].aabb(),
                    );
                }
                axis = bbox.longestAxis();
            },
        }
        const span = end - start;
        var sub_a: *Hittable = try allocator.create(Hittable);
        var sub_b: *Hittable = try allocator.create(Hittable);

        switch (span) {
            1 => {
                sub_a.* = hittable_group.objects.items[start];
                sub_b.* = sub_a.*;
            },
            2 => {
                sub_a.* = hittable_group.objects.items[start];
                sub_b.* = hittable_group.objects.items[end - 1];
            },
            else => {
                std.mem.sort(
                    Hittable,
                    hittable_group.objects.items[start..end],
                    SortAxis{ .axis = axis },
                    lessThanOnAxis,
                );
                const mid = start + @divTrunc(span, 2);
                sub_a.* = try Node.init(
                    hittable_group,
                    rng,
                    start,
                    mid,
                    allocator,
                    strategy,
                );
                sub_b.* = try Node.init(
                    hittable_group,
                    rng,
                    mid,
                    end,
                    allocator,
                    strategy,
                );
            },
        }
        if (strategy == .RANDOM_AXIS) {
            bbox = AABB.initFromAABBs(sub_a.aabb(), sub_b.aabb());
        }
        return Hittable{
            .bvh_node = .{
                .bbox = bbox,
                .sub_a = sub_a,
                .sub_b = sub_b,
            },
        };
    }

    pub fn deinit(self: Node, allocator: std.mem.Allocator) void {
        self.sub_a.deinit(allocator);
        self.sub_b.deinit(allocator);
        allocator.destroy(self.sub_a);
        allocator.destroy(self.sub_b);
    }

    pub fn hit(self: Node, ray: Ray, ray_t: Interval) ?Hit {
        if (self.bbox.hit(ray, ray_t)) {
            var final_hit: ?Hit = null;
            var max_t = ray_t.max;
            if (self.sub_a.hit(ray, ray_t)) |left| {
                max_t = left.at;
                final_hit = left;
            }
            const right_intvl = Interval{
                .min = ray_t.min,
                .max = max_t,
            };
            if (self.sub_b.hit(ray, right_intvl)) |right| {
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
