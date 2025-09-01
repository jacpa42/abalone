const rl = @import("raylib");
const AxialVector = @import("axial_point.zig").AxialVector;

pub fn render_hexagons(bound: i8, radius: f32) void {
    for (-bound..bound + 1) |q| {
        for (-bound..bound + 1) |r| {
            render_hexagon(.{ .q = q, .r = r }, radius);
        }
    }
}

pub inline fn render_hexagon(vec: AxialVector, radius: f32) void {
    const x, const y = vec.to_pixel_vec();

    const offsets: [6]Vector2 = [
    // todo: add the offset vectors from the center of the hexagon to define the line strips
tododododododo
    ];

    rl.drawLineStrip(&offsets, .black);
}
