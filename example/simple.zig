const std = @import("std");
const wasmtime = @import("wasmtime");
const process = std.process;
const fs = std.fs;

fn hello(params: ?*const wasmtime.c.wasm_val_t, results: ?*wasmtime.c.wasm_val_t) callconv(.C) ?*wasmtime.c.wasm_trap_t {
    std.debug.warn("Calling back...\n", .{});
    std.debug.warn("> Hello World!\n", .{});
    return null;
}

pub fn main() !void {
    var args: process.ArgIterator = process.args();
    var buffer: [1000]u8 = undefined;
    var allocator = &std.heap.FixedBufferAllocator.init(&buffer).allocator;
    _ = args.skip();
    const wasm_fn = args.next(allocator) orelse {
        std.debug.warn("You need to pass the path to your Wasm module\n", .{});
        return;
    };

    const wasm_file = try fs.openFileAbsolute(try wasm_fn, .{});
    var wasm: [1000000]u8 = undefined;
    const nread = try wasm_file.readAll(wasm[0..]);

    var engine = try wasmtime.Engine.init();
    defer engine.deinit();
    std.debug.warn("Engine initialized...\n", .{});

    var store = try wasmtime.Store.init(engine);
    defer store.deinit();
    std.debug.warn("Store initialized...\n", .{});

    var module = try wasmtime.Module.initFromWat(store, wasm[0..nread]);
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
