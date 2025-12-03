const std = @import("std");
const zm = @import("zm");

pub const PPMImage = struct {
    width: u16,
    height: u16,
    file: std.fs.File,
    file_buffer: [1024]u8 = undefined,
    file_writer: std.fs.File.Writer,
    out: *std.Io.Writer,

    pub fn init(name: []const u8, width: u16, height: u16) !PPMImage {
        var image = PPMImage{
            .width = width,
            .height = height,
            .file = undefined,
            .file_writer = undefined,
            .out = undefined,
        };
        image.file = try std.fs.cwd().createFile(name, .{});
        image.file_writer = std.fs.File.Writer.init(image.file, &image.file_buffer);
        image.out = &image.file_writer.interface;
        // Header of PPM image: P3 for ASCII colours, then widht height, then max color
        // value (255).
        try image.out.print("P3\n{d} {d}\n255\n", .{ width, height });
        return image;
    }

    pub fn close(self: *PPMImage) void {
        self.file.close();
    }

    pub fn writePixelBuffered(self: *PPMImage, pixel: zm.Vec3) !void {
        try self.out.print("{d} {d} {d}\n", .{
            @as(u8, @intFromFloat(255.999 * pixel.data[0])),
            @as(u8, @intFromFloat(255.999 * pixel.data[1])),
            @as(u8, @intFromFloat(255.999 * pixel.data[2])),
        });
    }

    pub fn flush(self: *PPMImage) !void {
        try self.out.flush();
    }
};
