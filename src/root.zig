const std = @import("std");

const rendering = @import("rendering.zig");
pub const Camera = rendering.Camera;
pub const CameraParams = rendering.CameraParams;

const math = @import("math.zig");
pub const Interval = math.Interval;

pub const empty_interval = math.Interval{
    .min = std.math.inf,
    .max = -std.math.inf,
};
pub const universe_interval = math.Interval{
    .min = -std.math.inf,
    .max = std.math.inf,
};

pub const scene = @import("scene.zig");
pub const PPMImage = @import("image.zig").PPMImage;
