const sokol = @import("sokol");
const std = @import("std");
const move = @import("move.zig");
const pt_array = @import("point_array.zig");
const turn_state = @import("state/turn.zig");

const SelectedBalls = @import("state/selected_balls.zig").SelectedBalls;
const AxialVector = @import("axial.zig").AxialVector;
const Direction = move.HexagonalDirection;
const Marbles = pt_array.PointArray(14);
const TurnState = turn_state.TurnState;
const Turn = turn_state.Turn;

pub const compute_best_fit_dir = turn_state.compute_best_fit_dir;

const fps = 60;
const logical_size = 100;
const inital_screen_width = 1000;
const inital_screen_height = 1000;
const screen_factor = logical_size * 0.5;

pub const GameState = struct {
    screen_width: f32 = inital_screen_width,
    screen_height: f32 = inital_screen_height,
    p1: Player = .{ .marbles = pt_array.white },
    p2: Player = .{ .marbles = pt_array.black },
    mouse_position: AxialVector = .zero,
    turn_state: TurnState = .default,

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

    pub fn process_keydown(self: *@This(), key: sokol.app.Keycode) void {
        switch (key) {
            .DELETE => sokol.app.quit(),
            .ESCAPE => {
                self.turn_state = self.turn_state.previous();
            },
            .SPACE => {
                if (self.turn_state == .ChoosingChain) {
                    self.turn_state = self.turn_state.next(self.mouse_position) orelse return;
                }
            },

            .R => {
                self.p1 = .{ .marbles = pt_array.white };
                self.p2 = .{ .marbles = pt_array.black };
                self.turn_state = .default;
            },
            else => {},
        }
    }

    /// expects x and y in ndc
    pub fn process_mousebutton_down(self: *@This(), x: f32, y: f32) void {
        switch (self.turn_state) {
            .ChoosingChain => |*mv| {
                const moused_over = AxialVector.from_pixel_vec(x, y);

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

                if (self.p1.score >= 6) {
                    std.log.info("Player 1 wins!", .{});
                } else if (self.p2.score >= 6) {
                    std.log.info("Player 2 wins!", .{});
                }

                // If we have completed the move then we switch players
                self.turn_state = self.turn_state.next(self.mouse_position) orelse return;
            },
        }
    }

    /// expects x and y in ndc
    pub fn process_mouse_moved(self: *@This(), x: f32, y: f32) void {
        const new_pos = AxialVector.from_pixel_vec(x, y);

        if (new_pos == self.mouse_position) return;

        self.mouse_position = new_pos;

        switch (self.turn_state) {
            .ChoosingDirection => |*mv| {
                mv.dir = compute_best_fit_dir(new_pos, mv.balls.marbles.const_slice()) catch null;
            },
            else => {},
        }
    }
};

pub const Player = struct {
    score: u3 = 0,
    marbles: Marbles,
};
