const builtin = @import("builtin");
const std = @import("std");
const wasmtime = @import("wasmtime");
const fs = std.fs;
const ga = std.heap.c_allocator;
const Allocator = std.mem.Allocator;

fn interrupt(handle: *wasmtime.c.InterruptHandle) void {
    // sleep for 2 seconds
    std.time.sleep(std.time.ns_per_s * 2);
    std.debug.print("Sending interrupt...\n", .{});
    handle.interrupt();
}

pub fn main() !void {
    const wasm_path = if (builtin.os.tag == .windows) "example\\interrupt.wat" else "example/interrupt.wat";
    const wasm_file = try fs.cwd().openFile(wasm_path, .{});
    const wasm = try wasm_file.readToEndAlloc(ga, std.math.maxInt(u64));
    defer ga.free(wasm);

    const config = try wasmtime.Config.init(.{ .interruptable = true });
    var engine = try wasmtime.Engine.withConfig(config);
    defer engine.deinit();
    std.debug.print("Engine initialized...\n", .{});

    var store = try wasmtime.Store.init(engine);
    std.debug.print("Store initialized...\n", .{});

    var handle = try wasmtime.c.InterruptHandle.init(store);
    defer handle.deinit();
    std.debug.print("Interrupt handle created...\n", .{});

    var module = try wasmtime.Module.initFromWat(engine, wasm);
    defer module.deinit();
    std.debug.print("Wasm module compiled...\n", .{});

    var instance = try wasmtime.Instance.init(store, module, &[_]*wasmtime.Func{});
    defer instance.deinit();
    std.debug.print("Instance initialized...\n", .{});

    const thread = try std.Thread.spawn(interrupt, handle);

    if (instance.getExportFunc("run")) |f| {
        std.debug.print("Calling export...\n", .{});
        f.call(void, .{}) catch |err| switch (err) {
            error.Trap => std.debug.print("Trap was hit!\n", .{}),
            else => return err,
        };
    } else {
        std.debug.print("Export not found...\n", .{});
    }

    thread.wait();
}
