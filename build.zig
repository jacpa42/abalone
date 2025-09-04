const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

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

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,

        // Options passed directly to https://github.com/castholm/SDL (SDL3 C Bindings):
        .c_sdl_preferred_linkage = std.builtin.LinkMode.dynamic,
        .c_sdl_strip = true,
        .c_sdl_sanitize_c = std.zig.SanitizeC.off,
        .c_sdl_lto = if (@import("builtin").target.os.tag == .macos) .none else .full,
        // .c_sdl_emscripten_pthreads = false,
        // .c_sdl_install_build_config_h = false,

        .ext_image = false,
        // Options if `ext_image` is enabled:
        // .image_enable_bmp = true,
        // .image_enable_gif = true,
        // .image_enable_jpg = true,
        // .image_enable_lbm = true,
        // .image_enable_pcx = true,
        // .image_enable_pnm = true,
        // .image_enable_qoi = true,
        // .image_enable_svg = true,
        // .image_enable_tga = true,
        // .image_enable_xcf = true,
        // .image_enable_xpm = true,
        // .image_enable_xv = true,
        // .image_enable_png = true,
    });

    exe.root_module.addImport("sdl3", sdl3.module("sdl3"));

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

    // Only pass macOS-specific linker flags if target is Darwin
    if (target.result.os.tag == .macos) {
        exe.dead_strip_dylibs = true;
    }

    const exe_unit_tests = b.addTest(.{ .root_module = exe_mod });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
