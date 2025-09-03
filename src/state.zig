const std = @import("std");
const sdl3 = @import("sdl3");
const geometry = @import("state/geometry.zig");
const move = @import("move.zig");
const pt_array = @import("point_array.zig");

const AxialVector = @import("axial.zig").AxialVector;
const Direction = move.HexagonalDirection;

const Marbles = pt_array.PointArray(14);

/// Basically a cyclical array of ball indicies for the current player
const SelectedBalls = struct {
    marbles: pt_array.PointArray(3) = .empty,

    /// Trys to unselect a ball
    ///
    /// - The ball must be selected.
    /// - The ball cannot break a chain (only in the case of 3 balls)
    pub fn try_deselect(self: *@This(), item: AxialVector) bool {
        const i = self.marbles.find(item) orelse return false;

        // If we have selected 3 then we can't deselect center.
        if (self.marbles.len == 3) {
            // get the other two indices
            const a = @mod(i + 1, 3);
            const b = @mod(i + 2, 3);
            const vec_ai = item.sub(self.marbles.items[a]);
            const vec_bi = item.sub(self.marbles.items[b]);

            // If they are both 1 then the selected must be in the middle of them!
            if (vec_ai.size() == vec_bi.size()) {
                std.log.info("Cannot deselect center of triplet!!", .{});
                return false;
            }
        }

        self.marbles.swap_remove(i);
        return true;
    }

    /// Will try to pick the ball. All the following are checked:
    ///
    /// - That we have >=1 capacity to store a marble.
    /// - All balls must be in bounds.
    /// - All balls must be a neighbour.
    /// - All balls need to match the player color.
    /// - All balls need to be in a straight line.
    pub fn try_select(
        self: *@This(),
        same_color_marbles: *const Marbles,
        item: AxialVector,
    ) bool {
        // We can have at most 3 marbles
        if (self.marbles.len == 3) return false;

        // Check that the ball is in bounds
        if (item.out_of_bounds()) return false;

        // Check that the ball is a neighbour
        if (!self.is_neighbour(item)) return false;

        // Check that the balls are the same color
        if (!same_color_marbles.contains(item)) return false;

        // If we have 2 balls then we need to check alignment of the third
        if (self.marbles.len == 2) {
            // 0 -> p vec
            const vec0p = item.sub(self.marbles.items[0]);
            // 1 -> p vec
            const vec1p = item.sub(self.marbles.items[1]);
            // These must be parallel
            if (!vec0p.parallel(vec1p)) return false;
        }

        self.marbles.append(item);
        return true;
    }

    /// Checks that the `pt` is:
    ///
    /// - Not one of the already selected balls
    /// - 1 distance away from 1 of the balls (if any)
    pub fn is_neighbour(self: *const @This(), pt: AxialVector) bool {
        if (self.marbles.len == 0) return true;
        for (self.marbles.const_slice()) |ball| if (ball == pt) return false;
        for (self.marbles.const_slice()) |ball| if (ball.dist(pt) == 1) return true;

        return false;
    }
};

pub const Player = struct {
    score: u3 = 0,
    marbles: Marbles,
};

/// The game follows this pattern:
///
/// 1. Player picks chain.
/// 2. Player picks direction to move in.
/// 3. Do move, update score and switch turns
const TurnStateEnum = enum {
    ChoosingChain,
    ChoosingDirection,
    ProcessMove,
};

const Turn = enum {
    p1,
    p2,

    pub fn next(self: @This()) @This() {
        return switch (self) {
            .p1 => .p2,
            .p2 => .p1,
        };
    }
};

const TurnState = union(TurnStateEnum) {
    ChoosingChain: struct {
        turn: Turn,
        balls: SelectedBalls,
    },
    ChoosingDirection: struct {
        turn: Turn,
        balls: SelectedBalls,
        dir: ?Direction,
    },
    ProcessMove: struct {
        turn: Turn,
        balls: SelectedBalls,
        dir: Direction,
    },

    pub const default = TurnState{
        .ChoosingChain = .{ .turn = .p1, .balls = .{} },
    };

    // pub inline fn get_turn(self: *const @This()) Turn {
    //     return switch (self.*) {
    //         .ChoosingChain => |*mv| mv.turn,
    //         .ChoosingDirection => |*mv| mv.turn,
    //         .ProcessMove => |*mv| mv.turn,
    //     };
    // }

    /// Trys to advance state, will fail in certain situations.
    pub fn next(self: @This()) ?@This() {
        switch (self) {
            .ChoosingChain => |mv| {
                if (mv.balls.marbles.len == 0) return null;

                return TurnState{
                    .ChoosingDirection = .{
                        .turn = mv.turn,
                        .balls = mv.balls,
                        .dir = null,
                    },
                };
            },
            .ChoosingDirection => |mv| {
                // Note: I shouldn't actually need to check this.
                if (mv.balls.marbles.len == 0) return null;

                const dir = mv.dir orelse return null;

                return TurnState{
                    .ProcessMove = .{
                        .turn = mv.turn,
                        .balls = mv.balls,
                        .dir = dir,
                    },
                };
            },
            .ProcessMove => |mv| {
                return TurnState{
                    .ChoosingChain = .{ .turn = mv.turn.next(), .balls = .{} },
                };
            },
        }
    }
};

