const std = @import("std");
const sokol = @import("sokol");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const abalone_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
        },
    });

    // Creates a binary
    const exe = b.addExecutable(.{
        .name = "abalone",
        .root_module = abalone_mod,
    });

    compile_shaders(b, dep_sokol, exe) catch @panic("");

    exe.root_module.addImport("sokol", dep_sokol.module("sokol"));

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

    const exe_unit_tests = b.addTest(.{ .root_module = abalone_mod });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn compile_shaders(b: *Build, dep_sokol: *Build.Dependency, abalone: *Build.Step.Compile) !void {
    // Shader compilation
    // extract shdc dependency from sokol dependency
    const dep_shdc = dep_sokol.builder.dependency("shdc", .{});
    const shader_dir = "src/shaders/";

    var shaders = try std.ArrayList(shader_desc).initCapacity(b.allocator, 0xf);
    try find_shaders(b.allocator, shader_dir, &shaders);

    for (shaders.items) |shader| {
        std.debug.print("Compiling shader {s} -> {s}\n", .{ shader.input, shader.output });

        const shdc_step = sokol.shdc.createSourceFile(b, .{
            .shdc_dep = dep_shdc,
            .input = shader.input,
            .output = shader.output,
            .slang = .{
                .glsl410 = false,
                .glsl430 = true,

                .glsl300es = true,
                .glsl310es = false,

                .hlsl4 = false,
                .hlsl5 = true,

                .wgsl = true,
                .metal_macos = true,

                .metal_ios = false,
                .metal_sim = false,
            },
        }) catch @panic("");

        abalone.step.dependOn(shdc_step);
    }

    std.debug.print("Shaders compiled\n", .{});
}

const shader_desc = struct { input: []const u8, output: []const u8 };

/// All the path strings and slices are allocated with the arena. Freeing the arena memory will clean up this bad boy.
///
/// All paths in the returned ArrayList contain the `.zig` extension. The actual path is just this sub 4.
fn find_shaders(
    alloc: std.mem.Allocator,
    shader_dir: []const u8,
    shaders: *std.ArrayList(shader_desc),
) (error{OutOfMemory} || std.fs.Dir.OpenError)!void {
    var dir = try std.fs.cwd().openDir(shader_dir, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();

    while (try iter.next()) |entry| {
        switch (entry.kind) {
            .file => {
                const ext = ".zig";
                if (std.mem.endsWith(u8, entry.name, ext)) continue;

                const input_name = [_][]const u8{ shader_dir, entry.name };
                const input = try std.mem.concat(alloc, u8, &input_name);

                const output_name = [_][]const u8{ shader_dir, entry.name, ".zig" };
                const output = try std.mem.concat(alloc, u8, &output_name);

                try shaders.append(alloc, .{ .input = input, .output = output });
            },
            .directory => try find_shaders(alloc, entry.name, shaders),
            else => continue,
        }
    }
}
