const builtin = @import("builtin");
const std = @import("std");
const wasmtime = @import("wasmtime");
const fs = std.fs;
const ga = std.heap.c_allocator;
const Allocator = std.mem.Allocator;

fn hello() void {
    std.debug.warn("Calling back...\n", .{});
    std.debug.warn("> Hello World!\n", .{});
}
// fn hello(params: ?*const wasmtime.c.wasm_val_t, results: ?*wasmtime.c.wasm_val_t) callconv(.C) ?*c_void {
//     std.debug.warn("Calling back...\n", .{});
//     std.debug.warn("> Hello World!\n", .{});
//     return null;
// }

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
    const wasm_path = if (builtin.os.tag == .windows) "example\\simple.wat" else "example/simple.wat";
    const wasm_file = try fs.cwd().openFile(wasm_path, .{});
    const wasm = try readToEnd(wasm_file, ga);
    defer ga.free(wasm);

    var engine = try wasmtime.Engine.init();
    defer engine.deinit();
    std.debug.warn("Engine initialized...\n", .{});

    var store = try wasmtime.Store.init(engine);
    defer store.deinit();
    std.debug.warn("Store initialized...\n", .{});

    var module = try wasmtime.Module.initFromWat(store, wasm);
    defer module.deinit();
    std.debug.warn("Wasm module compiled...\n", .{});

    var func = try wasmtime.Func.init(store, hello);
    std.debug.warn("Func callback prepared...\n", .{});

    var instance = try wasmtime.Instance.init(module, func);
    std.debug.warn("Instance initialized...\n", .{});

    if (try instance.getFuncExport("hello")) |f| {
        std.debug.warn("Calling export...\n", .{});
        try f.call();
    } else {
        std.debug.warn("Export not found...\n", .{});
    }
}
