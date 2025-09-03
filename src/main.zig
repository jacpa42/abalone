const sdl3 = @import("sdl3");
const std = @import("std");
const axial = @import("axial.zig");

const State = @import("state.zig").State;
const IRect = sdl3.rect.IRect;
const Key = sdl3.keycode.Keycode;

const fps = 60;
pub const logical_size = 100;

pub fn main() !void {
    defer sdl3.shutdown();

    // Initialize SDL with subsystems you need here.
    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    var state = State{ .screen_width = 1000, .screen_height = 1000 };

    var window_flags = sdl3.video.Window.Flags{
        .always_on_top = true,
        .keyboard_grabbed = true,
        .resizable = false,
        .borderless = true,
    };

    switch (@import("builtin").target.os.tag) {
        .macos => window_flags.metal = true,
        .linux => window_flags.open_gl = true,
        else => std.log.err("Get a real operating system.", .{}),
    }

    // Create a rendering context and window
    const gfx = try sdl3.render.Renderer.initWithWindow(
        "abalone",
        @intFromFloat(state.screen_width),
        @intFromFloat(state.screen_height),
        window_flags,
    );
    defer gfx.window.deinit();
    defer gfx.renderer.deinit();

    try gfx.renderer.setLogicalPresentation(logical_size, logical_size, .stretch);

    // Useful for limiting the FPS and getting the delta time.
    var fps_capper = sdl3.extras.FramerateCapper(f32){ .mode = .{ .limited = fps } };

    while (!state.quit) {
        // Delay to limit the FPS, returned delta time not needed.
        const dt = fps_capper.delay();
        _ = dt;

        try state.render(&gfx.renderer);

        try gfx.renderer.present();

        // Event logic.
        while (sdl3.events.poll()) |event|
            switch (event) {
                .quit => state.quit = true,
                .terminating => state.quit = true,
                .key_down => |keyboard| {
                    const key = keyboard.key orelse continue;
                    state.process_keydown(key);
                },
                .window_resized => |resize| {
                    state.screen_width = @floatFromInt(resize.width);
                    state.screen_height = @floatFromInt(resize.height);
                },
                .mouse_button_down => |*mb| {
                    state.process_mousebutton_down(mb);
                },
                .mouse_motion => |*mb| {
                    state.process_mouse_moved(mb.x, mb.y);
                },
                else => {},
            };
    }
}
