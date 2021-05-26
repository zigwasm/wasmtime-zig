const std = @import("std");
const wasmtime = @import("wasmtime");
const builtin = std.builtin;
const fs = std.fs;
const ga = std.heap.c_allocator;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    const wasm_path = if (builtin.os.tag == .windows) "examples\\linking1.wat" else "examples/linking1.wat";
    const wasm_path2 = if (builtin.os.tag == .windows) "examples\\linking2.wat" else "examples/linking2.wat";
    const wasm_file = try fs.cwd().openFile(wasm_path, .{});
    defer wasm_file.close();
    const wasm_file2 = try fs.cwd().openFile(wasm_path2, .{});
    defer wasm_file2.close();
    const wasm = try wasm_file.readToEndAlloc(ga, std.math.maxInt(u64));
    defer ga.free(wasm);
    const wasm2 = try wasm_file2.readToEndAlloc(ga, std.math.maxInt(u64));
    defer ga.free(wasm2);

    const engine = try wasmtime.Engine.init();
    defer engine.deinit();
    std.debug.print("Engine initialized...\n", .{});

    const module = try wasmtime.Module.initFromWat(engine, wasm);
    defer module.deinit();

    const module2 = try wasmtime.Module.initFromWat(engine, wasm2);
    defer module2.deinit();

    const store = try wasmtime.Store.init(engine);
    defer store.deinit();
    std.debug.print("Store initialized...\n", .{});

    // intantiate wasi
    const config = try wasmtime.WasiConfig.init();
    config.inherit(.{});

    var trap: ?*wasmtime.Trap = null;
    const wasi = try wasmtime.WasiInstance.init(store, "wasi_snapshot_preview1", config, &trap);
    if (trap) |t| {
        std.debug.print("Unexpected trap during WasiInstance initialization\n", .{});
        t.deinit();
        return;
    }
    defer wasi.deinit();
    std.debug.print("wasi instance initialized...\n", .{});

    // create our linker and then add our WASI instance to it.
    const linker = try wasmtime.Linker.init(store);
    defer linker.deinit();
    if (linker.defineWasi(wasi)) |err| {
        var msg = err.getMessage();
        defer msg.deinit();
        std.debug.print("Linking init err: '{s}'\n", .{msg.toSlice()});
        return;
    }

    // Instantiate `linking2` with our linker.
    var linking2: ?*wasmtime.wasm.Instance = null;
    const link_error2 = linker.instantiate(module2, &linking2, &trap);
    if (trap) |t| {
        std.debug.print("Unexpected trap during linker initialization\n", .{});
        t.deinit();
        return;
    }
    if (link_error2) |err| {
        var msg = err.getMessage();
        defer msg.deinit();
        std.debug.print("Linker instantiate err: '{s}'\n", .{msg.toSlice()});
        return;
    }

    // Register our new `linking2` instance with the linker
    const name = wasmtime.NameVec.fromSlice("linking2");
    if (linker.defineInstance(&name, linking2.?)) |err| {
        var msg = err.getMessage();
        defer msg.deinit();
        std.debug.print("Define instance err: '{s}'\n", .{msg.toSlice()});
        return;
    }

    var instance: ?*wasmtime.wasm.Instance = undefined;
    if (linker.instantiate(module, &instance, &trap)) |err| {
        var msg = err.getMessage();
        defer msg.deinit();
        std.debug.print("Instantiate err: '{s}'\n", .{msg.toSlice()});
        return;
    }
    if (trap) |t| {
        std.debug.print("Unexpected trap during linker initialization\n", .{});
        t.deinit();
        return;
    }
    defer instance.?.deinit();
    std.debug.print("Instance initialized...\n", .{});
    std.debug.print("Wasm linking completed...\n", .{});

    if (instance.?.getExportFunc("run")) |f| {
        std.debug.print("Calling export...\n", .{});
        try f.call(void, .{});
    } else {
        std.debug.print("Export not found...\n", .{});
    }
}
