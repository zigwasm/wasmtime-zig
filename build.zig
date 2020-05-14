const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("wasmtime-zig", "src/main.zig");
    lib.setBuildMode(mode);
    lib.addIncludeDir("lib");
    lib.addLibPath("lib");
    lib.linkSystemLibraryName("wasmtime");
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.addIncludeDir("lib");
    main_tests.addLibPath("lib");
    main_tests.linkSystemLibraryName("wasmtime");

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
