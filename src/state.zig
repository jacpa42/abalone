const std = @import("std");
const sdl3 = @import("sdl3");
const geometry = @import("state/geometry.zig");
const pt_array = @import("point_array.zig");

const AxialVector = @import("axial.zig").AxialVector;
const Move = @import("move.zig").Move;

const Marbles = pt_array.PointArray(14);

/// Basically a cyclical array of ball indicies for the current player
const SelectedBalls = struct {
    /// All the neighbours of the same color. The max neighbours you can have is the following:
    ///
    ///  ◯ ◯ ◯ ◯
    /// ◯ ● ● ● ◯
    ///  ◯ ◯ ◯ ◯
    ///
    /// which is 10
    neighbours: pt_array.PointArray(10) = .empty,

    items: [3]AxialVector = undefined,
    len: usize = 0,

    pub fn const_slice(self: *const @This()) []const AxialVector {
        return self.items[0..self.len];
    }

    /// Trys to insert the item into the back of `items`
    pub fn try_insert(self: *@This(), item: AxialVector) bool {
        // If the vector is empty somewhere then select and return
        if (self.len == self.items.len) return false;

        self.items[self.len] = item;
        self.len += 1;
        return true;
    }

    /// Just recomputes all neighbours. We need to know our potential same_color neighbours so we pass that in.
    pub fn update_neighbours(self: *@This(), same_color_balls: []const AxialVector) void {
        self.neighbours = .empty;
        // If the vector is empty somewhere then select and return
        inline for (self.items[self.len]) |pos| {
            inline for (pos.neighbours()) |neighbour| {
                if (self.neighbours.contains(neighbour)) continue;

                for (same_color_balls) |sc_ball| {
                    if (sc_ball == neighbour) {
                        // Should not be possible here
                        self.neighbours.append(neighbour) catch unreachable;
                        break;
                    }
                }
            }
        }
    }

    pub inline fn find(self: *const @This(), pos: AxialVector) ?usize {
        inline for (self.items, 0..) |selected, idx| {
            if (selected == pos) return idx;
        }
        return null;
    }

    pub inline fn swap_remove(self: *@This(), idx: usize) void {
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
    pub fn try_pick_ball(self: *@This(), at: AxialVector) void {
        std.debug.print("at = {any}", .{at});
        if (self.selected_balls.find(at)) |idx| {
            self.selected_balls.swap_remove(idx);
            return;
        }

        switch (self.turn) {
            .p1 => for (self.p1.marbles.const_slice()) |marble_pos| {
                if (marble_pos == at) {
                    _ = self.selected_balls.try_insert(marble_pos);
                    return;
                }
            },
            .p2 => for (self.p2.marbles.const_slice()) |marble_pos| {
                if (marble_pos == at) {
                    _ = self.selected_balls.try_insert(marble_pos);
                    return;
                }
            },
        }
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
