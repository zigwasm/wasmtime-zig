const std = @import("std");

pub const Error = @import("./error.zig").Error;
pub const Engine = @import("./engine.zig").Engine;

pub const wasm = @import("wasm");

pub const Context = opaque {};

// Store is a general group of wasm instances, and many objects
// must all be created with and reference the same `Store`
pub const Store = struct {
    inner: *wasm.Store,

    engine: *Engine,

    // init creates a new `Store` from the configuration provided in `engine`
    pub fn init(engine: *Engine) !Store {
        return Store{
            .inner = try wasm.Store.init(engine.inner),
            .engine = engine,
        };
    }

    pub fn deinit(self: *Store) void {
        self.inner.deinit();
    }

    pub fn context(self: *Store) *Context {
        return wasmtime_store_context(self.inner) orelse Error.StoreContext;
    }

    pub fn setEpochDeadline(self: *Store, deadline: u64) void {
        wasmtime_context_set_epoch_deadline(self.context(), deadline);
    }

    extern "c" fn wasmtime_store_context(*Store) *Context;
    extern "c" fn wasmtime_context_set_epoch_deadline(*Context, u64) void;

    // not imlemented
    // extern "c" fn wasmtime_context_fuel_consumed(*Context, u64) c_int // ??
    // extern "c" fn wasmtime_context_add_fuel(*Context, u64) void
    // extern "c" fn wasmtime_context_consume_fuel(*Context, u64, u64) u64
};
