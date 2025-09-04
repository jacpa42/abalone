const std = @import("std");
const sdl3 = @import("sdl3");
const geometry = @import("state/geometry.zig");
const move = @import("move.zig");
const pt_array = @import("point_array.zig");
const turn_state = @import("state/turn.zig");
const texture = @import("textures.zig");

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
const sdl_init_flags = sdl3.InitFlags{ .video = true };

pub const State = struct {
    game_state: GameState = .{},
    fps_capper: sdl3.extras.FramerateCapper(f32) = .{ .mode = .{ .limited = fps } },
    window: sdl3.video.Window,
    renderer: sdl3.render.Renderer,
    textures: Textures,

    // Initalizes sdl3 and self. You must call `deinit()` to clean up.
    pub fn init() !@This() {
        try sdl3.init(sdl_init_flags);

        const window_flags = sdl3.video.Window.Flags{
            .always_on_top = true,
            .keyboard_grabbed = true,
            .resizable = false,
            .borderless = true,
            .transparent = true,
            .mouse_capture = true,
            .mouse_grabbed = true,
        };

        // Create a rendering context and window
        const gfx = try sdl3.render.Renderer.initWithWindow(
            "abalone",
            inital_screen_width,
            inital_screen_height,
            window_flags,
        );

        try gfx.renderer.setLogicalPresentation(logical_size, logical_size, .integer_scale);

        return @This(){
            .window = gfx.window,
            .renderer = gfx.renderer,
            .textures = try Textures.init(gfx.renderer),
        };
    }

    pub inline fn render(self: *@This()) !void {
        if (!self.game_state.redraw_requested) return;

        try self.game_state.render(&self.renderer);
        try self.renderer.renderTexture(self.textures.blue_ball, null, null);
        try self.renderer.present();

        self.game_state.redraw_requested = false;
    }

    pub inline fn process_events(self: *@This()) void {
        while (sdl3.events.poll()) |event| switch (event) {
            .quit, .terminating => self.game_state.quit = true,
            .key_down => |keyboard| {
                const key = keyboard.key orelse continue;
                self.game_state.process_keydown(key);
            },
            .window_resized => |resize| {
                self.game_state.screen_width = @floatFromInt(resize.width);
                self.game_state.screen_height = @floatFromInt(resize.height);
            },
            .mouse_button_down => |*mb| self.game_state.process_mousebutton_down(mb),

            .mouse_motion => |*mb| self.game_state.process_mouse_moved(mb.x, mb.y),
            else => {},
        };
    }

    pub fn deinit(self: *@This()) void {
        self.textures.deinit();
        self.window.deinit();
        self.renderer.deinit();
        sdl3.quit(sdl_init_flags);
        sdl3.shutdown();
    }
};

pub const GameState = struct {
    redraw_requested: bool = true,
    quit: bool = false,
    screen_width: f32 = inital_screen_width,
    screen_height: f32 = inital_screen_height,
    p1: Player = .{ .marbles = pt_array.white },
    p2: Player = .{ .marbles = pt_array.black },
    mouse_position: ?AxialVector = null,
    turn_state: TurnState = .default,

    pub fn process_keydown(self: *@This(), key: sdl3.keycode.Keycode) void {
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

    pub fn process_mousebutton_down(self: *@This(), mb: *const sdl3.events.MouseButton) void {
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

    pub fn render_background_hexagons(self: *const @This(), renderer: *const sdl3.render.Renderer) !void {
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

    pub fn render_circles(
        renderer: *const sdl3.render.Renderer,
        circles: []const AxialVector,
        color: geometry.color.rgba,
    ) !void {
        const ball_scale = 0.65;

        var default_circle = geometry.Circle{};
        default_circle.color(color);
        default_circle.scale(ball_scale);

        for (circles) |marble| {
            const x, const y = marble.to_pixel_vec();

            var circle = default_circle;

            circle.shift(x + 1, y + 1);
            circle.scale(screen_factor);

            try renderer.renderGeometry(null, &circle.vertices, &geometry.Circle.indicies);
        }
    }

    pub fn render(self: *const @This(), renderer: *const sdl3.render.Renderer) !void {
        // background
        try self.render_background_hexagons(renderer);

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
};

pub const Player = struct {
    score: u3 = 0,
    marbles: Marbles,
};

pub const Textures = struct {
    blue_ball: sdl3.render.Texture,
    red_ball: sdl3.render.Texture,
    blue_heart: sdl3.render.Texture,
    red_heart: sdl3.render.Texture,

    pub fn init(renderer: sdl3.render.Renderer) !@This() {
        return .{
            .blue_ball = try texture.BlueBall.upload(renderer),
            .red_ball = try texture.RedBall.upload(renderer),
            .blue_heart = try texture.BlueHeart.upload(renderer),
            .red_heart = try texture.RedHeart.upload(renderer),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.blue_ball.deinit();
        self.red_ball.deinit();
        self.blue_heart.deinit();
        self.red_heart.deinit();
    }
};
