const std = @import("std");
const sdl3 = @import("sdl3");

pub const Color = sdl3.pixels.FColor;
const Renderer = sdl3.render.Renderer;
const Point = sdl3.rect.FPoint;
const Vertex = sdl3.render.Vertex;

const size = @import("../axial.zig").AxialVector.radius;

pub const grey = Color{ .r = 114.0 / 255.0, .g = 113.0 / 255.0, .b = 105.0 / 255.0, .a = 1.0 };
pub const light_grey = Color{ .r = 114.0 / 255.0, .g = 113.0 / 255.0, .b = 105.0 / 255.0, .a = 0.5 };
pub const white = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
pub const black = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
pub const purple = Color{ .r = 202.0 / 255.0, .g = 158.0 / 255.0, .b = 230.0 / 255.0, .a = 1.0 };
pub const red = Color{ .r = 232.0 / 255.0, .g = 36.0 / 255.0, .b = 36.0 / 255.0, .a = 1.0 };

pub const Hexagon = Poly(6, std.math.pi / 6.0, size);
pub const Circle = Poly(20, 0, size);

fn default_indices(comptime num_sides: comptime_int) [3 * num_sides]c_int {
    var indices: [3 * num_sides]c_int = undefined;

    // Construct the triangles from the sides
    for (0..num_sides) |side| {
        indices[3 * side] = 0;
        indices[3 * side + 1] = side + 1;
        indices[3 * side + 2] = side + 2;
    }
    indices[3 * num_sides - 1] = 1;

    return indices;
}

fn default_vertices(comptime num_sides: comptime_int, angle_offset: f32, radius: f32) [1 + num_sides]Vertex {
    const num_vertices = 1 + num_sides;
    const theta = (2.0 * std.math.pi) / @as(f32, @floatFromInt(num_sides));

    var vertices: [num_vertices]Vertex = undefined;

    // Set colors
    for (&vertices) |*vertex| vertex.color = grey;

    vertices[0].position = .{ .x = 0, .y = 0 };

    // Set positions
    for (vertices[1..], 0..) |*vertex, corner_idx| {
        const angle = @as(f32, @floatFromInt(corner_idx)) * theta + angle_offset;
        vertex.position = .{ .x = radius * @cos(angle), .y = radius * @sin(angle) };
    }

    return vertices;
}

pub fn Poly(comptime num_sides: comptime_int, angle_offset: f32, radius: f32) type {
    return struct {
        vertices: [1 + num_sides]Vertex = default_vertices(num_sides, angle_offset, radius),
        pub const indicies = default_indices(num_sides);

        /// Scales the size of the polygon by a factor
        pub fn shift(self: *@This(), x: f32, y: f32) void {
            inline for (&self.vertices) |*vertex| {
                vertex.position.x += x;
                vertex.position.y += y;
            }
        }

        /// Scales the size of the polygon by a factor
        pub fn scale(self: *@This(), factor: f32) void {
            inline for (&self.vertices) |*vertex| {
                vertex.position.x *= factor;
                vertex.position.y *= factor;
            }
        }

        pub fn color(self: *@This(), col: Color) void {
            inline for (&self.vertices) |*vertex| {
                vertex.color = col;
            }
        }

        /// A little thing i made which translates between the -1 to 1 coordinates used by open gl and the window coordinates used by sdl3.
        ///
        /// This makes it easier to place things on the screen.
        pub fn render_transform(self: *@This(), at: Point, screen_width: f32, screen_height: f32) void {
            std.debug.assert(screen_height > 0);
            std.debug.assert(screen_width > 0);

            const m = @min(screen_width, screen_height) * 0.5;
            self.shift(at.x + 1, at.y + 1);
            self.scale(m);
        }
    };
}
