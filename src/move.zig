const std = @import("std");
const AxialPoint = @import("axial_point.zig").AxialPoint;

const Polarity = enum(u1) { positive, negative };
const Axis = enum(u2) { q, r, s };
pub const Direction = struct { axis: Axis, polarity: Polarity };

const MoveCreationError = error{
    NoPoints,
    TooManyPoints,
    PointsNotTogether,
};

/// A general game move.
pub const Move = struct {
    /// Note that this has 1 <= len <= 3
    points: []AxialPoint,
    direction: Direction,
    point_alignment: Direction,

    /// Note that this will mutate the order points potentially!
    pub fn new(points: []AxialPoint, direction: Direction) MoveCreationError!@This() {
        switch (points.len) {
            0 => return error.NoPoints,
            1 => return Move{ .points = points, .direction = direction },
            2 => {
                // Compute the hex 01 vector.
                const chain_vec = points[0].sub(points[1]);

                var move = @This(){ .points = points, .direction = direction, .point_alignment = undefined };

                // If they lie along the q-axis, then r = 0
                if (chain_vec.r == 0) {
                    // The distance along the q axis is 1 in absolute value
                    const polarity = switch (chain_vec.q) {
                        -1 => Polarity.negative,
                        1 => Polarity.positive,
                        else => return error.PointsNotTogether,
                    };

                    move.direction = .{ .axis = .q, .polarity = polarity };
                    return move;
                }
                // If they lie along the r-axis, then q = 0
                if (chain_vec.q == 0) {
                    // The distance along the r axis is 1 in absolute value
                    const polarity = switch (chain_vec.r) {
                        -1 => Polarity.negative,
                        1 => Polarity.positive,
                        else => return error.PointsNotTogether,
                    };

                    move.direction = .{ .axis = .r, .polarity = polarity };
                    return move;
                }
                // If they lie along the s-axis, then s = 0 => q = -r
                if (chain_vec.q == -chain_vec.r) {

                    // The distance along the r axis is 1 in absolute value
                    const polarity = switch (chain_vec.q) {
                        -1 => Polarity.negative,
                        1 => Polarity.positive,
                        else => return error.PointsNotTogether,
                    };

                    move.direction = .{ .axis = .s, .polarity = polarity };
                    return move;
                }

                // otherwise we shit the bed
                return error.PointsNotTogether;
            },
            3 => {
                // todo!!!
            },

            else => return error.TooManyPoints,
        }
    }
};
