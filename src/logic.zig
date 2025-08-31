const std = @import("std");

pub const PieceColor = enum { white, black };
pub const MoveType = enum { Broadside, Inline };
pub const Row = enum(i8) {
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,

    pub fn prev(self: @This()) @This() {
        return switch (self) {
            .a => .i,
            .b => .a,
            .c => .b,
            .d => .c,
            .e => .d,
            .f => .e,
            .g => .f,
            .h => .g,
            .i => .h,
        };
    }

    pub fn next(self: @This()) @This() {
        return switch (self) {
            .a => .b,
            .b => .c,
            .c => .d,
            .d => .e,
            .e => .f,
            .f => .g,
            .g => .h,
            .h => .i,
            .i => .a,
        };
    }

    pub fn size(self: @This()) i8 {
        return switch (self) {
            .a => 5,
            .b => 6,
            .c => 7,
            .d => 8,
            .e => 9,
            .f => 8,
            .g => 7,
            .h => 6,
            .i => 5,
        };
    }
    pub fn offset(self: @This()) i8 {
        return switch (self) {
            .a => 0,
            .b => comptime (Row.a.size() + Row.a.offset()),
            .c => comptime (Row.b.size() + Row.b.offset()),
            .d => comptime (Row.c.size() + Row.c.offset()),
            .e => comptime (Row.d.size() + Row.d.offset()),
            .f => comptime (Row.e.size() + Row.e.offset()),
            .g => comptime (Row.f.size() + Row.f.offset()),
            .h => comptime (Row.g.size() + Row.g.offset()),
            .i => comptime (Row.h.size() + Row.h.offset()),
        };
    }
};

pub const Dir = enum {
    right,
    down_right,
    down_left,
    left,
    up_left,
    up_right,

    /// Compares the chain direction to the move_direction and computes whether the move will be inline or broadside
    pub fn move_type(self: @This(), move_direction: @This()) MoveType {
        switch (.{ self, move_direction }) {
            .{ .right, .right } |
                .{ .right, .left } |
                .{ .down_right, .down_right } |
                .{ .down_right, .up_left } |
                .{ .down_left, .up_right } |
                .{ .down_left, .up_right } => .Inline,
            else => .Broadside,
        }
    }
};

