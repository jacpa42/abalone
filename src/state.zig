const std = @import("std");
const sdl3 = @import("sdl3");
const geometry = @import("state/geometry.zig");
const move = @import("move.zig");
const pt_array = @import("point_array.zig");

const AxialVector = @import("axial.zig").AxialVector;
const Direction = move.HexagonalDirection;
const Marbles = pt_array.PointArray(14);

const screen_factor = @import("main.zig").logical_size * 0.5;

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
///
/// We then process the move and start again
const TurnStateEnum = enum { ChoosingChain, ChoosingDirection };

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

    pub const default = TurnState{
        .ChoosingChain = .{ .turn = .p1, .balls = .{} },
    };

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
                return TurnState{ .ChoosingChain = .{ .turn = mv.turn.next(), .balls = .{} } };
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

            .r => {
                self.p1 = .{ .marbles = pt_array.white };
                self.p2 = .{ .marbles = pt_array.black };
                self.mouse_position = null;
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
            .ChoosingDirection => |mv| {
                const mv_dir = mv.dir orelse return;
                const player_move = move.Move.new(mv.balls.marbles.const_slice(), mv_dir) catch |e| {
                    std.log.err("Failed to construct move: {}", .{e});
                    return;
                };
                self.try_do_move(mv.turn, player_move) catch |e| {
                    std.log.err("Failed to do move: {}", .{e});
                    return;
                };

                // If we have completed the move then we switch players
                self.turn_state = self.turn_state.next() orelse return;
            },
        }
    }

    pub fn try_do_move(
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
                const r2 = r1.add(move_vec);

                if (marbles.contains(r1)) return error.CannotPushSelf;
                if (enemy_marbles.find(r1)) |idx| {
                    // We cant push [enemy friend]
                    if (marbles.contains(r2)) return error.CannotPushSelf;
                    // We cant push [enemy enemy]
                    if (enemy_marbles.contains(r2)) return error.CannotPushEnemy;

                    // Move the old marble to the r2 position
                    enemy_marbles.items[idx] = r2;
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
                self.clean_your_balls();
            },
            .Inline3 => {
                const r1 = mv.chain[0].add(move_vec);
                if (r1.out_of_bounds()) return error.OutOfBounds;

                const r2 = r1.add(move_vec);
                const r3 = r2.add(move_vec);

                for (mv.chain) |pt| {
                    std.debug.print("r1r2r3 = {any} {any} {any}\n", .{
                        r1.if_in_bounds(),
                        r2.if_in_bounds(),
                        r3.if_in_bounds(),
                    });

                    std.debug.assert(pt != r1);
                }

                if (enemy_marbles.find(r1)) |enemy_idx| {
                    if (enemy_marbles.contains(r2)) {
                        // [enemy enemy x]

                        if (enemy_marbles.contains(r3)) return error.CannotPushEnemy;
                        if (marbles.contains(r3)) return error.CannotPushSelf;

                        // move enemy to r3
                        enemy_marbles.items[enemy_idx] = r3;

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
        self.mouse_position = AxialVector.from_pixel_vec_screen_space(
            x,
            y,
            self.screen_width,
            self.screen_height,
        ).if_in_bounds();

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

        // background
        try self.render_background_hexagons(renderer);

        // p1
        try State.render_circles(
            renderer,
            self.p1.marbles.const_slice(),
            geometry.white,
        );

        // p2
        try State.render_circles(
            renderer,
            self.p2.marbles.const_slice(),
            geometry.black,
        );

        switch (self.turn_state) {
            .ChoosingChain => |mv| {
                try State.render_circles(
                    renderer,
                    mv.balls.marbles.const_slice(),
                    geometry.grey,
                );
            },

            .ChoosingDirection => |mv| {
                std.debug.assert(mv.balls.marbles.len >= 1);

                try State.render_circles(
                    renderer,
                    mv.balls.marbles.const_slice(),
                    geometry.grey,
                );

                // Render the next move if any
                if (mv.dir) |move_dir| {
                    var moved_balls = pt_array.PointArray(3).empty;

                    for (mv.balls.marbles.const_slice()) |ball| {
                        const moved_ball = ball.add(move_dir.to_axial_vector());
                        if (moved_ball.out_of_bounds()) return;
                        moved_balls.append(moved_ball);
                    }

                    try State.render_circles(
                        renderer,
                        moved_balls.const_slice(),
                        geometry.light_grey,
                    );
                }
            },
        }
    }
};

pub fn compute_best_fit_dir(mouse_position: AxialVector, balls: []const AxialVector) error{DivideByZero}!Direction {
    var q: f32, var r: f32 = .{ 0.0, 0.0 };

    // Compute the average vector to the mouse position and normalize to get the angle
    {
        for (balls) |marble| {
            const diffvec = mouse_position.sub(marble);
            q += @floatFromInt(diffvec.q);
            r += @floatFromInt(diffvec.r);
        }

        const size = (@abs(q) + @abs(q + r) + @abs(r)) * 0.5;
        if (size == 0) return error.DivideByZero;
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

    return best_dir;
}
