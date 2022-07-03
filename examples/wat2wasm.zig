const builtin = @import("builtin");
const std = @import("std");
const wasmtime = @import("wasmtime");
const fs = std.fs;
const ga = std.heap.c_allocator;
const Allocator = std.mem.Allocator;
const unicode = @import("std").unicode;

const log = std.log.scoped(.wasmtime_zig);

pub fn main() !void {
    log.err("Starting...", .{ });
    const wat_path = if (builtin.os.tag == .windows) "examples\\simple.wat" else "examples/simple.wat";
    const wat_file = try fs.cwd().openFile(wat_path, .{});
    const wat = try wat_file.readToEndAlloc(ga, std.math.maxInt(u64));
    log.err("Read wat:\n{s}", .{ wat });
    defer ga.free(wat);

    const wasm = try wasmtime.Convert.wat2wasm(wat);
    const wasm_slice = wasm.toSlice();
    log.err("Converted wasm:\n{s}", .{ wasm_slice });

    const dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    var out = try dir.createFile("output.wasm", .{});
    defer out.close();
    if (std.unicode.utf8ValidateSlice(wasm_slice)) {
        try out.writeAll(wasm_slice);
        log.err("File written.", .{ });
    } else {
        log.err("No valid utf-8", .{});
    }
}