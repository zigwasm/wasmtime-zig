const std = @import("std");
const testing = std.testing;
const c = @cImport({
    @cInclude("wasm.h");
    @cInclude("wasmtime.h");
});

pub const Error = error{ EngineInit, StoreInit, ModuleInit };

pub const Engine = struct {
    instance: *c.wasm_engine_t,

    const Self = @This();

    pub fn init() !Self {
        const instance = c.wasm_engine_new() orelse return Error.EngineInit;
        return Self{
            .instance = instance,
        };
    }

    pub fn deinit(en: Self) void {
        c.wasm_engine_delete(en.instance);
    }
};

pub const Store = struct {
    instance: *c.wasm_store_t,

    const Self = @This();

    pub fn init(engine: *Engine) !Self {
        const instance = c.wasm_store_new(engine.instance) orelse return Error.StoreInit;
        return Self{
            .instance = instance,
        };
    }

    pub fn deinit(st: Self) void {
        c.wasm_store_delete(st.instance);
    }
};

pub const Module = struct {
    instance: *c.wasm_module_t,

    const Self = @This();

    pub fn init(store: *Store, wasm: []const u8) !Self {
        var wasm_bytes: c.wasm_byte_vec_t = undefined;
        c.wasm_byte_vec_new_uninitialized(&wasm_bytes, wasm.len);
        defer c.wasm_byte_vec_delete(&wasm_bytes);

        var i: usize = 0;
        var ptr = wasm_bytes.data;
        while (i < wasm.len) : (i += 1) {
            ptr.* = wasm[i];
            ptr += 1;
        }

        var instance: ?*c.wasm_module_t = null;
        const err = c.wasmtime_module_new(store.instance, &wasm_bytes, &instance);
        defer if (err) |e| {
            c.wasmtime_error_delete(e);
        };

        if (err) |e| {
            var msg: c.wasm_byte_vec_t = undefined;
            c.wasmtime_error_message(e, &msg);
            defer c.wasm_byte_vec_delete(&msg);

            // TODO print error message
            std.debug.warn("unexpected error occurred", .{});
            return Error.ModuleInit;
        }

        if (instance) |inst| {
            return Self{
                .instance = inst,
            };
        } else {
            return Error.ModuleInit;
        }
    }

    pub fn deinit(md: Self) void {
        c.wasm_module_delete(module);
    }
};

test "" {
    _ = Engine;
    _ = Store;
    _ = Module;
}
