const sokol = @import("sokol");
const std = @import("std");
const sshape = sokol.shape;
const f32x4 = @Vector(4, f32);

inline fn sum(v: f32x4) f32 {
    return v[0] + v[1] + v[2] + v[3];
}

/// Column-wise 4x4 matrix
pub const Mat4 = extern struct {
    m: [4]f32x4,

    pub const identity = @This(){ .m = [_]f32x4{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    } };

    pub const zero = @This(){ .m = [_]f32x4{
        .{ 0.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.0 },
    } };

    pub fn vecmul(self: *const @This(), vec: anytype) @TypeOf(vec) {
        const V = @TypeOf(vec);
        const info = @typeInfo(V);
        if (info != .array) @compileError("Vector must be array type");
        if (@typeInfo(info.array.child) != .float) @compileError("Vector must be array of floating point values.");
        if (@typeInfo(info.array.child).float.bits != 32) @compileError("Vector must be array of f32 values.");

        switch (info.array.len) {
            0 => return vec,

            1 => {
                vec[0] *= self.m[0][0];
                return vec;
            },

            2 => {
                const v0 = @as(f32x4, @splat(vec[0])) * self.m[0];
                const v1 = @as(f32x4, @splat(vec[1])) * self.m[1];

                const out = v0 + v1;

                return V{ out[0], out[1] };
            },

            3 => {
                const v0 = @as(f32x4, @splat(vec[0])) * self.m[0];
                const v1 = @as(f32x4, @splat(vec[1])) * self.m[1];
                const v2 = @as(f32x4, @splat(vec[2])) * self.m[2];

                const out = v0 + v1 + v2;

                return V{ out[0], out[1], out[2] };
            },

            4 => {
                const v0 = @as(f32x4, @splat(vec[0])) * self.m[0];
                const v1 = @as(f32x4, @splat(vec[1])) * self.m[1];
                const v2 = @as(f32x4, @splat(vec[2])) * self.m[2];
                const v3 = @as(f32x4, @splat(vec[3])) * self.m[3];

                const out = v0 + v1 + v2 + v3;

                return @bitCast(out);
            },

            else => @compileError("Unsupported vector dimension"),
        }
    }

    /// https://en.wikipedia.org/wiki/Invertible_matrix#Inversion_of_4_%C3%97_4_matrices
    pub fn inverse(self: *const @This()) Mat4 {
        var a2 = self.mul(self);
        const a3 = a2.mul(self);

        const a1tr = self.trace();
        const a1tr2 = a1tr * a1tr;
        const a2tr = a2.trace();
        const a3tr = a3.trace();
        const a4tr = sum(
            a2.row(0) * a2.col(0) +
                a2.row(1) * a2.col(1) +
                a2.row(2) * a2.col(2) +
                a2.row(3) * a2.col(3),
        );

        const one_over_det = 24 / ((a1tr2 * a1tr2) - 6 * a2tr * a1tr2 + 3 * a2tr * a2tr + 8 * a3tr * a1tr - 6 * a4tr);

        a2.scalar_mul_eq(a1tr);

        var out = Mat4.diag((a1tr * (a1tr2 - 3 * a2tr) + 2 * a3tr) / 6)
            .add(&self.scalar_mul(0.5 * (a2tr - a1tr2)))
            .add(&a2)
            .sub(&a3);

        out.scalar_mul_eq(one_over_det);

        return out;
    }

    pub inline fn row(self: *const @This(), v: u2) f32x4 {
        return f32x4{ self.m[0][v], self.m[1][v], self.m[2][v], self.m[3][v] };
    }

    pub inline fn col(self: *const @This(), v: u2) f32x4 {
        return self.m[v];
    }

    /// https://en.wikipedia.org/wiki/Determinant#Trace
    pub fn det(self: *const @This()) f32 {
        const a2 = self.mul(self);
        const a3 = a2.mul(self);
        const a4 = a3.mul(self);

        const a2tr = a2.trace();
        const tr = self.trace();
        const tr2 = tr * tr;
        const a3tr = a3.trace();
        const a4tr = a4.trace();

        return ((tr2 * tr2) - 6 * a2tr * tr2 + 3 * a2tr * a2tr + 8 * a3tr * tr - 6 * a4tr) / 24;
    }

    /// https://en.wikipedia.org/wiki/Determinant#Trace
    pub fn diag(v: f32) Mat4 {
        return Mat4{ .m = [_]f32x4{
            .{ v, 0, 0, 0 },
            .{ 0, v, 0, 0 },
            .{ 0, 0, v, 0 },
            .{ 0, 0, 0, v },
        } };
    }

    pub fn trace(self: *const @This()) f32 {
        return self.m[0][0] + self.m[1][1] + self.m[2][2] + self.m[3][3];
    }

    pub fn mul(self: *const @This(), right: *const Mat4) Mat4 {
        var out: Mat4 = undefined;

        // for each column of b
        for (0..4) |i| {
            const bx: f32x4 = @splat(self.m[i][0]);
            const by: f32x4 = @splat(self.m[i][1]);
            const bz: f32x4 = @splat(self.m[i][2]);
            const bw: f32x4 = @splat(self.m[i][3]);

            out.m[i] =
                right.m[0] * bx +
                right.m[1] * by +
                right.m[2] * bz +
                right.m[3] * bw;
        }

        return out;
    }

    pub fn scalar_mul(self: *const @This(), v: f32) Mat4 {
        var out: Mat4 = self.*;
        inline for (&out.m) |*c| c.* *= @splat(v);
        return out;
    }

    pub fn scalar_mul_eq(self: *@This(), v: f32) void {
        inline for (&self.m) |*c| c.* *= @splat(v);
    }

    pub fn sub(self: *const @This(), other: *const @This()) Mat4 {
        var out: Mat4 = self.*;
        inline for (&out.m, other.m) |*c, other_col| {
            c.* -= other_col;
        }
        return out;
    }

    pub fn add(self: *const @This(), other: *const @This()) Mat4 {
        var out: Mat4 = self.*;
        inline for (&out.m, other.m) |*c, other_col| {
            c.* += other_col;
        }
        return out;
    }

    pub fn persp(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
        var res = Mat4.identity;
        const t = std.math.tan(fov * (std.math.pi / 360.0));
        res.m[0][0] = 1.0 / t;
        res.m[1][1] = aspect / t;
        res.m[2][3] = -1.0;
        res.m[2][2] = (near + far) / (near - far);
        res.m[3][2] = (2.0 * near * far) / (near - far);
        res.m[3][3] = 0.0;
        return res;
    }

    pub fn lookat(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        var res = Mat4.zero;

        const f = Vec3.norm(Vec3.sub(center, eye));
        const s = Vec3.norm(Vec3.cross(f, up));
        const u = Vec3.cross(s, f);

        res.m[0][0] = s.x;
        res.m[0][1] = u.x;
        res.m[0][2] = -f.x;

        res.m[1][0] = s.y;
        res.m[1][1] = u.y;
        res.m[1][2] = -f.y;

        res.m[2][0] = s.z;
        res.m[2][1] = u.z;
        res.m[2][2] = -f.z;

        res.m[3][0] = -Vec3.dot(s, eye);
        res.m[3][1] = -Vec3.dot(u, eye);
        res.m[3][2] = Vec3.dot(f, eye);
        res.m[3][3] = 1.0;

        return res;
    }

    pub fn rotate(angle: f32, axis_unorm: Vec3) Mat4 {
        var res = Mat4.identity;

        const axis = Vec3.norm(axis_unorm);
        const sin_theta = std.math.sin(std.math.degreesToRadians(angle));
        const cos_theta = std.math.cos(std.math.degreesToRadians(angle));
        const cos_value = 1.0 - cos_theta;

        res.m[0][0] = (axis.x * axis.x * cos_value) + cos_theta;
        res.m[0][1] = (axis.x * axis.y * cos_value) + (axis.z * sin_theta);
        res.m[0][2] = (axis.x * axis.z * cos_value) - (axis.y * sin_theta);
        res.m[1][0] = (axis.y * axis.x * cos_value) - (axis.z * sin_theta);
        res.m[1][1] = (axis.y * axis.y * cos_value) + cos_theta;
        res.m[1][2] = (axis.y * axis.z * cos_value) + (axis.x * sin_theta);
        res.m[2][0] = (axis.z * axis.x * cos_value) + (axis.y * sin_theta);
        res.m[2][1] = (axis.z * axis.y * cos_value) - (axis.x * sin_theta);
        res.m[2][2] = (axis.z * axis.z * cos_value) + cos_theta;

        return res;
    }

    pub fn translate(translation: Vec3) Mat4 {
        var res = Mat4.identity;
        res.m[3][0] = translation.x;
        res.m[3][1] = translation.y;
        res.m[3][2] = translation.z;
        return res;
    }
};

pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn zero() Vec3 {
        return Vec3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn up() Vec3 {
        return Vec3{ .x = 0.0, .y = 1.0, .z = 0.0 };
    }

    pub fn len(v: Vec3) f32 {
        return std.math.sqrt(Vec3.dot(v, v));
    }

    pub fn add(left: Vec3, right: Vec3) Vec3 {
        return Vec3{ .x = left.x + right.x, .y = left.y + right.y, .z = left.z + right.z };
    }

    pub fn sub(left: Vec3, right: Vec3) Vec3 {
        return Vec3{ .x = left.x - right.x, .y = left.y - right.y, .z = left.z - right.z };
    }

    pub fn mul(v: Vec3, s: f32) Vec3 {
        return Vec3{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn norm(v: Vec3) Vec3 {
        const l = Vec3.len(v);
        if (l != 0.0) {
            return Vec3{ .x = v.x / l, .y = v.y / l, .z = v.z / l };
        } else {
            return Vec3.zero();
        }
    }

    pub fn cross(v0: Vec3, v1: Vec3) Vec3 {
        return Vec3{ .x = (v0.y * v1.z) - (v0.z * v1.y), .y = (v0.z * v1.x) - (v0.x * v1.z), .z = (v0.x * v1.y) - (v0.y * v1.x) };
    }

    pub fn dot(v0: Vec3, v1: Vec3) f32 {
        return v0.x * v1.x + v0.y * v1.y + v0.z * v1.z;
    }
};
