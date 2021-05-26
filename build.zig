const std = @import("std");
const builtin = @import("builtin");
const pkgs = @import("deps.zig").pkgs;

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("wasmtime-zig", "src/main.zig");
    lib.setBuildMode(mode);
    lib.addPackage(pkgs.wasm);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.addPackage(pkgs.wasm);
    main_tests.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const example = b.option([]const u8, "example", "The example to run from the examples/ folder");
    const example_path = example_path: {
        const basename = example orelse "simple";
        const with_ext = try std.fmt.allocPrint(b.allocator, "{s}.zig", .{basename});
        const full_path = try std.fs.path.join(b.allocator, &[_][]const u8{ "examples", with_ext });
        break :example_path full_path;
    };

    const simple_exe = b.addExecutable(example orelse "simple", example_path);
    simple_exe.setBuildMode(mode);
    simple_exe.addPackage(.{
        .name = "wasmtime",
        .path = "src/main.zig",
        .dependencies = &.{pkgs.wasm},
    });
    if (builtin.os.tag == .windows) {
        simple_exe.linkSystemLibrary("wasmtime.dll");
    } else {
        simple_exe.linkSystemLibrary("wasmtime");
    }
    simple_exe.linkLibC();
    simple_exe.step.dependOn(b.getInstallStep());

    const run_simple_cmd = simple_exe.run();
    const run_simple_step = b.step("run", "Runs an example. If no -Dexample arg is provided, the simple example will be ran");
    run_simple_step.dependOn(&run_simple_cmd.step);
}
