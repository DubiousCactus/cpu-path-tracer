const std = @import("std");
const zm = @import("zm");

const render = @import("render.zig");

pub const PPMImage = struct {
    width: u16,
    height: u16,
    buffer: []u8,
    writer: std.fs.File.Writer,

    pub fn init(name: []const u8, width: u16, height: u16, allocator: std.mem.Allocator) !PPMImage {
        const file = try std.fs.cwd().createFile(name, .{});
        const buf = try allocator.alloc(u8, width);
        var image = PPMImage{
            .width = width,
            .height = height,
            .buffer = buf,
            .writer = file.writer(buf),
        };
        // Header of PPM image: P3 for ASCII colours, then widht height, then max color
        // value (255).
        try image.writer.interface.print("P3\n{d} {d}\n255\n", .{ width, height });
        try image.writer.interface.flush();
        return image;
    }

    pub fn writerInterface(self: *PPMImage) *std.Io.Writer {
        return @constCast(&(self.file.writer(&self.buffer).interface));
    }
    pub fn deinit(self: *PPMImage, allocator: std.mem.Allocator) void {
        self.writer.interface.flush() catch {};
        allocator.free(self.buffer);
        self.writer.file.close();
    }

    pub fn writePixelBuffered(self: *PPMImage, pixel: zm.Vec3) !void {
        const intensity = render.Interval{ .min = 0.000, .max = 0.999 };
        try self.writer.interface.print("{d} {d} {d}\n", .{
            @as(u8, @intFromFloat(256 * intensity.clamp(pixel.data[0]))),
            @as(u8, @intFromFloat(256 * intensity.clamp(pixel.data[1]))),
            @as(u8, @intFromFloat(256 * intensity.clamp(pixel.data[2]))),
        });
    }

    pub fn flush(self: *PPMImage) !void {
        try self.writer.interface.flush();
    }
};
