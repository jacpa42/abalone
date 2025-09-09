const std = @import("std");
const sokol = @import("sokol");
pub const color = @import("color.zig");

const Renderer = sokol.render.Renderer;
const Point = sokol.rect.FPoint;
const Vertex = sokol.render.Vertex;
const rgba = color.rgba;

const size = @import("../axial.zig").AxialVector.radius;
const default_palette = color.kanagawa_wave;

pub const Hexagon = Poly(6, std.math.pi / 6.0, size);
pub const Circle = Poly(20, 0, size);
pub const Square = Poly(4, std.math.pi / 4.0, size);

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
    for (&vertices) |*vertex| vertex.color = default_palette.black.sdl();

    // Set positions and texture coordinates
    {
        vertices[0].position = .{ .x = 0, .y = 0 };
        vertices[0].tex_coord = .{ .x = 0.5, .y = 0.5 };
        for (vertices[1..], 0..) |*vertex, corner_idx| {
            const angle = @as(f32, @floatFromInt(corner_idx)) * theta + angle_offset;
            vertex.position = .{ .x = radius * @cos(angle), .y = radius * @sin(angle) };
            vertex.tex_coord = .{ .x = 0.5 + 0.5 * @cos(angle), .y = 0.5 + 0.5 * @sin(angle) };
        }
    }

    return vertices;
}

pub fn Poly(comptime num_sides: comptime_int, angle_offset: f32, radius: f32) type {
    return struct {
        vertices: [1 + num_sides]Vertex = default_vertices(num_sides, angle_offset, radius),
        pub const indicies = default_indices(num_sides);

        /// Moves each vertex position by these coordinates
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

        pub fn color(self: *@This(), col: rgba) void {
            inline for (&self.vertices) |*vertex| vertex.color = col.sdl();
        }
    };
}
