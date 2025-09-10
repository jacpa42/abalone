const sokol = @import("sokol");
const qoi = @import("qoi");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const shd = @import("shaders/shader.glsl.zig");
const std = @import("std");
const axial = @import("axial.zig");

const GameState = @import("state.zig").GameState;

pub fn main() error{ SdlError, StateInitError }!void {
    sokol.app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = input,
        .width = 640,
        .height = 480,
        .alpha = true,
        .icon = .{ .sokol_default = true },
        .window_title = "triangle.zig",
        .logger = .{ .func = sokol.log.func },
    });
}

const state = struct {
    var game_state = GameState{};
    var pass_action: sg.PassAction = .{};
    var bind: sg.Bindings = .{};
    var pip: sg.Pipeline = .{};
    var textures: [4]sg.View = .{sg.View{}} ** 4;
};

const Vertex = extern struct { x: f32, y: f32, color: u32, tex_x: f32, tex_y: f32 };

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    state.pass_action.colors[0] = .{
        .clear_value = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
        .load_action = .CLEAR,
    };

    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]Vertex{
            .{ .x = 1.0, .y = -1.0, .color = 0xffffffff, .tex_x = 0.0, .tex_y = 1.0 }, // bot r
            .{ .x = -1.0, .y = -1.0, .color = 0xffffffff, .tex_x = 1.0, .tex_y = 1.0 }, // bot l
            .{ .x = 1.0, .y = 1.0, .color = 0xffffffff, .tex_x = 0.0, .tex_y = 0.0 }, // top r
            .{ .x = -1.0, .y = 1.0, .color = 0xffffffff, .tex_x = 1.0, .tex_y = 0.0 }, // top l
        }),
    });

    {
        const texture_paths = [_][]const u8{
            "textures/blue_ball.qoi",
            "textures/blue_heart.qoi",
            "textures/red_ball.qoi",
            "textures/red_heart.qoi",
        };

        inline for (texture_paths, &state.textures) |path, *tex| {
            const image_bytes = @embedFile(path);
            const gpa = std.heap.c_allocator;

            var image = qoi.decode(gpa, image_bytes) catch unreachable;
            defer image.deinit(gpa);

            tex.* = sg.makeView(.{
                .texture = .{
                    .image = sg.makeImage(.{
                        .pixel_format = .RGBA8,
                        .height = @intCast(image.height),
                        .width = @intCast(image.width),
                        .data = init: {
                            var data = sg.ImageData{};
                            const pixel_data: []const u32 = @ptrCast(image.pixels);
                            std.debug.assert(image.height * image.width == pixel_data.len);
                            data.subimage[0][0] = sg.asRange(pixel_data);
                            break :init data;
                        },
                    }),
                },
            });
        }
    }

    state.bind.samplers[0] = sg.makeSampler(.{});

    // create a shader and pipeline object
    state.pip = sg.makePipeline(.{
        .shader = sg.makeShader(shd.defaultShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[shd.ATTR_default_pos].format = .FLOAT2;
            l.attrs[shd.ATTR_default_color0].format = .UBYTE4N;
            l.attrs[shd.ATTR_default_texcoord0].format = .FLOAT2;
            break :init l;
        },
        .primitive_type = .TRIANGLE_STRIP,
    });
}

export fn frame() void {
    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });
    sg.applyPipeline(state.pip);
    const i = @rem(@divFloor(sokol.app.frameCount(), 100), 4);
    std.debug.print("{}\n", .{i});
    state.bind.views[shd.VIEW_tex] = state.textures[i];
    sg.applyBindings(state.bind);
    sg.applyUniforms(shd.UB_vs_params, sg.asRange(&shd.VsParams{ .mvp = .identity() }));
    sg.draw(0, 4, 1);
    sg.endPass();
    sg.commit();
}

export fn input(event: ?*const sokol.app.Event) void {
    const ev = event orelse return;
    switch (ev.type) {
        .QUIT_REQUESTED => sapp.quit(),
        .KEY_DOWN => {
            const key = ev.key_code;
            state.game_state.process_keydown(key);
        },
        .MOUSE_DOWN => {
            if (ev.mouse_button != .LEFT) return;
            state.game_state.process_mousebutton_down(ev.mouse_x, ev.mouse_y);
        },
        .MOUSE_MOVE => {
            state.game_state.process_mouse_moved(ev.mouse_x, ev.mouse_y);
        },
        .RESIZED => {
            state.game_state.screen_height = @floatFromInt(ev.window_height);
            state.game_state.screen_width = @floatFromInt(ev.window_width);
        },
        else => return,
    }
}

export fn cleanup() void {
    sg.shutdown();
}
