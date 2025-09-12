const sokol = @import("sokol");
const qoi = @import("qoi");
const slog = sokol.log;
const sg = sokol.gfx;
const math = @import("math.zig");
const sapp = sokol.app;
const sglue = sokol.glue;
const shd = @import("shaders/shader.glsl.zig");
const std = @import("std");
const axial = @import("axial.zig");

const GameState = @import("state.zig").GameState;
const AxialVector = axial.AxialVector;

const inital_window_width = 680;
const inital_window_height = 480;

pub fn main() error{ SdlError, StateInitError }!void {
    sokol.app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = input,
        .width = inital_window_width,
        .height = inital_window_height,
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
    var default_color_tex: sg.View = .{};
    var active_color_tex: sg.View = .{};
    var textures: [4]sg.View = .{sg.View{}} ** 4;

    var fov: f32 = 90.0;

    const view_matrix: math.Mat4 = math.Mat4.lookat(
        .{ .x = 0, .y = 0, .z = -1 }, // eye
        .{ .x = 0, .y = 0, .z = 0 }, // center
        .{ .x = 0, .y = -1, .z = 0 }, // up
    );
    var perspective_matrix: math.Mat4 = math.Mat4.persp(
        90.0,
        @as(f32, @floatFromInt(inital_window_width)) / @as(f32, @floatFromInt(inital_window_height)),
        0.1,
        10.0,
    );
};

const Vertex = extern struct {
    x: f32,
    y: f32,
    color: u32 = 0xffffffff,
    tex_x: f32 = 0.0,
    tex_y: f32 = 0.0,
};

const square_indices = [_]u16{
    0, 1, 2,
    1, 2, 3,
};

const hexagon_indices = [_]u16{
    4, 5,  6,
    4, 6,  7,
    4, 7,  8,
    4, 8,  9,
    4, 9,  10,
    4, 10, 5,
};