pub const Piece = struct {
    idx: i8,
    row: Row,

    /// Where in the array representation of the board is this piece
    pub fn board_index(self: @This()) i8 {
        return self.row.offset() + self.idx;
    }

    pub fn move_right(piece: @This()) ?Piece {
        piece.idx += 1;
        if (piece.idx >= piece.row.size()) return null else return piece;
    }

    pub fn move_left(piece: @This()) ?Piece {
        piece.idx -= 1;
        if (piece.idx <= 0) return null else return piece;
    }

    /// Moves the piece in the direction provided. If the piece goes out of bounds null is returned
    pub fn move(piece: @This(), d: Dir) ?Piece {
        switch (d) {
            .right => piece.move_right(),
            .left => piece.move_left(),
            // moving down incurs a
            .down_right => switch (piece.row) {
                .a | .b | .c | .d => {
                    // Coming from these rows, moving down right is always possible
                    piece.row = piece.row.next();
                    piece.idx += 1;
                    return piece;
                },
                .e | .f | .g | .h => {
                    piece.row = piece.row.next();
                    if (piece.idx >= piece.row.size()) return null else return piece;
                },
                // can't move down
                .i => return null,
            },
            .down_left => switch (piece.row) {
                .a | .b | .c | .d => {
                    // Coming from these rows, moving down left is always possible
                    piece.row = piece.row.next();
                    return piece;
                },
                .e | .f | .g | .h => {
                    // Coming from these rows we go out of bounds if we are at 0
                    if (piece.idx == 0) return null;
                    piece.row = piece.row.next();
                    piece.idx -= 1;
                    return piece;
                },
                // can't move down
                .i => return null,
            },
            .up_right => switch (piece.row) {
                // can't move up
                .a => return null,

                .b | .c | .d | .e => {
                    // Coming from these rows we go out of bounds if we are at the end of the row
                    piece.row = piece.row.prev();
                    if (piece.idx >= piece.row.size()) return null else return piece;
                },
                .f | .g | .h | .i => {
                    // Coming from these rows, moving up is always possible
                    piece.row = piece.row.prev();
                    return piece;
                },
            },
            .up_left => switch (piece.row) {
                // can't move up
                .a => return null,

                .b | .c | .d | .e => {
                    // Coming from these rows we go out of bounds if we are at the end of the row
                    if (piece.idx == 0) return null;
                    piece.row = piece.row.prev();
                    piece.idx -= 1;
                    return piece;
                },
                .f | .g | .h | .i => {
                    // Coming from these rows, moving up is always possible
                    piece.row = piece.row.prev();
                    piece.idx -= 1;
                    return piece;
                },
            },
        }
    }

    /// Returns the coordinates of the piece when we represent the board as a 2d grid
    ///
    ///   -8-7-6-5-4-3-2-10 1 2 3 4 5 6 7 8
    /// 4         ⏺   ⏺   ⏺   ⏺   ⏺
    /// 3       ⏺   ⏺   ⏺   ⏺   ⏺   ⏺
    /// 2     ⏺   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺
    /// 1   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺
    /// 0 ⏺   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺
    ///-1   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺
    ///-2     ⏺   ⏺   ⏺   ⏺   ⏺   ⏺   ⏺
    ///-3       ⏺   ⏺   ⏺   ⏺   ⏺   ⏺
    ///-4         ⏺   ⏺   ⏺   ⏺   ⏺
    pub fn coordinates(self: @This()) struct { i8, i8 } {
        // If the row is smaller than 9 we need to offset it by a bit
        const row_offset = 9 - self.row.size();

        const x, const y = .{ row_offset + (self.idx << 1), @intFromEnum(self.row) };

        // We need to center the coordinates on the center of the grid because it is easier to see what is going on in test cases
        const WIDTH_SHIFT = 8;
        const HEIGHT_SHIFT = 4;

        return .{ WIDTH_SHIFT - x, HEIGHT_SHIFT - y };
    }

    /// Returns the direction from self to other. Assumes that the pieces are hexagonally aligned and different
    pub fn dir(self: @This(), other: @This()) Dir {
        const x, const y = self.coordinates();
        const v, const w = other.coordinates();

        const dx = x - v;
        const dy = y - w;

        const signbit = comptime @bitSizeOf(i8) - 1;

        const vinfo = .{
            // gradient
            @divFloor(dy, dx),
            // whether the deltas are negative or not
            dx >> signbit,
            dy >> signbit,
        };

        switch (vinfo) {
            .{ 1, 1, 1 } => Dir.up_right,
            .{ 1, 0, 0 } => Dir.down_left,
            .{ 0, 1, 0 } => Dir.right,
            .{ 0, 0, 0 } => Dir.left,
            .{ -1, 0, 1 } => Dir.up_left,
            .{ -1, 1, 0 } => Dir.down_right,
            else => @panic("Two pieces are not hexagon-grid-aligned :/"),
        }
    }
};

pub const Chain = struct {
    len: u8,
    data: [3]Piece,

    pub inline fn head(self: *@This()) Piece {
        std.debug.assert(self.len < 4);
        return self.data[self.len - 1];
    }

    pub inline fn tail(self: *@This()) Piece {
        std.debug.assert(self.len > 0);
        return self.data[0];
    }
};

const MoveCreationError = error{ TooFewPieces, TooManyPieces };

