const std = @import("std");
const sdl3 = @import("sdl3");
const geometry = @import("state/geometry.zig");
const pt_array = @import("point_array.zig");

const AxialVector = @import("axial.zig").AxialVector;
const Move = @import("move.zig").Move;

const Marbles = pt_array.PointArray(14);

/// Basically a cyclical array of ball indicies for the current player
const SelectedBalls = struct {
    items: [3]AxialVector = undefined,
    len: usize = 0,

    pub fn const_slice(self: *const @This()) []const AxialVector {
        return self.items[0..self.len];
    }

    /// Trys to insert the item into the back of `items`
    pub fn try_insert(self: *@This(), item: AxialVector) error{OutOfMemory}!void {
        if (self.len == self.items.len) return error.OutOfMemory;

        self.items[self.len] = item;
        self.len += 1;
    }

    /// Checks that the `pt` is:
    ///
    /// - Not one of the already selected balls
    /// - 1 distance away from 1 of the balls
    pub fn is_neighbour(self: *const @This(), pt: AxialVector) bool {
        if (self.len == 0) return true;
        for (self.const_slice()) |ball| if (ball == pt) return false;
        for (self.const_slice()) |ball| if (ball.dist(pt) == 1) return true;

        return false;
    }

    pub inline fn find(self: *const @This(), pos: AxialVector) ?usize {
        for (self.const_slice(), 0..) |selected, idx| {
            if (selected == pos) return idx;
        }
        return null;
    }

    pub inline fn swap_remove(self: *@This(), idx: usize) void {
        std.debug.print("idx = {}\n", .{idx});
        std.debug.assert(idx < self.len);
        self.len -= 1;
        self.items[idx] = self.items[self.len];
    }
};

pub const Player = struct {
    score: u3 = 0,
    marbles: Marbles,
};

pub const State = struct {
    /// This represents our playable surface. It is a |q| <= 4, |r| <= 4, |s| <= 4.
    p1: Player = .{ .marbles = pt_array.white },
    p2: Player = .{ .marbles = pt_array.black },
    moused_over: ?AxialVector = null,
    selected_balls: SelectedBalls = SelectedBalls{},
    turn: enum(u1) { p1, p2 } = .p1,

    /// Will try to pick the ball. If the ball is not the correct color or there is no ball there it will shit the bed.
    ///
    /// - All balls must be in bounds.
    /// - All balls must be neighbours.
    /// - All balls need to match the player color.
    /// - All balls need to be in a straight line.
    pub fn try_pick_ball(self: *@This(), at: AxialVector) error{OutOfMemory}!void {
        std.debug.print("at = {any}", .{at});

        const selected = &self.selected_balls;

        // Check that the ball is in bounds
        if (at.out_of_bounds()) return;

        if (selected.find(at)) |idx| {
            selected.swap_remove(idx);
            return;
        }

        // Check that the ball is a neighbour
        if (!selected.is_neighbour(at)) return;

        // Check that the balls are the same color
        const same_color = switch (self.turn) {
            .p1 => self.p1.marbles.contains(at),
            .p2 => self.p2.marbles.contains(at),
        };
        if (!same_color) return;

        // If we have 2 balls then we need to check alignment of the third
        if (selected.len == 2) {
            // 0 -> p vec
            const vec0p = at.sub(selected.items[0]);
            // 1 -> p vec
            const vec1p = at.sub(selected.items[1]);
            // These must be parallel
            if (!vec0p.parallel(vec1p)) return;
        }

        try self.selected_balls.try_insert(at);
    }

    pub fn render_background_hexagons(
        self: *const @This(),
        renderer: *const sdl3.render.Renderer,
        screen_factor: f32,
    ) !void {
        const hexagon_scale = 0.95;

        var background_hexagon = geometry.Hexagon{};
        background_hexagon.color(geometry.purple);
        background_hexagon.scale(hexagon_scale);

        // Render background tiles
        const bound = AxialVector.bound;
        var q: i8 = -bound;
        while (q <= bound) : (q += 1) {
            var r = @max(-bound, -bound - q);
            const end = @min(bound, bound - q);
            while (r <= end) : (r += 1) {
                const x, const y = (AxialVector{ .q = q, .r = r }).to_pixel_vec();

                var hexagon = background_hexagon;

                hexagon.shift(x + 1, y + 1);
                hexagon.scale(screen_factor);

                try renderer.renderGeometry(null, &hexagon.vertices, &geometry.Hexagon.indicies);
            }
        }

        // Render moused over balls
        if (self.moused_over) |hex| {
            const x, const y = hex.to_pixel_vec();

            background_hexagon.color(geometry.red);
            background_hexagon.shift(x + 1, y + 1);
            background_hexagon.scale(screen_factor);

            try renderer.renderGeometry(null, &background_hexagon.vertices, &geometry.Hexagon.indicies);
        }
    }

    pub fn render_circles(
        renderer: *const sdl3.render.Renderer,
        circles: []const AxialVector,
        screen_factor: f32,
        color: geometry.Color,
    ) !void {
        const ball_scale = 0.65;

        var default_circle = geometry.Circle{};
        default_circle.color(color);
        default_circle.scale(ball_scale);

        for (circles) |marble| {
            const x, const y = marble.to_pixel_vec();

            var circle = default_circle;

            circle.shift(x + 1, y + 1);
            circle.scale(screen_factor);

            try renderer.renderGeometry(null, &circle.vertices, &geometry.Circle.indicies);
        }
    }

    pub fn render(
        self: *const @This(),
        renderer: *const sdl3.render.Renderer,
        screen_width: f32,
        screen_height: f32,
    ) !void {
        const screen_factor = @min(screen_width, screen_height) * 0.5;

        // background
        try self.render_background_hexagons(renderer, screen_factor);

        // p1
        try State.render_circles(
            renderer,
            self.p1.marbles.const_slice(),
            screen_factor,
            geometry.white,
        );

        // p2
        try State.render_circles(
            renderer,
            self.p2.marbles.const_slice(),
            screen_factor,
            geometry.black,
        );

        // p1
        try State.render_circles(
            renderer,
            self.selected_balls.const_slice(),
            screen_factor,
            geometry.grey,
        );
    }
};
