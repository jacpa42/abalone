const sdl3 = @import("sdl3");
const std = @import("std");
const axial = @import("axial.zig");

const State = @import("state.zig").State;
const IRect = sdl3.rect.IRect;
const Key = sdl3.keycode.Keycode;

pub fn main() !void {
    var state = try State.init();
    defer state.deinit();

    while (!state.game_state.quit) {
        const dt = state.fps_capper.delay();
        _ = dt;

        state.process_events();
        try state.render();
    }
}
