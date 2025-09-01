const std = @import("std");
const rl = @import("raylib");
const Vec = rl.Vector2;

const AxialVector = @import("axial_point.zig").AxialVector;

pub fn render() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    const bound: i8 = 4;

    var q, var r = .{ -bound, -bound };
    while (q <= bound) : (q += 1) {
        while (r <= bound) : (r += 1) {
            render_hexagon(.{ .q = q, .r = r });
        }
    }
}

pub inline fn render_hexagon(vec: AxialVector) void {
    const x, const y = vec.to_pixel_vec();

    const t = std.math.pi / 3.0;

    var points: [7]Vec = .{
        .{ .x = x, .y = y },
        .{ .x = @cos(1 * t) + x, .y = @sin(1 * t) + y },
        .{ .x = @cos(2 * t) + x, .y = @sin(2 * t) + y },
        .{ .x = @cos(3 * t) + x, .y = @sin(3 * t) + y },
        .{ .x = @cos(4 * t) + x, .y = @sin(4 * t) + y },
        .{ .x = @cos(5 * t) + x, .y = @sin(5 * t) + y },
        .{ .x = @cos(6 * t) + x, .y = @sin(6 * t) + y },
    };

    for (&points) |*point| {
        point.* = point.scale(100);
        std.debug.print("{any}\n", .{point.*});
    }
    std.debug.print("\n", .{});

    rl.drawTriangleFan(&points, .black);
}
