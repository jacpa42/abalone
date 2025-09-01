pub const AxialVector = packed struct {
    q: i8,
    r: i8,

    /// Converts the axial coordinate to pixel coordinates in pointy configuration
    ///
    /// [https://www.redblobgames.com/grids/hexagons/#pixel-to-hex]
    pub fn to_pixel_vec(self: @This()) struct { f32, f32 } {
        const qr_vec = .{ @as(f32, @floatFromInt(self.q)), @as(f32, @floatFromInt(self.r)) };

        return .{
            @sqrt(3.0) * (qr_vec.@"0" + qr_vec.@"1" * 0.5),
            qr_vec.@"0" * 1.5,
        };
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

pub fn Vec2(comptime T: anytype) type {
    return struct {
        x: T,
        y: T,

        pub const zero: @This() = .{ .x = 0, .y = 0 };

        /// Distance squared to other `Vec(T)`
        pub inline fn dist_square(self: @This(), other: @This()) T {
            const diff = self.sub(other);
            return diff.dot(diff);
        }

        /// Distance squared to other `Vec(T)`
        pub inline fn dist(self: @This(), other: @This()) T {
            return @sqrt(self.dist_square(other));
        }

        /// bitwise right shift
        pub inline fn shr(self: @This(), amount: comptime_int) @This() {
            return .{ .x = self.x >> amount, .y = self.y >> amount };
        }

        pub inline fn float(self: @This(), comptime F: type) Vec2(F) {
            return .{ .x = @floatFromInt(self.x), .y = @floatFromInt(self.y) };
        }

        pub inline fn int(self: @This(), comptime I: type) Vec2(I) {
            return .{ .x = @intFromFloat(self.x), .y = @intFromFloat(self.y) };
        }

        pub inline fn norm(self: @This()) @This() {
            return self.div(@sqrt(self.dot(self)));
        }

        pub inline fn mul(self: @This(), other: T) @This() {
            return .{ .x = self.x * other, .y = self.y * other };
        }

        pub inline fn div(self: @This(), other: T) @This() {
            return .{ .x = self.x / other, .y = self.y / other };
        }

        pub inline fn sub(self: @This(), other: @This()) @This() {
            return .{ .x = self.x - other.x, .y = self.y - other.y };
        }

        pub inline fn add(self: @This(), other: @This()) @This() {
            return .{ .x = self.x + other.x, .y = self.y + other.y };
        }

        pub inline fn dot(self: @This(), other: @This()) T {
            return self.x * other.x + self.y * other.y;
        }
    };
}
