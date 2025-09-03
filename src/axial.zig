const root3 = @sqrt(3.0);

pub const AxialVector = packed struct {
    q: i8,
    r: i8,

    /// Max value (in absolute terms) for each q, r ,s coordinate
    pub const bound = 4;
    pub const radius = 1.0 / (2.0 * bound + 1);

    /// Converts the axial coordinate to pixel coordinates in pointy configuration.
    ///
    /// The `radius` parameter is the radius of the maximal circle inscribed in the hexagon.
    ///
    /// [https://www.redblobgames.com/grids/hexagons/#pixel-to-hex]
    pub inline fn to_pixel_vec(self: @This()) struct { f32, f32 } {
        const q = @as(f32, @floatFromInt(self.q));
        const r = @as(f32, @floatFromInt(self.r));

        return .{ radius * root3 * (q + r * 0.5), radius * 1.5 * r };
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
    pub fn from_pixel_vec_screen_space(x: f32, y: f32, screen_width: f32, screen_height: f32) @This() {
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
    pub inline fn dist(self: @This(), other: @This()) u8 {
        return self.sub(other).size();
    }

    pub inline fn size(self: @This()) u8 {
        return (@abs(self.q) + @abs(self.q + self.r) + @abs(self.r)) >> 1;
    }

    pub inline fn neg(self: @This()) @This() {
        return @This(){ .q = -self.q, .r = -self.r };
    }

    pub inline fn s(self: @This()) i8 {
        return -self.q - self.r;
    }

    pub inline fn sub(self: @This(), other: @This()) @This() {
        return self.add(other.neg());
    }

    pub inline fn parallel(self: @This(), other: @This()) bool {
        return self.q * other.r == self.r * other.q;
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
