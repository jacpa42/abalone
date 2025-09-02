const sdl3 = @import("sdl3");
const std = @import("std");

const State = @import("state.zig").State;
const IRect = sdl3.rect.IRect;
const Key = sdl3.keycode.Keycode;

const fps = 60;

pub fn main() !void {
    defer sdl3.shutdown();

    // Initialize SDL with subsystems you need here.
    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    var state = State.new();
    var screen_width: f32 = 1000;
    var screen_height: f32 = 1000;

    // Create a rendering context and window
    const gfx = try sdl3.render.Renderer.initWithWindow(
        "abalone",
        @intFromFloat(screen_width),
        @intFromFloat(screen_height),
        .{
            .always_on_top = true,
            .keyboard_grabbed = true,
            .open_gl = true,
            .resizable = false,
            .borderless = true,
        },
    );

    defer gfx.window.deinit();
    defer gfx.renderer.deinit();

    // Useful for limiting the FPS and getting the delta time.
    var fps_capper = sdl3.extras.FramerateCapper(f32){ .mode = .{ .limited = fps } };

    var quit = false;
    while (!quit) {
        // Delay to limit the FPS, returned delta time not needed.
        const dt = fps_capper.delay();
        _ = dt;

        try state.render(
            screen_height,
            screen_width,
            &gfx.renderer,
        );

        try gfx.renderer.present();

        // Event logic.
        while (sdl3.events.poll()) |event|
            switch (event) {
                .quit => quit = true,
                .terminating => quit = true,
                .key_down => |keyboard| {
                    if (keyboard.key == .escape) quit = true;
                },
                .window_resized => |resize| {
                    screen_width = @floatFromInt(resize.width);
                    screen_height = @floatFromInt(resize.height);
                },
                .mouse_button_down => |mb| {
                    std.debug.print("{any}\n", .{mb});
                },
                else => {},
            };
    }
}
