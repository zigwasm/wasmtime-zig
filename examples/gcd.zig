const builtin = @import("builtin");
const std = @import("std");
const wasmtime = @import("wasmtime");
const fs = std.fs;
const ga = std.heap.c_allocator;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    const wasm_path = if (builtin.os.tag == .windows) "examples\\gcd.wat" else "examples/gcd.wat";
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

    var instance = try wasmtime.Instance.init(store, module, &.{});
    defer instance.deinit();
    std.debug.print("Instance initialized...\n", .{});

    if (instance.getExportFunc("gcd")) |f| {
        std.debug.print("Calling export...\n", .{});
        const result = try f.call(i32, .{ @as(i32, 6), @as(i32, 27) });
        std.debug.print("Result: {d}\n", .{result});
    } else {
        std.debug.print("Export not found...\n", .{});
    }
}
