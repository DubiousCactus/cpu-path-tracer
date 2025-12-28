const std = @import("std");
const zm = @import("zm");
const rl = @import("raylib");
const Image = @import("image.zig").Image;

pub const LiveViewer = struct {
    img_buffer: *Image,

    pub fn init(img_buffer: *Image) !LiveViewer {
        rl.initWindow(img_buffer.width, img_buffer.height, "CPU Ray Tracer");
        rl.setTargetFPS(60);
        return .{
            .img_buffer = img_buffer,
        };
    }

    pub fn deinit(_: LiveViewer) void {
        rl.closeWindow();
    }

    pub fn run(self: LiveViewer) !void {
        const img = rl.Image{
            .width = self.img_buffer.width,
            .height = self.img_buffer.height,
            .format = .uncompressed_r32g32b32,
            .data = @as(*anyopaque, @ptrCast(self.img_buffer.buffer)),
            .mipmaps = 1,
        };
        const texture = try rl.Texture2D.fromImage(img);
        defer texture.unload();
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
            // Update
            rl.updateTexture(texture, @as(*anyopaque, @ptrCast(self.img_buffer.buffer)));
            // Draw
            //-----------------------------------------------------------
            rl.beginDrawing();
            rl.clearBackground(.white);
            texture.draw(0, 0, .white);
            rl.endDrawing();
            //-----------------------------------------------------------
        }
    }
};
