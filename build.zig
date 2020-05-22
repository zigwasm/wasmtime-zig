const builtin = @import("builtin");
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Builder = std.build.Builder;
const RunStep = std.build.RunStep;
const LibExeObjStep = std.build.LibExeObjStep;

const LIBWASMTIME_URL = "https://github.com/bytecodealliance/wasmtime/releases/download/v0.16.0/wasmtime-v0.16.0-x86_64-macos-c-api.tar.xz";

fn installDependency(b: *Builder, lib: *LibExeObjStep, url: []const u8, artifact: []const u8) !void {
    const allocator = b.allocator;
    const cwd = try mem.concat(allocator, u8, &[_][]const u8{ b.cache_root, "/deps" });
    defer allocator.free(cwd);

    try b.makePath(cwd);

    const archive_path = try mem.concat(allocator, u8, &[_][]const u8{ cwd, "/libwasmtime.tar.xz" });
    defer allocator.free(archive_path);

    const download_cmd = download(b, url, archive_path);
    lib.step.dependOn(&download_cmd.step);

    const unpack_cmd = unpack(b, archive_path, &[_][]const u8{artifact}, cwd);
    lib.step.dependOn(&unpack_cmd.step);

    const lib_path = try mem.concat(allocator, u8, &[_][]const u8{ cwd, "/libwasmtime.a" });
    // defer allocator.free(lib_path);

    const install_cmd = b.addInstallLibFile(lib_path, "libwasmtime.a");
    lib.step.dependOn(&install_cmd.step);
}

fn download(b: *Builder, url: []const u8, dest_path: []const u8) *RunStep {
    if (builtin.os.tag == .macosx) {
        return b.addSystemCommand(&[_][]const u8{ "curl", "-L", url, "-o", dest_path });
    }
    @compileError("unsupported platform");
}

fn unpack(b: *Builder, archive_path: []const u8, artifacts: []const []const u8, dest_path: []const u8) *RunStep {
    if (builtin.os.tag == .macosx) {
        // TODO unpack all specified artifacts
        return b.addSystemCommand(&[_][]const u8{ "tar", "-C", dest_path, "--strip-components", "2", "-xvf", archive_path, artifacts[0] });
    }
    @compileError("unsupported platform");
}

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();

    // TODO detect if the user installed dynamic library
    const lib = b.addStaticLibrary("wasmtime-zig", "src/main.zig");
    try installDependency(b, lib, LIBWASMTIME_URL, "*/lib/libwasmtime.a");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const simple_exe = b.addExecutable("simple", "example/simple.zig");
    simple_exe.setBuildMode(mode);
    simple_exe.addPackagePath("wasmtime", "src/main.zig");
    simple_exe.addObjectFile("zig-cache/lib/libwasmtime.a");

    simple_exe.step.dependOn(b.getInstallStep());

    const run_simple_cmd = simple_exe.run();
    const run_simple_step = b.step("example-simple", "Run the simple example app");
    run_simple_step.dependOn(&run_simple_cmd.step);
}
