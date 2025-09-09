const std = @import("std");
const sokol = @import("sokol");
const qoi = @import("qoi");

const prefix = "src/textures/";
const suffix = ".qoi";

const Allocator = std.mem.Allocator;
const Renderer = sokol.render.Renderer;
const Texture = sokol.render.Texture;

fn create_texture(
    alloc: Allocator,
    renderer: Renderer,
    comptime path: []const u8,
) !Texture {
    const raw = @embedFile(prefix ++ path ++ suffix);
    var image = try qoi.decode(alloc, raw);
    defer image.deinit(alloc);

    var gpu_tex = try Texture.init(
        renderer,
        .array_rgba_32,
        .static,
        image.width,
        image.height,
    );

    try gpu_tex.update(null, @ptrCast(image.pixels), image.width * image.channels);

    return gpu_tex;
}

pub const Textures = struct {
    blue_ball: Texture,
    red_ball: Texture,
    blue_heart: Texture,
    red_heart: Texture,

    /// `alloc` is used to create a buffer to decode the images. All memory used to decode images is freed in this function.
    pub fn init(
        alloc: Allocator,
        renderer: Renderer,
    ) !@This() {
        const blue_ball = try create_texture(alloc, renderer, "blue_ball");
        const blue_heart = try create_texture(alloc, renderer, "blue_heart");
        const red_heart = try create_texture(alloc, renderer, "red_heart");
        const red_ball = try create_texture(alloc, renderer, "red_ball");

        return .{
            .blue_ball = blue_ball,
            .red_ball = red_ball,
            .blue_heart = blue_heart,
            .red_heart = red_heart,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.blue_ball.deinit();
        self.red_ball.deinit();
        self.blue_heart.deinit();
        self.red_heart.deinit();
    }
};
