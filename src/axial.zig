const std = @import("std");
const root3 = @sqrt(3.0);

pub const Alignment = enum { pos, neg };

pub const AxialVector = packed struct {
    q: i16,
    r: i16,

    pub const zero = @This(){ .q = 0, .r = 0 };

    /// Max value (in absolute terms) for each q, r ,s coordinate
    pub const bound = 4;
    pub const radius = 1.0 / (2.0 * bound + 1);

    /// Converts the axial coordinate to pixel coordinates in pointy configuration.
    ///
    /// The `radius` parameter is the radius of the maximal circle inscribed in the hexagon.
    ///
    /// [https://www.redblobgames.com/grids/hexagons/#pixel-to-hex]
    pub inline fn to_pixel_vec(self: @This()) [2]f32 {
        const q = @as(f32, @floatFromInt(self.q));
        const r = @as(f32, @floatFromInt(self.r));

        return .{ radius * root3 * (q + r * 0.5), radius * 1.5 * r };
    }

    /// https://en.wikipedia.org/wiki/Centered_hexagonal_number#Formula
    fn num_hexagons() usize {
        return 3 * bound * (bound + 1) + 1;
    }

    pub fn compute_hexagons() [num_hexagons()][2]f32 {
        // https://en.wikipedia.org/wiki/Centered_hexagonal_number#Formula
        var hexagons: [num_hexagons()][2]f32 = undefined;
        var idx = 0;

        var q: i16 = -bound;
        while (q <= bound) : (q += 1) {
            // |s| (= |q+r|) < bound
            var r: i16 = @max(-q - bound, -bound);
            const end = @min(-q + bound, bound);
            while (r <= end) : (r += 1) {
                hexagons[idx] = (AxialVector{ .q = q, .r = r }).to_pixel_vec();
                idx += 1;
            }
        }

        const zero_idx = fdzero: {
            for (hexagons, 0..) |hex, i| {
                if (hex[0] == 0.0 and hex[1] == 0.0) break :fdzero i;
            }
            unreachable;
        };

        std.mem.swap([2]f32, &hexagons[0], &hexagons[zero_idx]);

        return hexagons;
    }

    /// Converts the NDC vector to an axial vector
    ///
    /// The `radius` parameter is the radius of the maximal circle inscribed in the hexagon.
    ///
    /// [https://www.redblobgames.com/grids/hexagons/#pixel-to-hex]
    pub fn from_pixel_vec(x: f32, y: f32) @This() {
        const q = (root3 * x - y) / (radius * 3.0);
        const r = (2.0 * y) / (radius * 3.0);

        return .{
            .q = @intFromFloat(@round(q)),
            .r = @intFromFloat(@round(r)),
        };
    }

    /// Converts the screen space vector to an axial vector
    ///
    /// The `radius` parameter is the radius of the maximal circle inscribed in the hexagon.
    ///
    /// [https://www.redblobgames.com/grids/hexagons/#pixel-to-hex]
    pub inline fn from_pixel_vec_screen_space(x: f32, y: f32, screen_width: f32, screen_height: f32) @This() {
        return @This().from_pixel_vec(
            2.0 * (x / screen_width) - 1,
            2.0 * (y / screen_height) - 1,
        );
    }

    /// Returns all neighbours who are in bounds
    pub fn neighbours(self: @This()) [6]@This() {
        const Direction = @import("move.zig").HexagonalDirection;
        const num_dirs = @typeInfo(Direction).@"enum".fields.len;

        comptime {
            if (num_dirs > 6) @compileError("Too many directions");
        }

        var ngbrs: [6]@This() = undefined;

        inline for (0..num_dirs) |idx| {
            const dir: Direction = @enumFromInt(idx);
            ngbrs[idx] = self.add(dir.to_axial_vector());
        }

        return ngbrs;
    }

    /// Computes the Manhatten distance.
    pub inline fn dist(self: @This(), other: @This()) u16 {
        return self.sub(other).size();
    }

    pub inline fn size(self: @This()) u16 {
        return (@abs(self.q) + @abs(self.q + self.r) + @abs(self.r)) >> 1;
    }

    pub inline fn neg(self: @This()) @This() {
        return @This(){ .q = -self.q, .r = -self.r };
    }

    pub inline fn mul(self: @This(), by: i16) @This() {
        return @This(){ .q = by * self.q, .r = by * self.r };
    }

    pub inline fn s(self: @This()) i16 {
        return -self.q - self.r;
    }

    pub inline fn sub(self: @This(), other: @This()) @This() {
        return self.add(other.neg());
    }

    pub inline fn parallel(self: @This(), other: @This()) bool {
        return self.q * other.r == self.r * other.q;
    }

    /// Checks that the vectors are parallel and whether they are in the same quadrant
    ///
    /// `pos`  : The vectors face the same direction.
    /// `neg`  : The vectors face opposite directions.
    /// `null` : Not parallel
    pub inline fn alignment(self: @This(), other: @This()) ?Alignment {
        if (!self.parallel(other)) return null;
        if (self == zero or other == zero) return .pos;

        // By xoring the sign bit we get whether they have the same or different signs
        //
        // 0 for different
        const qalign = @intFromBool(self.q < 0) ^ @intFromBool(other.q < 0);
        const ralign = @intFromBool(self.r < 0) ^ @intFromBool(other.r < 0);

        const a = (@as(u2, qalign) << 1) | @as(u2, ralign);
        return switch (a) {
            // q neg and r neg
            0b00 => .pos,
            // q neg and r pos
            0b01 => .neg,
            // q pos and r neg
            0b10 => .neg,
            // q pos and r pos
            0b11 => .neg,
        };
    }

    pub inline fn add(self: @This(), other: @This()) @This() {
        return @This(){ .q = self.q + other.q, .r = self.r + other.r };
    }

    pub inline fn out_of_bounds(self: @This()) bool {
        return @abs(self.q) > bound or @abs(self.r) > bound or @abs(self.s()) > bound;
    }

    // Returns self when in bounds, otherwise null
    pub inline fn if_in_bounds(self: @This()) ?@This() {
        if (self.out_of_bounds()) return null else return self;
    }

    /// The type which provides the AxialPoint Hasher
    pub fn Hasher() type {
        return struct {
            pub inline fn hash(self: @This(), pt: AxialVector) u32 {
                _ = self;
                return (@as(u32, pt.q) << 8) | @as(u32, pt.r);
            }

            pub inline fn eql(self: @This(), pt1: AxialVector, pt2: AxialVector, idx: usize) bool {
                _ = self;
                _ = idx;
                return pt1.q == pt2.q and pt1.r == pt2.r;
            }
        };
    }
};

