const builtin = @import("builtin");
const std = @import("std");
const wasmtime = @import("wasmtime");
const fs = std.fs;
const ga = std.heap.c_allocator;
const Allocator = std.mem.Allocator;

fn hello() void {
    std.debug.print("Calling back...\n", .{});
    std.debug.print("> Hello World!\n", .{});
}

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
    std.debug.print("Engine initialized...\n", .{});

    var store = try wasmtime.Store.init(engine);
    defer store.deinit();
    std.debug.print("Store initialized...\n", .{});

    var module = try wasmtime.Module.initFromWat(engine, wasm);
    defer module.deinit();
    std.debug.print("Wasm module compiled...\n", .{});

    var func = try wasmtime.Func.init(store, hello);
    std.debug.print("Func callback prepared...\n", .{});

    var instance = try wasmtime.Instance.init(store, module, &[_]*wasmtime.Func{func});
    std.debug.print("Instance initialized...\n", .{});

    if (instance.getExportFunc("run")) |f| {
        std.debug.print("Calling export...\n", .{});
        try f.call(void, .{});
    } else {
        std.debug.print("Export not found...\n", .{});
    }
}
