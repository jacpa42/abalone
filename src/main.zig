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
const Move = @import("move.zig").Move;
const compute_best_fit_dir = @import("state.zig").compute_best_fit_dir;
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

    /// The ndc coordinates of the mouse cursor
    var mouse_position = [_]f32{ 0, 0 };

    var screen_width: f32 = inital_window_width;
    var screen_height: f32 = inital_window_height;

    var hexagon_instances = AxialVector.compute_game_grid();

    var model_view_projection_matrix: math.Mat4 = compute_mvp_matrix(
        inital_window_width / inital_window_height,
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

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    // Hide the mouse cursor
    sokol.app.showMouse(false);

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
    const r = AxialVector.radius;
    const hexscale = 0.95;
    const ballscale = 0.8 * hexscale;
    const theta = std.math.pi / 3.0;
    const offset = std.math.pi / 6.0;
    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]Vertex{
            // square
            .{ .x = r * ballscale, .y = r * ballscale, .tex_x = 0.0, .tex_y = 0.0 }, // top r
            .{ .x = r * ballscale, .y = -r * ballscale, .tex_x = 0.0, .tex_y = 1.0 }, // bot r
            .{ .x = -r * ballscale, .y = r * ballscale, .tex_x = 1.0, .tex_y = 0.0 }, // top l
            .{ .x = -r * ballscale, .y = -r * ballscale, .tex_x = 1.0, .tex_y = 1.0 }, // bot l

            // hexagon
            .{ .x = 0, .y = 0 },
            .{
                .x = r * hexscale * @cos(0 * theta + offset),
                .y = r * hexscale * @sin(0 * theta + offset),
            },
            .{
                .x = r * hexscale * @cos(1 * theta + offset),
                .y = r * hexscale * @sin(1 * theta + offset),
            },
            .{
                .x = r * hexscale * @cos(2 * theta + offset),
                .y = r * hexscale * @sin(2 * theta + offset),
            },
            .{
                .x = r * hexscale * @cos(3 * theta + offset),
                .y = r * hexscale * @sin(3 * theta + offset),
            },
            .{
                .x = r * hexscale * @cos(4 * theta + offset),
                .y = r * hexscale * @sin(4 * theta + offset),
            },
            .{
                .x = r * hexscale * @cos(5 * theta + offset),
                .y = r * hexscale * @sin(5 * theta + offset),
            },
        }),
    });

    // Buffer for the instances
    state.bind.vertex_buffers[1] = sg.makeBuffer(.{
        .data = sg.asRange(&state.hexagon_instances),
        .usage = .{ .immutable = true },
    });

    state.bind.index_buffer = sg.makeBuffer(.{
        .data = sg.asRange(&(square_indices ++ hexagon_indices)),
        .usage = .{ .index_buffer = true },
    });

    state.bind.samplers[0] = sg.makeSampler(.{});

    // Create a shader and pipeline object
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

fn draw_hexagon_at(pos: [2]f32) void {
    sg.applyUniforms(shd.UB_vs_params, sg.asRange(&shd.VsParams{
        .mvp = math.Mat4.translate(pos).mul(&state.model_view_projection_matrix),
    }));

    sg.draw(square_indices.len, hexagon_indices.len, 1);
}

// Todo: Do instanced rendering for this. We can have the instance buffer as streaming and then upload the positions for the hexagons, player 1 balls and then player 2 balls in that order.
fn draw_balls(gstate: *const GameState) void {
    var uniforms = shd.VsParams{ .mvp = state.model_view_projection_matrix };

    state.bind.views[shd.VIEW_tex] = state.textures[0];
    sg.applyBindings(state.bind);

    for (gstate.p1.marbles.const_slice()) |marble| {
        uniforms.mvp = math.Mat4.translate(marble.to_pixel_vec())
            .mul(&state.model_view_projection_matrix);
        sg.applyUniforms(shd.UB_vs_params, sg.asRange(&uniforms));

        sg.draw(0, square_indices.len, 1);
    }

    state.bind.views[shd.VIEW_tex] = state.textures[2];
    sg.applyBindings(state.bind);

    for (gstate.p2.marbles.const_slice()) |marble| {
        uniforms.mvp = math.Mat4.translate(marble.to_pixel_vec())
            .mul(&state.model_view_projection_matrix);
        sg.applyUniforms(shd.UB_vs_params, sg.asRange(&uniforms));

        sg.draw(0, square_indices.len, 1);
    }
}

