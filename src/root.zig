const std = @import("std");

const rendering = @import("render.zig");
pub const Interval = rendering.Interval;
pub const Camera = rendering.Camera;
pub const CameraParams = rendering.CameraParams;
pub const empty_interval = rendering.Interval{
    .min = std.math.inf,
    .max = -std.math.inf,
};
pub const universe_interval = rendering.Interval{
    .min = -std.math.inf,
    .max = std.math.inf,
};

pub const scene = @import("scene.zig");
pub const PPMImage = @import("image.zig").PPMImage;
