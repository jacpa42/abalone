const std = @import("std");
const AxialVector = @import("axial.zig").AxialVector;

pub const black = black_start();
pub const white = white_start();

pub fn PointArray(comptime max_cap: usize) type {
    return struct {
        /// The grid positions of each marble.
        items: [CAPACITY]AxialVector,
        /// The number of marbles left
        len: usize,

        pub const empty = @This(){ .items = undefined, .len = 0 };

        pub const CAPACITY = max_cap;

        pub fn contains(self: *const @This(), item: AxialVector) bool {
            for (self.const_slice()) |point| {
                if (item == point) return true;
            }
            return false;
        }

        pub fn find(self: *const @This(), item: AxialVector) ?usize {
            for (self.const_slice(), 0..) |point, i| {
                if (item == point) return i;
            }
            return null;
        }

        pub fn try_append(self: *@This(), item: AxialVector) error{OutOfMemory}!void {
            if (self.len == CAPACITY) return error.OutOfMemory;
            self.items[self.len] = item;
            self.len += 1;
            return;
        }

        pub fn append(self: *@This(), item: AxialVector) void {
            std.debug.assert(self.len < CAPACITY);
            self.items[self.len] = item;
            self.len += 1;
            return;
        }

        pub fn const_slice(self: *const @This()) []const AxialVector {
            return self.items[0..self.len];
        }

        pub fn slice(self: *@This()) []AxialVector {
            return self.items[0..self.len];
        }

        pub fn swap_remove(self: *@This(), idx: usize) void {
            std.debug.assert(idx < self.len);
            self.len -= 1;
            self.items[idx] = self.items[self.len];
        }
    };
}

const Array = PointArray(14);
fn black_start() Array {
    const bound = 4;
    var array = Array{ .items = undefined, .len = 0 };

    var r = bound;
    while (r >= bound - 1) : (r -= 1) {
        var q = @max(-bound, -bound - r);
        const end = @min(bound, bound - r);

        while (q <= end) : (q += 1) {
            array.items[array.len] = AxialVector{ .q = q, .r = r };
            array.len += 1;
        }
    }

    r = bound - 2;
    var q = 0;
    while (q >= -2) : (q -= 1) {
        array.items[array.len] = AxialVector{ .q = q, .r = r };
        array.len += 1;
    }

    return array;
}

fn white_start() Array {
    const bound = 4;
    var array = Array{ .items = undefined, .len = 0 };

    var r = -bound;
    while (r <= -bound + 1) : (r += 1) {
        var q = @max(-bound, -bound - r);
        const end = @min(bound, bound - r);
        while (q <= end) : (q += 1) {
            array.items[array.len] = AxialVector{ .q = q, .r = r };
            array.len += 1;
        }
    }

    r = -bound + 2;
    var q = 0;
    while (q <= 2) : (q += 1) {
        array.items[array.len] = AxialVector{ .q = q, .r = r };
        array.len += 1;
    }

    return array;
}