pub const State = struct {
    /// This represents our playable surface. It is a |q| <= 4, |r| <= 4, |s| <= 4.
    quit: bool = false,
    screen_width: f32,
    screen_height: f32,

    p1: Player = .{ .marbles = pt_array.white },
    p2: Player = .{ .marbles = pt_array.black },
    mouse_position: ?AxialVector = null,
    turn_state: TurnState = .default,

    pub fn process_keydown(self: *@This(), key: sdl3.keycode.Keycode) void {
        switch (key) {
            .escape => self.quit = true,
            // TODO: select the current balls, choose the move and then execute and swap turns
            .return_key => {
                self.turn_state = self.turn_state.next() orelse return;
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

                if (!mv.balls.try_deselect(moused_over)) {
                    const same_color_marbles =
                        switch (mv.turn) {
                            .p1 => &self.p1.marbles,
                            .p2 => &self.p2.marbles,
                        };
                    if (!mv.balls.try_select(same_color_marbles, moused_over)) {
                        std.log.info("Failed to select ball", .{});
                    }
                }
            },
            else => {},
        }
    }

    pub fn process_mouse_moved(self: *@This(), x: f32, y: f32) void {
        self.mouse_position = AxialVector.from_pixel_vec_screen_space(
            x,
            y,
            self.screen_width,
            self.screen_height,
        ).if_in_bounds();
    }

    pub fn render_background_hexagons(
        self: *const @This(),
        renderer: *const sdl3.render.Renderer,
        screen_factor: f32,
    ) !void {
        const hexagon_scale = 0.95;

        var background_hexagon = geometry.Hexagon{};
        background_hexagon.color(geometry.purple);
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

            background_hexagon.color(geometry.red);
            background_hexagon.shift(x + 1, y + 1);
            background_hexagon.scale(screen_factor);

            try renderer.renderGeometry(null, &background_hexagon.vertices, &geometry.Hexagon.indicies);
        }
    }

    pub fn render_circles(
        renderer: *const sdl3.render.Renderer,
        circles: []const AxialVector,
        screen_factor: f32,
        color: geometry.Color,
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
        const screen_factor = @import("main.zig").logical_size * 0.5;

        // background
        try self.render_background_hexagons(renderer, screen_factor);

        // p1
        try State.render_circles(
            renderer,
            self.p1.marbles.const_slice(),
            screen_factor,
            geometry.white,
        );

        // p2
        try State.render_circles(
            renderer,
            self.p2.marbles.const_slice(),
            screen_factor,
            geometry.black,
        );

        switch (self.turn_state) {
            .ChoosingChain => |mv| {
                try State.render_circles(
                    renderer,
                    mv.balls.marbles.const_slice(),
                    screen_factor,
                    geometry.grey,
                );
            },

            .ChoosingDirection => |mv| {
                try State.render_circles(
                    renderer,
                    mv.balls.marbles.const_slice(),
                    screen_factor,
                    geometry.grey,
                );

                std.debug.assert(mv.balls.marbles.len >= 1);

                if (self.mouse_position) |pos| {
                    var q: f32, var r: f32 = .{ 0.0, 0.0 };

                    // Compute the average vector to the mouse position and normalize to get the angle
                    {
                        for (mv.balls.marbles.const_slice()) |marble| {
                            const diffvec = pos.sub(marble);
                            q += @floatFromInt(diffvec.q);
                            r += @floatFromInt(diffvec.r);
                        }

                        const size = (@abs(q) + @abs(q + r) + @abs(r)) * 0.5;
                        if (size == 0) return;
                        q /= size;
                        r /= size;
                    }

                    // Compute the move direction which best suits this mouse position.
                    var dist = std.math.inf(f32);
                    var best_dir = Direction.l;
                    inline for (0..@typeInfo(Direction).@"enum".fields.len) |dir_idx| {
                        const dir: Direction = @enumFromInt(dir_idx);
                        const dir_vec = dir.to_axial_vector();
                        const fq: f32 = @floatFromInt(dir_vec.q);
                        const fr: f32 = @floatFromInt(dir_vec.r);

                        const new_dist = (@abs(q - fq) + @abs(q + r - fq - fr) + @abs(r - fr)) * 0.5;
                        if (new_dist < dist) {
                            dist = new_dist;
                            best_dir = dir;
                        }
                    }

                    // Simulate moving the balls in this direction
                    var balls = mv.balls;
                    for (balls.marbles.slice()) |*ball| {
                        ball.* = ball.add(best_dir.to_axial_vector());
                    }

                    try State.render_circles(
                        renderer,
                        balls.marbles.const_slice(),
                        screen_factor,
                        geometry.light_grey,
                    );
                }
            },

            // we don't render anything special for this state
            .ProcessMove => return,
        }
    }
};
