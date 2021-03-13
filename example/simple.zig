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

pub fn main() !void {
    const wasm_path = if (builtin.os.tag == .windows) "example\\simple.wat" else "example/simple.wat";
    const wasm_file = try fs.cwd().openFile(wasm_path, .{});
    const wasm = try wasm_file.readToEndAlloc(ga, std.math.maxInt(u64));
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
    defer instance.deinit();
    std.debug.print("Instance initialized...\n", .{});

    if (instance.getExportFunc("run")) |f| {
        std.debug.print("Calling export...\n", .{});
        try f.call(void, .{});
    } else {
        std.debug.print("Export not found...\n", .{});
    }
}
