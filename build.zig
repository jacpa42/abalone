const std = @import("std");
const sokol = @import("sokol");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Creates a binary
    const exe = b.addExecutable(.{
        .name = "abalone",
        .root_module = exe_mod,
    });

    // sokol
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("sokol", dep_sokol.module("sokol"));

    // Shader compilation
    // extract shdc dependency from sokol dependency
    const dep_shdc = dep_sokol.builder.dependency("shdc", .{});
    const shader_dir = "src/shaders/";

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const shaders = find_shaders(&arena, shader_dir) catch @panic("Failed to find all shaders");
    defer arena.deinit();

    for (shaders.items) |shader_path_with_zig_ext| {
        const len = shader_path_with_zig_ext.len;

        const input = shader_path_with_zig_ext[0 .. len - ".zig".len];
        const output = shader_path_with_zig_ext;
        std.debug.print("Compiling shader {s} -> {s}\n", .{ input, output });

        const shdc_step = sokol.shdc.createSourceFile(b, .{
            .shdc_dep = dep_shdc,
            .input = input,
            .output = output,
            .slang = .{
                .glsl410 = false,
                .glsl430 = true,

                .glsl300es = true,
                .glsl310es = true,

                .hlsl4 = false,
                .hlsl5 = true,

                .metal_macos = true,
                .metal_ios = true,
                .metal_sim = true,
                .wgsl = true,
            },
            .reflection = true,
        }) catch @panic("");

        exe.step.dependOn(shdc_step);
    }

    std.debug.print("Shaders compiled\n", .{});

    // qoi
    const qoi = b.dependency("qoi", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("qoi", qoi.module("qoi"));

    // Installs the binary with the `install` option
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| run_cmd.addArgs(args);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the game :)");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{ .root_module = exe_mod });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

/// All the path strings and slices are allocated with the arena. Freeing the arena memory will clean up this bad boy.
///
/// All paths in the returned ArrayList contain the `.zig` extension. The actual path is just this sub 4.
fn find_shaders(
    arena: *std.heap.ArenaAllocator,
    shader_dir: []const u8,
) (error{OutOfMemory} || std.fs.Dir.OpenError)!std.ArrayList([]const u8) {
    const MAX_SHADERS = 100;

    const path_buffer = try arena.allocator().alloc([]const u8, MAX_SHADERS);
    var paths = std.ArrayList([]const u8).initBuffer(path_buffer);

    try find_shaders_in_dir(shader_dir, arena, &paths);
    return paths;
}

fn find_shaders_in_dir(
    dir_path: []const u8,
    arena: *std.heap.ArenaAllocator,
    paths: *std.ArrayList([]const u8),
) (error{OutOfMemory} || std.fs.Dir.OpenError)!void {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();

    while (try iter.next()) |entry| {
        switch (entry.kind) {
            .file => {
                const ext = ".zig";
                if (std.mem.endsWith(u8, entry.name, ext)) continue;
                const slices = [_][]const u8{ dir_path, entry.name, ".zig" };
                const file_name = try std.mem.concat(arena.allocator(), u8, &slices);
                try paths.appendBounded(file_name);
            },
            .directory => try find_shaders_in_dir(entry.name, arena, paths),
            else => continue,
        }
    }
}
