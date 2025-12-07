const std = @import("std");
const zm = @import("zm");

const Interval = @import("math.zig").Interval;

fn linearToGamma(px: zm.Vec3) zm.Vec3 {
    var gamma_px = zm.Vec3.zero();
    inline for (0..px.data.len) |i| {
        if (px.data[i] > 0) {
            gamma_px.data[i] = std.math.sqrt(px.data[i]);
        }
    }
    return gamma_px;
}

pub const PPMImage = struct {
    width: u16,
    height: u16,
    buffer: []u8,
    writer: std.fs.File.Writer,

    pub fn init(
        name: []const u8,
        width: u16,
        height: u16,
        allocator: std.mem.Allocator,
    ) !PPMImage {
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

    pub fn deinit(self: *PPMImage, allocator: std.mem.Allocator) void {
        self.writer.interface.flush() catch {};
        allocator.free(self.buffer);
        self.writer.file.close();
    }

    pub fn writePixelBuffered(self: *PPMImage, pixel: zm.Vec3) !void {
        const intensity = Interval{ .min = 0.000, .max = 0.999 };
        const gamma_px = linearToGamma(pixel);
        try self.writer.interface.print("{d} {d} {d}\n", .{
            @as(u8, @intFromFloat(256 * intensity.clamp(gamma_px.data[0]))),
            @as(u8, @intFromFloat(256 * intensity.clamp(gamma_px.data[1]))),
            @as(u8, @intFromFloat(256 * intensity.clamp(gamma_px.data[2]))),
        });
    }

    pub fn flush(self: *PPMImage) !void {
        try self.writer.interface.flush();
    }
};

pub const ImageFile = union(enum) {
    ppm: PPMImage,

    pub fn writePixelBuffered(self: *ImageFile, pixel: zm.Vec3) !void {
        switch (self.*) {
            .ppm => |_| try self.ppm.writePixelBuffered(pixel),
        }
    }
    pub fn flush(self: *ImageFile) !void {
        switch (self.*) {
            .ppm => |_| try self.ppm.flush(),
        }
    }

    pub fn deinit(self: *ImageFile, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .ppm => |_| {
                self.ppm.deinit(allocator);
            },
        }
    }
};

pub const Image = struct {
    buffer: []f64,
    width: u16,
    height: u16,
    channels: u16,
    file_name: []const u8,
    image_file: ImageFile,

    pub fn init(
        file_name: []const u8,
        width: u16,
        height: u16,
        channels: u16,
        allocator: std.mem.Allocator,
    ) !Image {
        const buf = try allocator.alloc(f64, @as(u32, @intCast(width)) * @as(u32, @intCast(height)) * @as(u32, @intCast(channels)));
        return .{
            .buffer = buf,
            .width = width,
            .height = height,
            .channels = channels,
            .file_name = file_name,
            .image_file = ImageFile{ .ppm = try PPMImage.init(
                file_name,
                width,
                height,
                allocator,
            ) },
        };
    }

    fn getBufferIndex(self: Image, x: u16, y: u16) usize {
        var i = @as(u32, @intCast(y)) * @as(u32, @intCast(self.width)) * @as(u32, @intCast(self.channels));
        i += @as(u32, @intCast(x)) * @as(u32, @intCast(self.channels));
        return @as(usize, @intCast(i));
    }

    pub fn write(self: *Image, x: u16, y: u16, c: zm.Vec3) void {
        const i: usize = self.getBufferIndex(x, y);
        @memcpy(self.buffer[i .. i + 3], c.data[0..c.data.len]);
    }

    pub fn deinit(self: *Image, allocator: std.mem.Allocator) void {
        self.image_file.deinit(allocator);
        allocator.free(self.buffer);
    }

    pub fn save(self: *Image) !void {
        var x: u16 = undefined;
        var y: u16 = undefined;
        var buf_i: usize = undefined;
        for (0..self.height) |j| {
            for (0..self.width) |i| {
                x = @as(u16, @intCast(i));
                y = @as(u16, @intCast(j));
                buf_i = self.getBufferIndex(x, y);
                try self.image_file.writePixelBuffered(zm.Vec3{ .data = self.buffer[buf_i..][0..3].* });
            }
            try self.image_file.flush();
        }
        try self.image_file.flush();
    }
};
