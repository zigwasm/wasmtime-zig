const builtin = @import("builtin");
const std = @import("std");
const wasmtime = @import("wasmtime");
const fs = std.fs;
const ga = std.heap.c_allocator;
const Allocator = std.mem.Allocator;

fn readToEnd(file: fs.File, alloc: *Allocator) ![]u8 {
    const ALLOC_SIZE: comptime usize = 1000;

    var buffer = try alloc.alloc(u8, ALLOC_SIZE);
    defer alloc.free(buffer);

    var total_read: usize = 0;
    while (true) {
        const nread = try file.readAll(buffer[total_read..]);
        total_read += nread;

        if (total_read < buffer.len) break;

        buffer = try alloc.realloc(buffer, buffer.len + ALLOC_SIZE);
    }

    var contents = try alloc.alloc(u8, total_read);
    std.mem.copy(u8, contents, buffer[0..total_read]);

    return contents;
}

pub fn main() !void {
    const wasm_path = if (builtin.os.tag == .windows) "example\\gcd.wat" else "example/gcd.wat";
    const wasm_file = try fs.cwd().openFile(wasm_path, .{});
    const wasm = try readToEnd(wasm_file, ga);
    defer ga.free(wasm);

    var engine = try wasmtime.Engine.init();
    defer engine.deinit();
    std.debug.print("Engine initialized...\n", .{});

    var store = try wasmtime.Store.init(engine);
    defer store.deinit();
    std.debug.print("Store initialized...\n", .{});

    var module = try wasmtime.Module.initFromWat(engine, wasm);
    defer module.deinit();
    std.debug.print("Wasm module compiled...\n", .{});

    var instance = try wasmtime.Instance.init(store, module, &.{});
    std.debug.print("Instance initialized...\n", .{});

    if (instance.getExportFunc("gcd")) |f| {
        std.debug.print("Calling export...\n", .{});
        const result = try f.call(i32, .{ @as(i32, 6), @as(i32, 27) });
        std.debug.print("Result: {d}\n", .{result});
    } else {
        std.debug.print("Export not found...\n", .{});
    }
}
