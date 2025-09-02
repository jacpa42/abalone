pub const AxialVector = packed struct {
    q: i8,
    r: i8,

    /// Converts the axial coordinate to pixel coordinates in pointy configuration.
    ///
    /// The `radius` parameter is the radius of the maximal circle inscribed in the hexagon.
    ///
    /// [https://www.redblobgames.com/grids/hexagons/#pixel-to-hex]
    pub fn to_pixel_vec(self: @This(), radius: f32) struct { f32, f32 } {
        const q = @as(f32, @floatFromInt(self.q));
        const r = @as(f32, @floatFromInt(self.r));
        const root3 = comptime @sqrt(3.0);

        return .{ radius * root3 * (q + r * 0.5), radius * 1.5 * r };
    }

    /// Computes the Manhatten distance.
    pub inline fn dist(self: @This(), other: @This()) i8 {
        return self.sub(other).size();
    }

    pub inline fn size(self: @This()) i8 {
        return (@abs(self.q) + @abs(self.q + self.r) + @abs(self.r)) >> 1;
    }

    pub inline fn s(self: @This()) i8 {
        return -self.q - self.r;
    }

    pub inline fn sub(self: @This(), other: @This()) @This() {
        return @This(){ .q = self.q - other.q, .r = self.r - other.r };
    }

    pub inline fn add(self: @This(), other: @This()) @This() {
        return @This(){ .q = self.q + other.q, .r = self.r + other.r };
    }

    pub inline fn out_of_bounds(self: @This()) bool {
        return @abs(self.q) > 4 or @abs(self.r) > 4 or @abs(self.s()) > 4;
    }

    /// The type which provides the AxialPoint Hasher
    pub fn Hasher() type {
        return struct {
            pub inline fn hash(self: @This(), pt: AxialVector) u32 {
                _ = self;
                return (@as(u32, pt.q) << 4) | @as(u32, pt.r);
            }

            pub inline fn eql(self: @This(), pt1: AxialVector, pt2: AxialVector, idx: usize) bool {
                _ = self;
                _ = idx;
                return pt1.q == pt2.q and pt1.r == pt2.r;
            }
        };
    }
};