/// Represents a move for any number of pieces
///
/// # Examples
///
/// `Move { todo }`
///
///     ⏺ ⏺ ⏺ ⏺ ⏺              ⏺ ⏺ ⏺ ⏺ ⏺
///    ⏺ ⏺ ⏺ ⏺ ⏺ ⏺            ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///   ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺          ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///  ⏺ ⏺ ⏺ ◯ ◯ ◯ ⏺ ⏺        ⏺ ⏺ ⏺ ⏺ ◯ ◯ ◯ ⏺
/// ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺  ->  ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///  ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺        ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///   ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺          ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///    ⏺ ⏺ ⏺ ⏺ ⏺ ⏺            ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///     ⏺ ⏺ ⏺ ⏺ ⏺              ⏺ ⏺ ⏺ ⏺ ⏺
///
/// `Move { todo }`
///
///     ⏺ ⏺ ⏺ ⏺ ⏺              ⏺ ⏺ ⏺ ⏺ ⏺
///    ⏺ ⏺ ⏺ ⏺ ⏺ ⏺            ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///   ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺          ⏺ ⏺ ◯ ◯ ◯ ⏺ ⏺
///  ⏺ ⏺ ⏺ ◯ ◯ ◯ ⏺ ⏺        ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
/// ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺  ->  ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///  ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺        ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///   ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺          ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///    ⏺ ⏺ ⏺ ⏺ ⏺ ⏺            ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
///     ⏺ ⏺ ⏺ ⏺ ⏺              ⏺ ⏺ ⏺ ⏺ ⏺
///
pub const Move = struct {
    move_type: MoveType,
    pieces: Chain,
    dir: Dir,

    pub fn new(pieces: []Piece, dir: Dir) MoveCreationError!@This() {

        // We need to sort the pieces in order according to the move direction

        switch (pieces.len) {
            0 => return error.TooFewPieces,
            1 => {
                return @This(){
                    .move_type = .Inline,
                    .pieces = .{ .len = 1, .data = .{pieces[0]} },
                    .dir = dir,
                };
            },
            2 => {
                const d01 = pieces[0].dir(pieces[1]);

                // We have to calculate the move type
                switch (d01.move_type(dir)) {
                    // We need to sort the pieces here as our board move function expects the chain to be sorted
                    .Inline => {
                        // If 0 -> 1 is the same direction as the move direction then we are all good
                        if (d01 == dir) {
                            return @This(){
                                .move_type = .Inline,
                                .pieces = .{ .len = 2, .data = .{ pieces[0], pieces[1] } },
                                .dir = dir,
                            };
                        } else { // otherwise we swap our pieces
                            return @This(){
                                .move_type = .Inline,
                                .pieces = .{ .len = 2, .data = .{ pieces[1], pieces[0] } },
                                .dir = dir,
                            };
                        }
                    },
                    // We don't need to sort the pieces here because broadside moves cant push
                    .Broadside => return @This(){
                        .move_type = .Broadside,
                        .pieces = .{ .len = 2, .data = .{ pieces[0], pieces[1] } },
                    },
                }
            },
            3 => {
                const d01 = pieces[0].dir(pieces[1]);
                const d02 = pieces[0].dir(pieces[2]);
                const d12 = pieces[1].dir(pieces[2]);

                // We have to calculate the move type
                switch (d01.move_type(dir)) {
                    // We need to sort the pieces here as our board move function expects the chain to be sorted
                    .Inline => {
                        // If 0 -> 1 is the same direction as the move direction then we are all good
                        var chain = Chain{ .len = 3, .pieces = undefined };

                        // Do some complicated sorting based on some stuff I wrote down
                        const flags = (@as(u3, @intFromBool(d01 == dir)) << 2) | (@as(u3, @intFromBool(d12 == dir)) << 1) | @as(u3, @intFromBool(d02 == dir));

                        switch (flags) {
                            // 012
                            0b111 => {
                                chain.data[0] = pieces[0];
                                chain.data[1] = pieces[1];
                                chain.data[2] = pieces[2];
                            },
                            // 021
                            0b101 => {
                                chain.data[0] = pieces[0];
                                chain.data[1] = pieces[2];
                                chain.data[2] = pieces[1];
                            },
                            // 210
                            0b000 => {
                                chain.data[0] = pieces[2];
                                chain.data[1] = pieces[1];
                                chain.data[2] = pieces[0];
                            },
                            // 201
                            0b010 => {
                                chain.data[0] = pieces[1];
                                chain.data[1] = pieces[2];
                                chain.data[2] = pieces[0];
                            },
                            // 120
                            0b100 => {
                                chain.data[0] = pieces[2];
                                chain.data[1] = pieces[0];
                                chain.data[2] = pieces[1];
                            },
                            // 102
                            0b011 => {
                                chain.data[0] = pieces[1];
                                chain.data[1] = pieces[0];
                                chain.data[2] = pieces[2];
                            },
                        }

                        return @This(){
                            .move_type = .Inline,
                            .pieces = pieces,
                            .dir = dir,
                        };
                    },
                    // We don't need to sort the pieces here because broadside moves cant push
                    .Broadside => return @This(){
                        .move_type = .Broadside,
                        .pieces = .{ .len = 2, .data = .{ pieces[0], pieces[1] } },
                        .dir = dir,
                    },
                }
            },
            else => return error.TooManyPieces,
        }
    }
};