test "axial-parallel" {
    const bound = 10;
    var q: i16 = -bound;
    while (q <= bound) : (q += 1) {
        var r: i16 = -bound;
        while (r <= bound) : (r += 1) {
            var mul: i16 = -128;
            while (mul <= 128) : (mul += 1) {
                const axial_vec = AxialVector{ .q = @intCast(q), .r = @intCast(r) };
                std.debug.assert(axial_vec.mul(mul).parallel(axial_vec));
            }
        }
    }
}

test "axial-alignment" {
    const bound = 10;
    var q: i16 = -bound;
    while (q <= bound) : (q += 1) {
        var r: i16 = -bound;
        while (r <= bound) : (r += 1) {
            var mul: i16 = -128;
            while (mul < 128) : (mul += 1) {
                const axial_vec = AxialVector{ .q = @intCast(q), .r = @intCast(r) };
                if (axial_vec == AxialVector.zero) continue;

                const expected: Alignment = if (mul >= 0) .pos else .neg;
                std.debug.assert(axial_vec.mul(mul).parallel(axial_vec));
                const alignment = axial_vec.mul(mul).alignment(axial_vec);

                std.debug.print(
                    "mul: {any} | self: {any} | other: {any} | expected: {any} | got {any}\n",
                    .{ mul, axial_vec.mul(mul), axial_vec, expected, alignment },
                );

                std.debug.assert(alignment == expected);
            }
        }
    }
}
