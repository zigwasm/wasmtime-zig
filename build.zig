const builtin = @import("builtin");
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();

    const lib_path = b.option([]const u8, "library-search-path", "Add additional system library search path.");

    const lib = b.addStaticLibrary("wasmtime-zig", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.linkSystemLibrary("wasmtime");
    if (lib_path) |path| {
        main_tests.addLibPath(path);
    }
    main_tests.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const simple_exe = b.addExecutable("simple", "example/simple.zig");
    simple_exe.setBuildMode(mode);
    simple_exe.addPackagePath("wasmtime", "src/main.zig");
    simple_exe.linkSystemLibrary("wasmtime");
    if (builtin.os.tag == .windows) {
        simple_exe.linkSystemLibrary("advapi32");
        simple_exe.linkSystemLibrary("Ws2_32");
        simple_exe.linkSystemLibrary("userenv");
    } else {
        simple_exe.linkSystemLibrary("pthread");
    }
    if (lib_path) |path| {
        simple_exe.addLibPath(path);
    }
    simple_exe.step.dependOn(b.getInstallStep());

    const run_simple_cmd = simple_exe.run();
    const run_simple_step = b.step("example-simple", "Run the simple example app");
    run_simple_step.dependOn(&run_simple_cmd.step);
}
