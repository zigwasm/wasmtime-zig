const std = @import("std");
const testing = std.testing;
const c = @cImport({
    @cInclude("wasm.h");
    @cInclude("wasmtime.h");
});

pub const Error = error{ EngineInit, StoreInit, ModuleInit };

pub const Engine = struct {
    c_ptr: *c.wasm_engine_t,

    const Self = @This();

    pub fn init() !Self {
        const engine = c.wasm_engine_new() orelse return Error.EngineInit;
        return Self{
            .c_ptr = engine,
        };
    }

    pub fn deinit(self: Self) void {
        c.wasm_engine_delete(self.c_ptr);
    }
};

pub const Store = struct {
    c_ptr: *c.wasm_store_t,

    const Self = @This();

    pub fn init(engine: *Engine) !Self {
        const store = c.wasm_store_new(engine.c_ptr) orelse return Error.StoreInit;
        return Self{
            .c_ptr = store,
        };
    }

    pub fn deinit(self: Self) void {
        c.wasm_store_delete(self.c_ptr);
    }
};

pub const Module = struct {
    c_ptr: *c.wasm_module_t,

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

        var maybe_c_ptr: ?*c.wasm_module_t = null;
        const err = c.wasmtime_module_new(store.c_ptr, &wasm_bytes, &maybe_c_ptr);
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

        if (maybe_c_ptr) |c_ptr| {
            return Self{
                .c_ptr = c_ptr,
            };
        } else {
            return Error.ModuleInit;
        }
    }

    pub fn deinit(self: Self) void {
        c.wasm_module_delete(self.c_ptr);
    }
};

test "" {
    _ = Engine;
    _ = Store;
    _ = Module;
}
