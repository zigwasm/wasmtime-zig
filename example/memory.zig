const builtin = @import("builtin");
const std = @import("std");
const wasmtime = @import("wasmtime");
const fs = std.fs;
const ga = std.heap.c_allocator;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn main() !void {
    const wasm_path = if (builtin.os.tag == .windows) "example\\memory.wat" else "example/memory.wat";
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

    var instance = try wasmtime.Instance.init(store, module, &[_]*wasmtime.Func{});
    defer instance.deinit();
    std.debug.print("Instance initialized...\n", .{});

    const memory = instance.getExportMem("memory").?;
    defer memory.deinit();

    const size_func = instance.getExportFunc("size").?;
    const load_func = instance.getExportFunc("load").?;
    const store_func = instance.getExportFunc("store").?;

    // verify initial memory
    assert(memory.pages() == 2);
    assert(memory.size() == 0x20_000);
    assert(memory.data()[0] == 0);
    assert(memory.data()[0x1000] == 1);
    assert(memory.data()[0x1003] == 4);

    assertCall(size_func, 2);
    assertCall1(load_func, 0, 0);
    assertCall1(load_func, 0x1000, 1);
    assertCall1(load_func, 0x1003, 4);
    assertCall1(load_func, 0x1ffff, 0);
    assertTrap(load_func, 0x20_000);

    // mutate memory
    memory.data()[0x1003] = 5;
    assertCall2(store_func, 0x1002, 6);
    assertTrap1(store_func, 0x20_000, 0);

    // verify memory again
    assert(memory.data()[0x1002] == 6);
    assert(memory.data()[0x1003] == 5);
    assertCall1(load_func, 0x1002, 6);
    assertCall1(load_func, 0x1003, 5);

    // Grow memory
    try memory.grow(1); // 'allocate' 1 more page
    assert(memory.pages() == 3);
    assert(memory.size() == 0x30_000);

    assertCall1(load_func, 0x20_000, 0);
    assertCall2(store_func, 0x20_000, 0);
    assertTrap(load_func, 0x30_000);
    assertTrap1(store_func, 0x30_000, 0);

    if (memory.grow(1)) |_| {} else |err| assert(err == error.OutOfMemory);
    try memory.grow(0);

    // create stand-alone memory
    const mem_type = try wasmtime.c.MemoryType.init(.{ .min = 5, .max = 5 });
    defer mem_type.deinit();

    const mem = try wasmtime.c.Memory.init(store, mem_type);
    defer mem.deinit();

    assert(mem.pages() == 5);
    if (mem.grow(1)) |_| {} else |err| assert(err == error.OutOfMemory);
    try memory.grow(0);
}

fn assertCall(func: *wasmtime.Func, result: u32) void {
    const res = func.call(@TypeOf(result), .{}) catch std.debug.panic("Unexpected error", .{});
    std.debug.assert(result == res);
}

fn assertCall1(func: *wasmtime.Func, comptime arg: u32, result: u32) void {
    const res = func.call(@TypeOf(arg), .{arg}) catch std.debug.panic("Unexpected error", .{});
    std.debug.assert(result == res);
}

fn assertCall2(func: *wasmtime.Func, comptime arg: u32, comptime arg2: u32) void {
    const res = func.call(void, .{ arg, arg2 }) catch std.debug.panic("Unexpected error", .{});
    std.debug.assert({} == res);
}

fn assertTrap(func: *wasmtime.Func, comptime arg: u32) void {
    if (func.call(@TypeOf(arg), .{arg})) |_| {
        std.debug.panic("Expected Trap error, got result", .{});
    } else |err| std.debug.assert(err == error.Trap);
}

fn assertTrap1(func: *wasmtime.Func, comptime arg: u32, comptime arg2: u32) void {
    if (func.call(void, .{ arg, arg2 })) |_| {
        std.debug.panic("Expected Trap error, got result", .{});
    } else |err| std.debug.assert(err == error.Trap);
}
