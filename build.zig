const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;

fn linkWasmtime(step: *LibExeObjStep, search_path: ?[]const u8) void {
    if (builtin.os.tag == .windows) {
        // On Windows, link dynamic library as otherwise lld will have a
        // hard time satisfying `libwasmtime` deps
        step.linkSystemLibrary("wasmtime.dll");
    } else {
        step.linkSystemLibrary("wasmtime");
    }
    if (search_path) |path| {
        step.addLibPath(path);
    }
}

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();

    const lib_path = b.option([]const u8, "library-search-path", "Add additional system library search path.");

    const lib = b.addStaticLibrary("wasmtime-zig", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    linkWasmtime(main_tests, lib_path);
    main_tests.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const simple_exe = b.addExecutable("simple", "example/simple.zig");
    simple_exe.setBuildMode(mode);
    simple_exe.addPackagePath("wasmtime", "src/main.zig");
    simple_exe.linkLibC();
    linkWasmtime(simple_exe, lib_path);
    simple_exe.step.dependOn(b.getInstallStep());

    const run_simple_cmd = simple_exe.run();
    const run_simple_step = b.step("example-simple", "Run the simple example app");
    run_simple_step.dependOn(&run_simple_cmd.step);
}
