const std = @import("std");
const sdl3 = @import("sdl3");
const geometry = @import("state/geometry.zig");

const AxialVector = @import("axial.zig").AxialVector;
const Move = @import("move.zig").Move;
const Vertex = sdl3.render.Vertex;
const Window = sdl3.video.Window;
const Renderer = sdl3.render.Renderer;
const Point = sdl3.rect.FPoint;

pub const Array = struct {
    /// The grid positions of each marble.
    data: [CAPACITY]AxialVector,
    /// The number of marbles left
    len: usize,

    pub const black = black_start();
    pub const white = white_start();

    pub const CAPACITY = 14;

    pub fn const_slice(self: *const @This()) []const AxialVector {
        return self.data[0..self.len];
    }

    pub fn slice(self: *@This()) []AxialVector {
        return self.data[0..self.len];
    }

    fn black_start() @This() {
        const bound = 4;
        var array = @This(){ .data = undefined, .len = 0 };

        var r = bound;
        while (r >= bound - 1) : (r -= 1) {
            var q = @max(-bound, -bound - r);
            const end = @min(bound, bound - r);

            while (q <= end) : (q += 1) {
                std.debug.assert(array.len <= CAPACITY);

                array.data[array.len] = AxialVector{ .q = q, .r = r };
                array.len += 1;
            }
        }

        r = bound - 2;
        var q = 0;
        while (q >= -2) : (q -= 1) {
            array.data[array.len] = AxialVector{ .q = q, .r = r };
            array.len += 1;
        }

        return array;
    }

    fn white_start() @This() {
        const bound = 4;
        var array = @This(){ .data = undefined, .len = 0 };

        var r = -bound;
        while (r <= -bound + 1) : (r += 1) {
            var q = @max(-bound, -bound - r);
            const end = @min(bound, bound - r);
            while (q <= end) : (q += 1) {
                std.debug.assert(array.len <= CAPACITY);

                array.data[array.len] = AxialVector{ .q = q, .r = r };
                array.len += 1;
            }
        }

        r = -bound + 2;
        var q = 0;
        while (q <= 2) : (q += 1) {
            array.data[array.len] = AxialVector{ .q = q, .r = r };
            array.len += 1;
        }

        return array;
    }
};

pub const Player = struct {
    score: u3 = 0,
    marbles: Array,
};

pub const State = struct {
    /// This represents our playable surface. It is a |q| <= 4, |r| <= 4, |s| <= 4.
    p1: Player,
    p2: Player,
    turn: enum(u1) { p1, p2 },

    pub fn new() @This() {
        return @This(){
            .p1 = Player{ .marbles = .white },
            .p2 = Player{ .marbles = .black },
            .turn = .p1,
        };
    }

    pub fn render(
        self: *const @This(),
        screen_width: f32,
        screen_height: f32,
        renderer: *const Renderer,
    ) !void {
        const bound: i8 = 4;
        const size = 0.11;
        const default_hexagon = geometry.Hexagon{};

        // Render background tiles
        var q = -bound;
        while (q <= bound) : (q += 1) {
            var r = @max(-bound, -bound - q);
            const end = @min(bound, bound - q);
            while (r <= end) : (r += 1) {
                const x, const y = (AxialVector{ .q = q, .r = r }).to_pixel_vec(size);

                var hexagon = default_hexagon;

                hexagon.scale(size * 0.95);
                hexagon.color(geometry.purple);
                hexagon.render_transform(.{ .x = x, .y = y }, screen_width, screen_height);

                try renderer.renderGeometry(null, &hexagon.vertices, &geometry.Hexagon.indicies);
            }
        }

        const default_circle = geometry.Circle{};
        const ball_scale = 0.65;

        for (self.p1.marbles.const_slice()) |marble| {
            const x, const y = marble.to_pixel_vec(size);

            var circle = default_circle;

            circle.scale(size * ball_scale);
            circle.color(geometry.white);
            circle.render_transform(.{ .x = x, .y = y }, screen_width, screen_height);

            try renderer.renderGeometry(null, &circle.vertices, &geometry.Circle.indicies);
        }

        for (self.p2.marbles.const_slice()) |marble| {
            const x, const y = marble.to_pixel_vec(size);

            var circle = default_circle;

            circle.scale(size * ball_scale);
            circle.color(geometry.black);
            circle.render_transform(.{ .x = x, .y = y }, screen_width, screen_height);

            try renderer.renderGeometry(null, &circle.vertices, &geometry.Circle.indicies);
        }
    }
};
