const std = @import("std");
const rl = @import("raylib");
const render = @import("render.zig");

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) {
        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(.white);

            rl.drawTriangle(
                .{ .x = 0, .y = screenHeight / 2 },
                .{ .x = 0, .y = screenHeight },
                .{ .x = screenWidth / 5, .y = screenHeight / 5 },
                .red,
            );
        }
    }
}
