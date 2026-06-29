const std = @import("std");
const zm = @import("zm");
const rl = @import("raylib");
const Image = @import("image.zig").Image;

pub const LiveViewer = struct {
    img_buffer: *Image,
    texture: rl.Texture2D,

    pub fn init(img_buffer: *Image) !LiveViewer {
        rl.initWindow(img_buffer.width, img_buffer.height, "CPU Ray Tracer");
        rl.setTargetFPS(30);
        const img = rl.Image{
            .width = img_buffer.width,
            .height = img_buffer.height,
            .format = .uncompressed_r32g32b32,
            .data = @as(*anyopaque, @ptrCast(img_buffer.buffer)),
            .mipmaps = 1,
        };
        const texture = try rl.Texture2D.fromImage(img);
        rl.beginDrawing();
        rl.clearBackground(.white);
        texture.draw(0, 0, .white);
        rl.drawText(
            "Launching render threads...",
            img_buffer.width / 2 - 120,
            img_buffer.height / 2,
            20,
            rl.Color.white,
        );
        rl.endDrawing();
        return .{
            .img_buffer = img_buffer,
            .texture = texture,
        };
    }

    pub fn deinit(_: LiveViewer) void {
        rl.closeWindow();
    }

    pub fn run(self: LiveViewer) void {
        defer self.texture.unload();
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
            // Update
            rl.updateTexture(self.texture, @as(*anyopaque, @ptrCast(self.img_buffer.buffer)));
            // Draw
            //-----------------------------------------------------------
            rl.beginDrawing();
            rl.clearBackground(.white);
            self.texture.draw(0, 0, .white);
            rl.endDrawing();
            //-----------------------------------------------------------
        }
    }
};
