const std = @import("std");

const SelectedBalls = @import("selected_balls.zig").SelectedBalls;
const Direction = @import("../move.zig").HexagonalDirection;
const AxialVector = @import("../axial.zig").AxialVector;

/// The game follows this pattern:
///
/// 1. Player picks chain.
/// 2. Player picks direction to move in.
///
/// We then process the move and start again
const TurnStateEnum = enum { ChoosingChain, ChoosingDirection };

pub const Turn = enum {
    p1,
    p2,

    pub fn next(self: @This()) @This() {
        return switch (self) {
            .p1 => .p2,
            .p2 => .p1,
        };
    }
};

pub const TurnState = union(TurnStateEnum) {
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

    pub fn get_turn(self: *const @This()) Turn {
        switch (self.*) {
            .ChoosingChain => |*data| return data.turn,
            .ChoosingDirection => |*data| return data.turn,
        }
    }

    /// Trys to advance state, will fail in certain situations.
    pub fn next(self: @This(), mouse_pos: AxialVector) ?@This() {
        switch (self) {
            .ChoosingChain => |mv| {
                if (mv.balls.marbles.len == 0) return null;

                var dir: ?Direction = null;
                if (mouse_pos.if_in_bounds()) |pos| {
                    dir = compute_best_fit_dir(
                        pos,
                        mv.balls.marbles.const_slice(),
                    ) catch null;
                }

                return TurnState{
                    .ChoosingDirection = .{
                        .turn = mv.turn,
                        .balls = mv.balls,
                        .dir = dir,
                    },
                };
            },

            .ChoosingDirection => |mv| {
                return TurnState{ .ChoosingChain = .{ .turn = mv.turn.next(), .balls = .{} } };
            },
        }
    }

    pub fn previous(self: @This()) @This() {
        switch (self) {
            .ChoosingChain => |mv| {
                return TurnState{
                    .ChoosingChain = .{ .turn = mv.turn, .balls = .{} },
                };
            },

            .ChoosingDirection => |mv| {
                return TurnState{
                    .ChoosingChain = .{ .turn = mv.turn, .balls = mv.balls },
                };
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
        if (size < 1e-2) return error.DivideByZero;
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
