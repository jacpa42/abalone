const sokol = @import("sokol");
const std = @import("std");
const axial = @import("axial.zig");

const state = @import("state.zig");

pub fn main() error{ SdlError, StateInitError }!void {
    sokol.app.run(.{
        .init_cb = state.init,
        .frame_cb = state.frame,
        .cleanup_cb = state.cleanup,
        .event_cb = state.input,
        .width = 640,
        .height = 480,
        .icon = .{ .sokol_default = true },
        .window_title = "triangle.zig",
        .logger = .{ .func = sokol.log.func },
    });
}
