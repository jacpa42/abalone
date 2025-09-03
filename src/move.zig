const std = @import("std");
const AxialVector = @import("axial.zig").AxialVector;

/// A direction in hex coordinates is a combination of 2 Axial axes.
/// It represents all the directions we can move in for our game
pub const HexagonalDirection = enum {
    /// -r and +q
    /// {q r s} = {1 -1 0}
    ur,

    /// Combination of +q and -s
    /// {q r s} = {1 0 -1}
    r,

    /// Combination of -s and +r
    /// {q r s} = {0 1 -1}
    dr,

    /// Combination of +r and -q
    /// {q r s} = {-1 1 0}
    dl,

    /// Combination of -q and +s
    /// {q r s} = {-1 0 1}
    l,

    /// Combination of +s and -r
    /// {q r s} = {0 -1 1}
    ul,

    pub inline fn to_axial_vector(self: @This()) AxialVector {
        return switch (self) {
            .ur => .{ .q = 1, .r = -1 },
            .r => .{ .q = 1, .r = 0 },
            .dr => .{ .q = 0, .r = 1 },
            .dl => .{ .q = -1, .r = 1 },
            .l => .{ .q = -1, .r = 0 },
            .ul => .{ .q = 0, .r = -1 },
        };
    }

    // pub inline fn neg(self: @This()) @This() {
    //     return switch (self) {
    //         .ur => .dl,
    //         .r => .l,
    //         .dr => .ul,
    //         .dl => .ur,
    //         .l => .r,
    //         .ul => .dr,
    //     };
    // }

    // If the two directions are aligned, then same direction returns `.pos` and opposite directions return `.neg`. Otherwise null
    // pub inline fn alignment(self: @This(), other: @This()) ?enum { pos, neg } {
    //     if (self == other) return .pos;
    //     if (self == other.neg()) return .neg;
    //     return null;
    // }
};

pub const MoveType = enum {
    Broadside2,
    Broadside3,
    Inline1,
    Inline2,
    Inline3,
};

/// A general game move.
///
/// `BroadsideN`: For this move type we have several pieces and a direction in which they move, we don't care much for the order of the pieces.
/// `InlineN`: For this type of move the pieces move along the axis defined in the `dir` field.
pub const Move = struct {
    move_type: MoveType,

    /// Head is 0, tail is last. Number of pieces is defined by the `move_type`
    chain: [3]AxialVector,
    dir: HexagonalDirection,

    /// Constructs a new move. The points put into this function are assumed to be hexagonally aligned.
    pub fn new(points: []const AxialVector, move_dir: HexagonalDirection) error{ NoPoints, TooManyPoints }!@This() {
        switch (points.len) {
            0 => return error.NoPoints,
            1 => return Move{
                .move_type = .Inline1,
                .chain = .{ points[0], undefined, undefined },
                .dir = move_dir,
            },
            2 => {
                // 0 -> 1 vector
                const vec = points[1].sub(points[0]);
                const move_vec = move_dir.to_axial_vector();

                const alignment = vec.alignment(move_vec) orelse return Move{
                    .move_type = .Broadside2,
                    .chain = .{ points[0], points[1], undefined },
                    .dir = move_dir,
                };

                switch (alignment) {
                    // 0 -> 1 is in the same direction as the move_dir
                    .pos => return Move{
                        .move_type = .Inline2,
                        .chain = .{ points[1], points[0], undefined },
                        .dir = move_dir,
                    },

                    // 0 -> 1 is in the opposite direction as the move_dir
                    .neg => return Move{
                        .move_type = .Inline2,
                        .chain = .{ points[0], points[1], undefined },
                        .dir = move_dir,
                    },
                }
            },

            3 => {
                // For the case of 3 points we only need the head and tail.
                // Because of this we do the exact same thing as on the 2
                // point case but with some other checks just before

                const indices: [3][3]usize = .{ .{ 0, 1, 2 }, .{ 0, 2, 1 }, .{ 1, 2, 0 } };
                for (indices) |idx| {
                    const a, const b, const c = idx;

                    // a -> b vector
                    const vec = points[a].sub(points[b]);

                    // Distance between them must be 2
                    if (vec.size() != 2) continue;

                    const move_vec = move_dir.to_axial_vector();

                    const alignment = vec.alignment(move_vec) orelse return Move{
                        .move_type = .Broadside3,
                        .chain = .{ points[a], points[c], points[b] },
                        .dir = move_dir,
                    };

                    switch (alignment) {
                        // 0 -> 1 is in the same direction as the move_dir
                        .pos => return Move{
                            .move_type = .Inline3,
                            .chain = .{ points[a], points[c], points[b] },
                            .dir = move_dir,
                        },

                        // 0 -> 1 is in the opposite direction as the move_dir
                        .neg => return Move{
                            .move_type = .Inline3,
                            .chain = .{ points[b], points[c], points[a] },
                            .dir = move_dir,
                        },
                    }
                }

                unreachable;
            },

            else => return error.TooManyPoints,
        }
    }
};
