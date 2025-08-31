pub const Piece = enum { white, black };
pub const Row = enum { a, b, c, d, e, f, g, h, i };
pub const Move = struct {};

pub const Board = struct {
    /// a     ⬤ ⬤ ⬤ ⬤ ⬤
    /// b    ⬤ ⬤ ⬤ ⬤ ⬤ ⬤
    /// c   ⬤ ⬤ ⬤ ⬤ ⬤ ⬤ ⬤
    /// d  ⬤ ⬤ ⬤ ⬤ ⬤ ⬤ ⬤ ⬤
    /// e ⬤ ⬤ ⬤ ⬤ ⬤ ⬤ ⬤ ⬤ ⬤
    /// f  ⬤ ⬤ ⬤ ⬤ ⬤ ⬤ ⬤ ⬤
    /// g   ⬤ ⬤ ⬤ ⬤ ⬤ ⬤ ⬤
    /// h    ⬤ ⬤ ⬤ ⬤ ⬤ ⬤
    /// i     ⬤ ⬤ ⬤ ⬤ ⬤
    pieces: [NUM_PIECES]?Piece,

    pub const NUM_PIECES = 61;

    pub fn get_row(self: *@This(), comptime row: Row) []?Piece {
        const size, const offset =
            switch (row) {
                .a, .i => .{ 5, 0 },
                .b, .h => .{ 6, 5 },
                .c, .g => .{ 7, 6 + 5 },
                .d, .f => .{ 8, 7 + 6 + 5 },
                .e => .{ 9, 8 + 7 + 6 + 5 },
            };

        return self.pieces[offset .. offset + size];
    }
};
