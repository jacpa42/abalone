pub const AxialPoint = packed struct {
    q: i4,
    r: i4,

    pub inline fn s(self: @This()) i4 {
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
            pub inline fn hash(self: @This(), pt: AxialPoint) u32 {
                _ = self;
                return (@as(u32, pt.q) << 4) | @as(u32, pt.r);
            }

            pub inline fn eql(self: @This(), pt1: AxialPoint, pt2: AxialPoint, idx: usize) bool {
                _ = self;
                _ = idx;
                return pt1.q == pt2.q and pt1.r == pt2.r;
            }
        };
    }
};
