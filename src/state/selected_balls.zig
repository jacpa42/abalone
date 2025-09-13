const std = @import("std");

const PointArray = @import("../point_array.zig").PointArray;
const AxialVector = @import("../axial.zig").AxialVector;

/// Basically a cyclical array of ball indicies for the current player
pub const SelectedBalls = struct {
    marbles: PointArray(3) = .empty,

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
        same_color_marbles: *const PointArray(14),
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