const hexagon_instances = AxialVector.compute_hexagons();

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    const texture_paths = [_][]const u8{
        "textures/blue_ball.qoi",
        "textures/blue_heart.qoi",
        "textures/red_ball.qoi",
        "textures/red_heart.qoi",
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();

    state.default_color_tex = sg.makeView(.{ .texture = .{
        .image = sg.makeImage(.{
            .pixel_format = .RGBA8,
            .height = 1,
            .width = 1,
            .data = init: {
                var data = sg.ImageData{};
                data.subimage[0][0] = sg.asRange(&[_]u8{ 0xe8, 0x24, 0x24, 0xff });
                break :init data;
            },
        }),
    } });

    state.active_color_tex = sg.makeView(.{ .texture = .{
        .image = sg.makeImage(.{
            .pixel_format = .RGBA8,
            .height = 1,
            .width = 1,
            .data = init: {
                var data = sg.ImageData{};
                data.subimage[0][0] = sg.asRange(&[_]u8{ 0x7a, 0xa7, 0x9f, 0xff });

                break :init data;
            },
        }),
    } });

    inline for (texture_paths, &state.textures) |path, *tex| {
        const image_bytes = @embedFile(path);
        const image = qoi.decode(arena.allocator(), image_bytes) catch unreachable;

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

    state.pass_action.colors[0] = .{
        .clear_value = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
        .load_action = .CLEAR,
    };

    // Square and hexagon verticies in one model
    const theta = std.math.pi / 3.0;
    const offset = std.math.pi / 6.0;
    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]Vertex{
            // square
            .{ .x = 1.0, .y = -1.0, .tex_x = 0.0, .tex_y = 1.0 }, // bot r
            .{ .x = -1.0, .y = -1.0, .tex_x = 1.0, .tex_y = 1.0 }, // bot l
            .{ .x = 1.0, .y = 1.0, .tex_x = 0.0, .tex_y = 0.0 }, // top r
            .{ .x = -1.0, .y = 1.0, .tex_x = 1.0, .tex_y = 0.0 }, // top l

            // hexagon
            .{ .x = 0, .y = 0 },
            .{
                .x = AxialVector.radius * 0.93 * @cos(0 * theta + offset),
                .y = AxialVector.radius * 0.93 * @sin(0 * theta + offset),
            },
            .{
                .x = AxialVector.radius * 0.93 * @cos(1 * theta + offset),
                .y = AxialVector.radius * 0.93 * @sin(1 * theta + offset),
            },
            .{
                .x = AxialVector.radius * 0.93 * @cos(2 * theta + offset),
                .y = AxialVector.radius * 0.93 * @sin(2 * theta + offset),
            },
            .{
                .x = AxialVector.radius * 0.93 * @cos(3 * theta + offset),
                .y = AxialVector.radius * 0.93 * @sin(3 * theta + offset),
            },
            .{
                .x = AxialVector.radius * 0.93 * @cos(4 * theta + offset),
                .y = AxialVector.radius * 0.93 * @sin(4 * theta + offset),
            },
            .{
                .x = AxialVector.radius * 0.93 * @cos(5 * theta + offset),
                .y = AxialVector.radius * 0.93 * @sin(5 * theta + offset),
            },
        }),
    });

    // Buffer for the instances
    state.bind.vertex_buffers[1] = sg.makeBuffer(.{
        .data = sg.asRange(&hexagon_instances),
        .usage = .{ .immutable = true },
    });

    state.bind.index_buffer = sg.makeBuffer(.{
        .data = sg.asRange(&(square_indices ++ hexagon_indices)),
        .usage = .{ .index_buffer = true },
    });

    state.bind.samplers[0] = sg.makeSampler(.{});

    // create a shader and pipeline object
    state.pip = sg.makePipeline(.{
        .shader = sg.makeShader(shd.defaultShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.buffers[1].step_func = .PER_INSTANCE;
            l.attrs[shd.ATTR_default_pos] = .{ .format = .FLOAT2, .buffer_index = 0 };
            l.attrs[shd.ATTR_default_color0] = .{ .format = .UBYTE4N, .buffer_index = 0 };
            l.attrs[shd.ATTR_default_texcoord0] = .{ .format = .FLOAT2, .buffer_index = 0 };
            l.attrs[shd.ATTR_default_inst_pos] = .{ .format = .FLOAT2, .buffer_index = 1 };
            break :init l;
        },
        .colors = init: {
            var colors = [_]sg.ColorTargetState{.{}} ** 4;
            colors[0].blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                .op_rgb = .ADD,
                .src_factor_alpha = .ONE,
                .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
                .op_alpha = .ADD,
            };
            break :init colors;
        },
        .index_type = .UINT16,
    });
}

export fn frame() void {
    sg.beginPass(.{
        .action = state.pass_action,
        .swapchain = sglue.swapchain(),
    });

    sg.applyPipeline(state.pip);

    // Set view_port matrix
    var uniforms = shd.VsParams{ .mvp = state.perspective_matrix.mul(&state.view_matrix) };
    sg.applyUniforms(shd.UB_vs_params, sg.asRange(&uniforms));

    // Set texture
    // state.bind.views[shd.VIEW_tex] = state.textures[0];
    // sg.applyBindings(state.bind);

    // // square with texture
    // sg.draw(0, square_indices.len, 1);

    state.bind.views[shd.VIEW_tex] = state.default_color_tex;
    sg.applyBindings(state.bind);

    // Hexagon with texture
    sg.draw(square_indices.len, hexagon_indices.len, hexagon_instances.len);

    if (state.game_state.mouse_position) |mp| {
        const mp_screen = mp.to_pixel_vec();
        const translate = math.Mat4.translate(.{ .x = mp_screen[0], .y = -mp_screen[1], .z = 0 });

        uniforms.mvp = state.perspective_matrix.mul(&translate).mul(&state.view_matrix);

        state.bind.views[shd.VIEW_tex] = state.active_color_tex;
        sg.applyBindings(state.bind);
        sg.applyUniforms(shd.UB_vs_params, sg.asRange(&uniforms));

        sg.draw(square_indices.len, hexagon_indices.len, 1);
    }

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

            const aspect = state.game_state.screen_width / state.game_state.screen_height;
            state.perspective_matrix = math.Mat4.persp(state.fov, aspect, 0.01, 10.0);
        },
        else => return,
    }
}

export fn cleanup() void {
    sg.shutdown();
}
