const std = @import("std");
const wasmtime = @import("wasmtime");
const process = std.process;
const fs = std.fs;

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
    errdefer engine.deinit();
    std.debug.warn("Engine initialized...\n", .{});

    var store = try wasmtime.Store.init(&engine);
    errdefer store.deinit();
    std.debug.warn("Store initialized...\n", .{});

    var module = try wasmtime.Module.init(&store, wasm[0..nread]);
    errdefer module.deinit();
    std.debug.warn("Wasm module compiled...\n", .{});
}