const MoveError = error{
    /// There was a number of pieces in the way of the moving chain and we were unable to push it
    PathBlocked,
    /// A move landed one of our pieces out of bounds :(
    OutOfBounds,
    /// We cannot move a blank piece
    CannotMoveBlank,
};

pub const Board = struct {
    /// a     ⏺ ⏺ ⏺ ⏺ ⏺
    /// b    ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
    /// c   ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
    /// d  ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
    /// e ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
    /// f  ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
    /// g   ⏺ ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
    /// h    ⏺ ⏺ ⏺ ⏺ ⏺ ⏺
    /// i     ⏺ ⏺ ⏺ ⏺ ⏺
    pieces: [NUM_PIECES]?PieceColor,

    pub const NUM_PIECES = 61;

    pub fn get_row(self: *@This(), comptime row: Row) []?PieceColor {
        const size, const offset =
            switch (row) {
                .a => .{ 5, 0 },
                .b => .{ 6, 5 },
                .c => .{ 7, 5 + 6 },
                .d => .{ 8, 5 + 6 + 7 },
                .e => .{ 9, 5 + 6 + 7 + 8 },
                .f => .{ 8, 5 + 6 + 7 + 8 + 9 },
                .g => .{ 7, 5 + 6 + 7 + 8 + 9 + 8 },
                .h => .{ 6, 5 + 6 + 7 + 8 + 9 + 8 + 7 },
                .i => .{ 5, 5 + 6 + 7 + 8 + 9 + 8 + 7 + 6 },
            };

        return self.pieces[offset .. offset + size];
    }

    /// Performs the move. If a piece was displaced in the process then it is returned
    pub fn do_move(self: *@This(), move: *const Move) MoveError!?PieceColor {
        return switch (move.move_type) {
            .Broadside => self.do_broadside_move(self, move),
            .Inline => self.do_inline_move(self, move),
        };
    }

    /// Moves a chain broadside.
    ///
    /// # Errors
    /// - `error.PathBlocked`: Errors when we collide with a piece of any color.
    /// - `error.OutOfBounds`: Errors when we send a piece out of bounds
    pub fn do_broadside_move(self: *@This(), move: *const Move) MoveError!void {
        for (move.pieces) |piece| {
            const new_piece = piece.move(move.dir) orelse return error.OutOfBounds;

            const new_idx = @as(usize, new_piece.board_index());
            if (self.pieces[new_idx] != null) return error.PathBlocked;

            const old_idx = piece.board_index();
            self.pieces[new_idx] = self.pieces[old_idx];
            return;
        }
    }

    /// Moves a chain inline. Assumes that the chain is sorted such that `chain[i].dir(chain[j]) == move.dir` for
    /// for each `i < j`.
    ///
    /// # Errors
    /// `todo`
    pub fn do_inline_move(self: *@This(), move: *const Move) MoveError!?PieceColor {
        const old_head = move.pieces.head();
        const new_head = old_head.move(move.dir) orelse return error.OutOfBounds;

        // todo: should we pass this as a parameter
        const old_head_idx = old_head.board_index();
        const new_head_idx = new_head.board_index();

        const player_color = self.pieces[old_head_idx] orelse return error.CannotMoveBlank;

        if (self.pieces[new_head_idx]) |col| {
            // We cannot push our own piece

            _ = col;
            @panic("I still need to implement this. The idea is to cast a ray along the direction of travel from the head of length 4. if the array is less than length 4 then we end in void. Then we can just check all cases here and only some of them are allowed.");
        } else {
            // There are no pieces in the way. we just put our old piece at this location and return
            self.pieces[new_head_idx] = player_color;
            self.pieces[move.pieces.tail().board_index()] = null;
            return null;
        }
    }
};
