const std = @import("std");
const geometry = @import("state/geometry.zig");
const move = @import("move.zig");
const pt_array = @import("point_array.zig");
const turn_state = @import("state/turn.zig");
const texture = @import("textures.zig");

const Textures = texture.Textures;
const SelectedBalls = @import("state/selected_balls.zig").SelectedBalls;
const AxialVector = @import("axial.zig").AxialVector;
const Direction = move.HexagonalDirection;
const Marbles = pt_array.PointArray(14);
const TurnState = turn_state.TurnState;
const Turn = turn_state.Turn;

const compute_best_fit_dir = turn_state.compute_best_fit_dir;

const theme = geometry.color.catppuccin_macchiato;
const fps = 60;
const logical_size = 100;
const inital_screen_width = 1000;
const inital_screen_height = 1000;
const screen_factor = logical_size * 0.5;

//------------------------------------------------------------------------------
//  shapes.zig
//
//  Simple sokol.shape demo.
//------------------------------------------------------------------------------
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const sdtx = sokol.debugtext;
const sshape = sokol.shape;
const assert = @import("std").debug.assert;
const math = std.math;
const shd = @import("shaders/shapes.glsl.zig");

pub const Mat4 = extern struct {
    m: [4][4]f32,

    pub fn identity() Mat4 {
        return Mat4{
            .m = [_][4]f32{
                .{ 1.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 1.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 1.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    pub fn zero() Mat4 {
        return Mat4{
            .m = [_][4]f32{
                .{ 0.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 0.0 },
            },
        };
    }

    pub fn mul(left: Mat4, right: Mat4) Mat4 {
        var res = Mat4.zero();
        for (0..4) |col| {
            for (0..4) |row| {
                res.m[col][row] = left.m[0][row] * right.m[col][0] +
                    left.m[1][row] * right.m[col][1] +
                    left.m[2][row] * right.m[col][2] +
                    left.m[3][row] * right.m[col][3];
            }
        }
        return res;
    }

    pub fn persp(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
        var res = Mat4.identity();
        const t = math.tan(fov * (math.pi / 360.0));
        res.m[0][0] = 1.0 / t;
        res.m[1][1] = aspect / t;
        res.m[2][3] = -1.0;
        res.m[2][2] = (near + far) / (near - far);
        res.m[3][2] = (2.0 * near * far) / (near - far);
        res.m[3][3] = 0.0;
        return res;
    }

    pub fn lookat(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        var res = Mat4.zero();

        const f = Vec3.norm(Vec3.sub(center, eye));
        const s = Vec3.norm(Vec3.cross(f, up));
        const u = Vec3.cross(s, f);

        res.m[0][0] = s.x;
        res.m[0][1] = u.x;
        res.m[0][2] = -f.x;

        res.m[1][0] = s.y;
        res.m[1][1] = u.y;
        res.m[1][2] = -f.y;

        res.m[2][0] = s.z;
        res.m[2][1] = u.z;
        res.m[2][2] = -f.z;

        res.m[3][0] = -Vec3.dot(s, eye);
        res.m[3][1] = -Vec3.dot(u, eye);
        res.m[3][2] = Vec3.dot(f, eye);
        res.m[3][3] = 1.0;

        return res;
    }

    pub fn rotate(angle: f32, axis_unorm: Vec3) Mat4 {
        var res = Mat4.identity();

        const axis = Vec3.norm(axis_unorm);
        const sin_theta = math.sin(math.degreesToRadians(angle));
        const cos_theta = math.cos(math.degreesToRadians(angle));
        const cos_value = 1.0 - cos_theta;

        res.m[0][0] = (axis.x * axis.x * cos_value) + cos_theta;
        res.m[0][1] = (axis.x * axis.y * cos_value) + (axis.z * sin_theta);
        res.m[0][2] = (axis.x * axis.z * cos_value) - (axis.y * sin_theta);
        res.m[1][0] = (axis.y * axis.x * cos_value) - (axis.z * sin_theta);
        res.m[1][1] = (axis.y * axis.y * cos_value) + cos_theta;
        res.m[1][2] = (axis.y * axis.z * cos_value) + (axis.x * sin_theta);
        res.m[2][0] = (axis.z * axis.x * cos_value) + (axis.y * sin_theta);
        res.m[2][1] = (axis.z * axis.y * cos_value) - (axis.x * sin_theta);
        res.m[2][2] = (axis.z * axis.z * cos_value) + cos_theta;

        return res;
    }

    pub fn translate(translation: Vec3) Mat4 {
        var res = Mat4.identity();
        res.m[3][0] = translation.x;
        res.m[3][1] = translation.y;
        res.m[3][2] = translation.z;
        return res;
    }
};

pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn zero() Vec3 {
        return Vec3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn up() Vec3 {
        return Vec3{ .x = 0.0, .y = 1.0, .z = 0.0 };
    }

    pub fn len(v: Vec3) f32 {
        return math.sqrt(Vec3.dot(v, v));
    }

    pub fn add(left: Vec3, right: Vec3) Vec3 {
        return Vec3{ .x = left.x + right.x, .y = left.y + right.y, .z = left.z + right.z };
    }

    pub fn sub(left: Vec3, right: Vec3) Vec3 {
        return Vec3{ .x = left.x - right.x, .y = left.y - right.y, .z = left.z - right.z };
    }

    pub fn mul(v: Vec3, s: f32) Vec3 {
        return Vec3{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn norm(v: Vec3) Vec3 {
        const l = Vec3.len(v);
        if (l != 0.0) {
            return Vec3{ .x = v.x / l, .y = v.y / l, .z = v.z / l };
        } else {
            return Vec3.zero();
        }
    }

    pub fn cross(v0: Vec3, v1: Vec3) Vec3 {
        return Vec3{ .x = (v0.y * v1.z) - (v0.z * v1.y), .y = (v0.z * v1.x) - (v0.x * v1.z), .z = (v0.x * v1.y) - (v0.y * v1.x) };
    }

    pub fn dot(v0: Vec3, v1: Vec3) f32 {
        return v0.x * v1.x + v0.y * v1.y + v0.z * v1.z;
    }
};

const Shape = struct {
    pos: Vec3 = Vec3.zero(),
    draw: sshape.ElementRange = .{},
};

const NUM_SHAPES = 5;

const state = struct {
    var pass_action: sg.PassAction = .{};
    var pip: sg.Pipeline = .{};
    var bind: sg.Bindings = .{};
    var vs_params: shd.VsParams = undefined;
    var shapes: [NUM_SHAPES]Shape = .{
        .{ .pos = .{ .x = -1, .y = 1, .z = 0 } },
        .{ .pos = .{ .x = 1, .y = 1, .z = 0 } },
        .{ .pos = .{ .x = -2, .y = -1, .z = 0 } },
        .{ .pos = .{ .x = 2, .y = -1, .z = 0 } },
        .{ .pos = .{ .x = 0, .y = -1, .z = 0 } },
    };
    var rx: f32 = 0.0;
    var ry: f32 = 0.0;
    const view = Mat4.lookat(.{ .x = 0.0, .y = 1.5, .z = 6.0 }, Vec3.zero(), Vec3.up());
};

pub export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    var sdtx_desc: sdtx.Desc = .{
        .logger = .{ .func = slog.func },
    };

    sdtx_desc.fonts[0] = sdtx.fontKc853();
    sdtx.setup(sdtx_desc);

    // pass-action for clearing to black
    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };

    // shader- and pipeline-object
    state.pip = sg.makePipeline(.{
        .shader = sg.makeShader(shd.shapesShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.buffers[0] = sshape.vertexBufferLayoutState();
            l.attrs[shd.ATTR_shapes_position] = sshape.positionVertexAttrState();
            l.attrs[shd.ATTR_shapes_normal] = sshape.normalVertexAttrState();
            l.attrs[shd.ATTR_shapes_texcoord] = sshape.texcoordVertexAttrState();
            l.attrs[shd.ATTR_shapes_color0] = sshape.colorVertexAttrState();
            break :init l;
        },
        .index_type = .UINT16,
        .cull_mode = .NONE,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        },
    });

    // generate shape geometries
    var vertices: [6 * 1024]sshape.Vertex = undefined;
    var indices: [16 * 1024]u16 = undefined;
    var buf: sshape.Buffer = .{
        .vertices = .{ .buffer = sshape.asRange(&vertices) },
        .indices = .{ .buffer = sshape.asRange(&indices) },
    };
    buf = sshape.buildBox(buf, .{
        .width = 1.0,
        .height = 1.0,
        .depth = 1.0,
        .tiles = 10,
        .random_colors = true,
    });
    state.shapes[0].draw = sshape.elementRange(buf);
    buf = sshape.buildPlane(buf, .{
        .width = 1.0,
        .depth = 1.0,
        .tiles = 10,
        .random_colors = true,
    });
    state.shapes[1].draw = sshape.elementRange(buf);
    buf = sshape.buildSphere(buf, .{
        .radius = 0.75,
        .slices = 36,
        .stacks = 20,
        .random_colors = true,
    });
    state.shapes[2].draw = sshape.elementRange(buf);
    buf = sshape.buildCylinder(buf, .{
        .radius = 0.5,
        .height = 1.5,
        .slices = 36,
        .stacks = 10,
        .random_colors = true,
    });
    state.shapes[3].draw = sshape.elementRange(buf);
    buf = sshape.buildTorus(buf, .{
        .radius = 0.5,
        .ring_radius = 0.3,
        .rings = 36,
        .sides = 18,
        .random_colors = true,
    });
    state.shapes[4].draw = sshape.elementRange(buf);
    assert(buf.valid);

    // one vertex- and index-buffer for all shapes
    state.bind.vertex_buffers[0] = sg.makeBuffer(sshape.vertexBufferDesc(buf));
    state.bind.index_buffer = sg.makeBuffer(sshape.indexBufferDesc(buf));
}

pub export fn frame() void {
    // help text
    sdtx.canvas(sapp.widthf() * 0.5, sapp.heightf() * 0.5);
    sdtx.pos(0.5, 0.5);
    sdtx.puts("press key to switch draw mode:\n\n");
    sdtx.puts("  1: vertex normals\n");
    sdtx.puts("  2: texture coords\n");
    sdtx.puts("  3: vertex colors\n");

    // view-project matrix
    const proj = Mat4.persp(60.0, sapp.widthf() / sapp.heightf(), 0.01, 10.0);
    const view_proj = Mat4.mul(proj, state.view);

    // model-rotation matrix
    const dt: f32 = @floatCast(sapp.frameDuration() * 60);
    state.rx += 1.0 * dt;
    state.ry += 1.0 * dt;
    const rxm = Mat4.rotate(state.rx, .{ .x = 1, .y = 0, .z = 0 });
    const rym = Mat4.rotate(state.ry, .{ .x = 0, .y = 1, .z = 0 });
    const rm = Mat4.mul(rxm, rym);

    // render shapes...
    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });
    sg.applyPipeline(state.pip);
    sg.applyBindings(state.bind);
    for (state.shapes) |shape| {
        // per-shape model-view-projection matrix
        const model = Mat4.mul(Mat4.translate(shape.pos), rm);
        state.vs_params.mvp = Mat4.mul(view_proj, model);
        sg.applyUniforms(shd.UB_vs_params, sg.asRange(&state.vs_params));
        sg.draw(shape.draw.base_element, shape.draw.num_elements, 1);
    }
    sdtx.draw();
    sg.endPass();
    sg.commit();
}

pub export fn input(event: ?*const sapp.Event) void {
    const ev = event.?;
    if (ev.type == .KEY_DOWN) {
        state.vs_params.draw_mode = switch (ev.key_code) {
            ._1 => 0.0,
            ._2 => 1.0,
            ._3 => 2.0,
            else => state.vs_params.draw_mode,
        };
    }
}

pub export fn cleanup() void {
    sdtx.shutdown();
    sg.shutdown();
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = input,
        .cleanup_cb = cleanup,
        .width = 800,
        .height = 600,
        .sample_count = 4,
        .icon = .{ .sokol_default = true },
        .window_title = "shapes.zig",
        .logger = .{ .func = slog.func },
    });
}

