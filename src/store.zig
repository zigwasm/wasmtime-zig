const std = @import("std");

pub const config = @import("./config.zig");
pub const error = @import("./error.zig").Error;

pub const wasm = @import("wasm");

pub const Context = opaque {}

// Store is a general group of wasm instances, and many objects
// must all be created with and reference the same `Store`
pub const Store = struct {
    inner: *wasm.Store,

    engine: *wasmtime.Engine,

    // init creates a new `Store` from the configuration provided in `engine`
    pub fn init(engine: *wasmtime.Engine) !*Store {
        return Store {
            .inner = try wasm.Store.init();
        }
    }

    pub fn deinit(self: *Store) void {
        self.inner.deinit(self.inner);
    }

    pub fn context() *Context{
        return wasmtime_store_context(self.inner) orelse error.StoreContext
    }

    pub fn setEpochDeadline(self: *Store, deadline: u64) {
        wasmtime_context_set_epoch_deadline(self.context(), deadline)
    }

    // not imlemented
    pub fn fuelConsumed() (uint64, bool) // zig multiple return values?
    pub fn addFuel(fuel: u64) !void {}
    pub fn consumeFuel(fuel: u64) !u64 {}

    extern "c" fn wasmtime_store_context(*Store) *Context;
    extern "c" fn wasmtime_context_set_epoch_deadline(*Context, u64);

    // not imlemented
    extern "c" fn wasmtime_context_fuel_consumed(*Context, u64) // ??
    extern "c" fn wasmtime_context_add_fuel(*Context, u64) void
    extern "c" fn wasmtime_context_consume_fuel(*Context, u64, u64) u64
}
