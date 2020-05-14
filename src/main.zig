const std = @import("std");
const testing = std.testing;
const c = @cImport({
    @cInclude("wasm.h");
    @cInclude("wasmtime.h");
});

pub const Error = error{ EngineInit, StoreInit };

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
    engine: *Engine,
    instance: *c.wasm_store_t,

    const Self = @This();

    pub fn init(engine: *Engine) !Self {
        const instance = c.wasm_store_new(engine.instance) orelse return Error.StoreInit;
        return Self{
            .engine = engine,
            .instance = instance,
        };
    }

    pub fn deinit(st: Self) void {
        c.wasm_store_delete(st.instance);
    }
};

test "" {
    _ = Engine;
    _ = Store;
}
