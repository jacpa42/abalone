const std = @import("std");
const Move = @import("move.zig").Move;
const AxialPoint = @import("axial_point.zig").AxialPoint;

const Cells = std.ArrayHashMapUnmanaged(
    AxialPoint,
    enum(u8) { white, black },
    AxialPoint.Hasher(),
    false,
);

/// This represents our playable surface. It is a |q| <= 4, |r| <= 4, |s| <= 4.
const HexagonalGrid = struct {
    /// A small hashmap of all remaining cells
    cells: Cells,
};