export fn frame() void {
    sg.beginPass(.{
        .action = state.pass_action,
        .swapchain = sglue.swapchain(),
    });

    sg.applyPipeline(state.pip);

    // Set view_port matrix
    var uniforms = shd.VsParams{
        .mvp = state.model_view_projection_matrix,
    };
    sg.applyUniforms(shd.UB_vs_params, sg.asRange(&uniforms));

    // Grid hexagons with texture.
    {
        state.bind.views[shd.VIEW_tex] = state.default_color_tex;
        sg.applyBindings(state.bind);

        sg.draw(square_indices.len, hexagon_indices.len, state.hexagon_instances.len);
    }

    // Draw the hexagon which the user is mousing over
    {
        state.bind.views[shd.VIEW_tex] = state.active_color_tex;
        sg.applyBindings(state.bind);
        draw_hexagon_at(state.game_state.mouse_position.to_pixel_vec());
    }

    // Draw the balls with textures
    {
        switch (state.game_state.turn_state) {
            // If we are choosing a chain, render each selected tile with the active_color_tex
            .ChoosingChain => |*data| {
                state.bind.views[shd.VIEW_tex] = state.active_color_tex;
                sg.applyBindings(state.bind);

                for (data.balls.marbles.const_slice()) |marble| draw_hexagon_at(marble.to_pixel_vec());
                draw_balls(&state.game_state);
            },
            // If we are picking a direction then we simulate the move if any on the copy of the game state
            .ChoosingDirection => |*data| {
                if (data.dir) |mv_dir| {
                    // Simulate the move with a copy of the game state
                    var copy_of_game_state = state.game_state;
                    const player_move = Move.new(data.balls.marbles.const_slice(), mv_dir);
                    copy_of_game_state.do_move(data.turn, player_move) catch |e| {
                        std.log.warn("Failed to simulate move: {}", .{e});
                    };

                    draw_balls(&copy_of_game_state);
                } else {
                    draw_balls(&state.game_state);
                }
            },
        }
    }

    // Draw correct color heart at mouse position
    {
        var scale = math.Mat4.diag(0.5);
        scale.m[3][3] = 1;
        uniforms.mvp = scale.mul(
            &math.Mat4.translate(state.mouse_position),
        ).mul(&state.model_view_projection_matrix);
        sg.applyUniforms(shd.UB_vs_params, sg.asRange(&uniforms));

        const texture_idx: usize = if (state.game_state.turn_state.get_turn() == .p1) 1 else 3;
        state.bind.views[shd.VIEW_tex] = state.textures[texture_idx];
        sg.applyBindings(state.bind);

        sg.draw(0, square_indices.len, 1);
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
            if (ev.mouse_button == .RIGHT) {
                state.game_state.turn_state = state.game_state.turn_state.previous();
            } else {
                state.game_state.process_leftmousebutton_down(state.mouse_position);
            }
        },

        .MOUSE_MOVE => {
            const ndc = compute_ndc_mouse_pos(ev.mouse_x, ev.mouse_y);
            state.game_state.process_mouse_moved(ndc);
        },

        .RESIZED => {
            state.screen_height = @floatFromInt(ev.window_height);
            state.screen_width = @floatFromInt(ev.window_width);
            state.model_view_projection_matrix = compute_mvp_matrix(
                state.screen_width / state.screen_height,
            );
        },
        else => return,
    }
}

export fn cleanup() void {
    sg.shutdown();
}

fn compute_mvp_matrix(aspect_ratio: f32) math.Mat4 {
    const perspective = math.Mat4.persp(90, aspect_ratio, 0.1, 10);
    return math.Mat4.lookat(
        .{ .x = 0, .y = 0, .z = 1 }, // eye
        .{ .x = 0, .y = 0, .z = 0 }, // center
        .{ .x = 0, .y = 1, .z = 0 }, // up
    ).mul(&perspective);
}

/// Expects mouse_x and mouse_y in pixel coordinates
fn compute_ndc_mouse_pos(mouse_x: f32, mouse_y: f32) [2]f32 {
    var mvp_inv: math.Mat4 = state.model_view_projection_matrix.inverse();

    state.mouse_position = mvp_inv.vecmul([_]f32{
        2.0 * (mouse_x / state.screen_width) - 1.0,
        1.0 - 2.0 * (mouse_y / state.screen_height),
    });

    return state.mouse_position;
}
