const sdl3 = @import("sdl3");
const std = @import("std");
const axial = @import("axial.zig");

const State = @import("state.zig").State;
const IRect = sdl3.rect.IRect;
const Key = sdl3.keycode.Keycode;

pub fn main() error{SdlError}!void {
    var state = State.init() catch {
        if (sdl3.errors.get()) |sdlerr| {
            std.debug.print("Sdl error: {s}\n", .{sdlerr});
        }
        return error.SdlError;
    };
    defer state.deinit();

    while (!state.game_state.quit) {
        const dt = state.fps_capper.delay();
        _ = dt;

        state.process_events();
        state.render() catch {
            if (sdl3.errors.get()) |sdlerr| {
                std.debug.print("Sdl error: {s}\n", .{sdlerr});
            }
            return error.SdlError;
        };
    }
}