// pub inline fn process_events(self: *@This()) void {
//     while (sokol.events.poll()) |event| switch (event) {
//         .quit, .terminating => self.game_state.quit = true,
//         .key_down => |keyboard| {
//             const key = keyboard.key orelse continue;
//             self.game_state.process_keydown(key);
//         },
//         .window_resized => |resize| {
//             self.game_state.screen_width = @floatFromInt(resize.width);
//             self.game_state.screen_height = @floatFromInt(resize.height);
//         },
//         .mouse_button_down => |*mb| self.game_state.process_mousebutton_down(mb),
//
//         .mouse_motion => |*mb| self.game_state.process_mouse_moved(mb.x, mb.y),
//         else => {},
//     };
// }

pub const GameState = struct {
    redraw_requested: bool = true,
    quit: bool = false,
    screen_width: f32 = inital_screen_width,
    screen_height: f32 = inital_screen_height,
    p1: Player = .{ .marbles = pt_array.white },
    p2: Player = .{ .marbles = pt_array.black },
    mouse_position: ?AxialVector = null,
    turn_state: TurnState = .default,

    pub fn process_keydown(self: *@This(), key: sokol.keycode.Keycode) void {
        switch (key) {
            .delete => self.quit = true,
            .escape => {
                self.turn_state = self.turn_state.previous();
                self.redraw_requested = true;
            },
            .space => {
                if (self.turn_state == .ChoosingChain) {
                    self.turn_state = self.turn_state.next(self.mouse_position) orelse return;
                    self.redraw_requested = true;
                }
            },

            .r => {
                self.p1 = .{ .marbles = pt_array.white };
                self.p2 = .{ .marbles = pt_array.black };
                self.turn_state = .default;
            },
            else => {},
        }
    }

    pub fn process_mousebutton_down(self: *@This(), mb: *const sokol.events.MouseButton) void {
        switch (self.turn_state) {
            .ChoosingChain => |*mv| {
                const moused_over = AxialVector.from_pixel_vec_screen_space(
                    mb.x,
                    mb.y,
                    self.screen_width,
                    self.screen_height,
                );

                self.redraw_requested = true;

                if (mv.balls.try_deselect(moused_over)) return;

                const same_color_marbles = switch (mv.turn) {
                    .p1 => &self.p1.marbles,
                    .p2 => &self.p2.marbles,
                };

                const ball_selected = mv.balls.try_select(same_color_marbles, moused_over);

                if (ball_selected and mv.balls.marbles.len == 3) {
                    self.turn_state = self.turn_state.next(self.mouse_position) orelse return;
                }
            },

            .ChoosingDirection => |mv| {
                const mv_dir = mv.dir orelse return;
                const player_move = move.Move.new(mv.balls.marbles.const_slice(), mv_dir);

                self.do_move(mv.turn, player_move) catch return;

                // on move success redraw
                self.redraw_requested = true;

                if (self.p1.score >= 6) {
                    std.log.info("Player 1 wins!", .{});
                    self.quit = true;
                } else if (self.p2.score >= 6) {
                    std.log.info("Player 2 wins!", .{});
                    self.quit = true;
                }

                // If we have completed the move then we switch players
                self.turn_state = self.turn_state.next(self.mouse_position) orelse return;
            },
        }
    }

    pub fn do_move(
        self: *@This(),
        turn: Turn,
        mv: move.Move,
    ) error{
        OutOfBounds,
        CannotPushSelf,
        CannotPushEnemy,
        ChainNotOwned,
    }!void {
        const move_vec = mv.dir.to_axial_vector();
        var friend: *Player, var enemy: *Player = switch (turn) {
            .p1 => .{ &self.p1, &self.p2 },
            .p2 => .{ &self.p2, &self.p1 },
        };

        var marbles: *Marbles = &friend.marbles;
        var enemy_marbles: *Marbles = &enemy.marbles;

        switch (mv.move_type) {
            .Inline1 => {
                const marble: AxialVector = mv.chain[0].add(move_vec);

                if (marble.out_of_bounds()) return error.OutOfBounds;
                if (marbles.contains(marble)) return error.CannotPushSelf;
                if (enemy_marbles.contains(marble)) return error.CannotPushEnemy;

                const i = marbles.find(mv.chain[0]) orelse unreachable;
                marbles.items[i] = marble;
            },
            .Broadside2 => {
                const moved: [2]AxialVector = .{
                    mv.chain[0].add(move_vec),
                    mv.chain[1].add(move_vec),
                };

                inline for (moved) |marble| {
                    if (marble.out_of_bounds()) return error.OutOfBounds;
                    if (marbles.contains(marble)) return error.CannotPushSelf;
                    if (enemy_marbles.contains(marble)) return error.CannotPushEnemy;
                }

                inline for (moved, mv.chain[0..moved.len]) |moved_marble, old| {
                    const i = marbles.find(old) orelse unreachable;
                    marbles.items[i] = moved_marble;
                }
            },
            .Broadside3 => {
                const moved: [3]AxialVector = .{
                    mv.chain[0].add(move_vec),
                    mv.chain[1].add(move_vec),
                    mv.chain[2].add(move_vec),
                };

                inline for (moved) |marble| {
                    if (marble.out_of_bounds()) return error.OutOfBounds;
                    if (marbles.contains(marble)) return error.CannotPushSelf;
                    if (enemy_marbles.contains(marble)) return error.CannotPushEnemy;
                }

                inline for (moved, mv.chain[0..moved.len]) |moved_marble, old| {
                    const i = marbles.find(old) orelse unreachable;
                    marbles.items[i] = moved_marble;
                }
            },

            .Inline2 => {
                // Explanation: With an `Inline2` I can move if the ray
                // in front of head is: [empty] or [enemy empty]
                const r1 = mv.chain[0].add(move_vec);
                if (r1.out_of_bounds()) return error.OutOfBounds;

                const r2 = r1.add(move_vec);

                for (mv.chain[0..2]) |pt| std.debug.assert(pt != r1);

                if (marbles.contains(r1)) return error.CannotPushSelf;
                if (enemy_marbles.find(r1)) |enemy_idx| {
                    // We cant push [enemy friend]
                    if (marbles.contains(r2)) return error.CannotPushSelf;
                    // We cant push [enemy enemy]
                    if (enemy_marbles.contains(r2)) return error.CannotPushEnemy;

                    // Move the old marble to the r2 position
                    if (r2.out_of_bounds()) {
                        enemy_marbles.swap_remove(enemy_idx);
                        friend.score += 1;
                    } else {
                        enemy_marbles.items[enemy_idx] = r2;
                    }

                    // Move the tail to r1
                    const tail_idx = marbles.find(mv.chain[1]) orelse return error.ChainNotOwned;
                    marbles.items[tail_idx] = r1;
                    return;
                } else {
                    // we have [empty]. move the tail to r1
                    const tail_idx = marbles.find(mv.chain[1]) orelse return error.ChainNotOwned;
                    marbles.items[tail_idx] = r1;
                    return;
                }
            },
            .Inline3 => {
                const r1 = mv.chain[0].add(move_vec);
                if (r1.out_of_bounds()) return error.OutOfBounds;

                const r2 = r1.add(move_vec);
                const r3 = r2.add(move_vec);

                for (mv.chain) |pt| std.debug.assert(pt != r1);

                if (enemy_marbles.find(r1)) |enemy_idx| {
                    if (enemy_marbles.contains(r2)) {
                        // [enemy enemy x]

                        if (enemy_marbles.contains(r3)) return error.CannotPushEnemy;
                        if (marbles.contains(r3)) return error.CannotPushSelf;

                        // move enemy to r3
                        if (r3.out_of_bounds()) {
                            enemy_marbles.swap_remove(enemy_idx);
                            friend.score += 1;
                        } else {
                            enemy_marbles.items[enemy_idx] = r3;
                        }

                        // move friend to r1
                        const friend_idx = marbles.find(mv.chain[2]) orelse unreachable;
                        marbles.items[friend_idx] = r1;
                    } else if (!marbles.contains(r2)) {
                        // [enemy x]

                        // move enemy to r2 and do bounds check
                        if (r2.out_of_bounds()) {
                            enemy_marbles.swap_remove(enemy_idx);
                            friend.score += 1;
                        } else {
                            enemy_marbles.items[enemy_idx] = r2;
                        }

                        // move friend to r1
                        const friend_idx = marbles.find(mv.chain[2]) orelse unreachable;
                        marbles.items[friend_idx] = r1;
                    }
                } else if (!marbles.contains(r1)) {
                    // [x]
                    // move friend to r1
                    const friend_idx = marbles.find(mv.chain[2]) orelse unreachable;
                    marbles.items[friend_idx] = r1;
                }
            },
        }
    }

    pub fn process_mouse_moved(self: *@This(), x: f32, y: f32) void {
        const new_pos =
            AxialVector.from_pixel_vec_screen_space(
                x,
                y,
                self.screen_width,
                self.screen_height,
            ).if_in_bounds();
        if (new_pos == self.mouse_position) return;

        self.mouse_position = new_pos;
        self.redraw_requested = true;

        // Update the chosen direction for selected balls
        const mp = self.mouse_position orelse return;

        switch (self.turn_state) {
            .ChoosingDirection => |*mv| {
                mv.dir = compute_best_fit_dir(mp, mv.balls.marbles.const_slice()) catch null;
            },
            else => {},
        }
    }

    pub fn render_background_hexagons(self: *const @This(), renderer: *const sokol.render.Renderer) !void {
        const hexagon_scale = 0.95;

        var background_hexagon = geometry.Hexagon{};
        background_hexagon.color(theme.magenta);
        background_hexagon.scale(hexagon_scale);

        // Render background tiles
        const bound = AxialVector.bound;
        var q: i8 = -bound;
        while (q <= bound) : (q += 1) {
            var r = @max(-bound, -bound - q);
            const end = @min(bound, bound - q);
            while (r <= end) : (r += 1) {
                const x, const y = (AxialVector{ .q = q, .r = r }).to_pixel_vec();

                var hexagon = background_hexagon;

                hexagon.shift(x + 1, y + 1);
                hexagon.scale(screen_factor);

                try renderer.renderGeometry(null, &hexagon.vertices, &geometry.Hexagon.indicies);
            }
        }

        // Render moused over balls
        if (self.mouse_position) |hex| {
            const x, const y = hex.to_pixel_vec();

            background_hexagon.color(theme.red);
            background_hexagon.shift(x + 1, y + 1);
            background_hexagon.scale(screen_factor);

            try renderer.renderGeometry(null, &background_hexagon.vertices, &geometry.Hexagon.indicies);
        }
    }

    pub fn render_square_texture(
        renderer: *const sokol.render.Renderer,
        positions: []const AxialVector,
        scale: f32,
        tex: sokol.render.Texture,
    ) !void {
        var default_square = geometry.Square{};
        default_square.scale(scale);

        for (positions) |pos| {
            const x, const y = pos.to_pixel_vec();

            var square = default_square;
            square.shift(x + 1, y + 1);
            square.scale(screen_factor);

            try renderer.renderGeometry(tex, &square.vertices, &geometry.Square.indicies);
        }
    }

    pub fn render_circles(
        renderer: *const sokol.render.Renderer,
        positions: []const AxialVector,
        color: geometry.color.rgba,
    ) !void {
        const ball_scale = 0.65;

        var default_circle = geometry.Circle{};
        default_circle.color(color);
        default_circle.scale(ball_scale);

        for (positions) |marble| {
            const x, const y = marble.to_pixel_vec();

            var circle = default_circle;

            circle.shift(x + 1, y + 1);
            circle.scale(screen_factor);

            try renderer.renderGeometry(null, &circle.vertices, &geometry.Circle.indicies);
        }
    }

    pub fn render_player_marbles(
        self: *const @This(),
        renderer: *const sokol.render.Renderer,
    ) !void {
        switch (self.turn_state) {
            .ChoosingChain => |mv| {
                // p1
                try GameState.render_circles(
                    renderer,
                    self.p1.marbles.const_slice(),
                    theme.white,
                );

                // p2
                try GameState.render_circles(
                    renderer,
                    self.p2.marbles.const_slice(),
                    theme.black,
                );

                try GameState.render_circles(
                    renderer,
                    mv.balls.marbles.const_slice(),
                    theme.red,
                );
            },

            .ChoosingDirection => |choosing_dir| {
                std.debug.assert(choosing_dir.balls.marbles.len >= 1);

                // Render the next move if any
                if (choosing_dir.dir) |move_dir| {
                    const mv = move.Move.new(choosing_dir.balls.marbles.const_slice(), move_dir);
                    var self_cpy = self.*;
                    self_cpy.do_move(choosing_dir.turn, mv) catch {};

                    // p1
                    try GameState.render_circles(
                        renderer,
                        self_cpy.p1.marbles.const_slice(),
                        theme.white,
                    );

                    // p2
                    try GameState.render_circles(
                        renderer,
                        self_cpy.p2.marbles.const_slice(),
                        theme.black,
                    );
                } else {
                    try GameState.render_circles(
                        renderer,
                        self.p1.marbles.const_slice(),
                        theme.white,
                    );

                    // p2
                    try GameState.render_circles(
                        renderer,
                        self.p2.marbles.const_slice(),
                        theme.black,
                    );

                    try GameState.render_circles(
                        renderer,
                        choosing_dir.balls.marbles.const_slice(),
                        theme.red,
                    );
                }
            },
        }
    }
    pub fn render_player_marbles_textured(
        self: *const @This(),
        renderer: *const sokol.render.Renderer,
        textures: *const Textures,
    ) !void {
        const ball_scale = 0.65;
        switch (self.turn_state) {
            .ChoosingChain => |mv| {
                try GameState.render_square_texture(
                    renderer,
                    self.p1.marbles.const_slice(),
                    ball_scale,
                    textures.blue_ball,
                );

                // p2
                try GameState.render_square_texture(
                    renderer,
                    self.p2.marbles.const_slice(),
                    ball_scale,
                    textures.red_ball,
                );

                _ = mv;
                // try GameState.render_square_texture(
                //     renderer,
                //     mv.balls.marbles.const_slice(),
                //     ball_scale,
                //     textures.blue_ball,
                // );
            },

            .ChoosingDirection => |choosing_dir| {
                std.debug.assert(choosing_dir.balls.marbles.len >= 1);

                // Render the next move if any
                if (choosing_dir.dir) |move_dir| {
                    const mv = move.Move.new(choosing_dir.balls.marbles.const_slice(), move_dir);
                    var self_cpy = self.*;
                    self_cpy.do_move(choosing_dir.turn, mv) catch {};

                    // p1
                    try GameState.render_square_texture(
                        renderer,
                        self_cpy.p1.marbles.const_slice(),
                        ball_scale,
                        textures.blue_ball,
                    );

                    // p2
                    try GameState.render_square_texture(
                        renderer,
                        self_cpy.p2.marbles.const_slice(),
                        ball_scale,
                        textures.red_ball,
                    );
                } else {
                    try GameState.render_square_texture(
                        renderer,
                        self.p1.marbles.const_slice(),
                        ball_scale,
                        textures.blue_ball,
                    );

                    // p2
                    try GameState.render_square_texture(
                        renderer,
                        self.p2.marbles.const_slice(),
                        ball_scale,
                        textures.red_ball,
                    );

                    try GameState.render_square_texture(
                        renderer,
                        choosing_dir.balls.marbles.const_slice(),
                        ball_scale,
                        textures.blue_ball,
                    );
                }
            },
        }
    }

    pub fn render(
        self: *const @This(),
        renderer: *const sokol.render.Renderer,
        textures: *const Textures,
    ) !void {
        // background
        try self.render_background_hexagons(renderer);
        try self.render_player_marbles_textured(renderer, textures);
    }
};

pub const Player = struct {
    score: u3 = 0,
    marbles: Marbles,
};
