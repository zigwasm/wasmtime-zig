const std = @import("std");

pub const Config = @import("./config.zig").Config;

pub const wasm = @import("wasm");

// Engine is an instance of a wasmtime engine which is used to create a `Store`.
//
// Engines are a form of global configuration for wasm compilations and modules
// and such.
pub const Engine = struct {
    inner: *wasm.Engine,

    /// TODO: decide: call function "init" or "new"?
    /// init creates a new `Engine` with default configuration.
    pub fn init() !Engine {
        return Engine{
            .inner = try wasm.Engine.init(),
        };
    }

    // withConfig creates a new `Engine` with the `Config` provided
    //
    // Note that once a `Config` is passed to this method it cannot be used again.
    pub fn withConfig(config: *Config) !Engine {
        return Engine{
            .inner = try wasm.Engine.withConfig(config.inner),
        };
    }

    /// Frees the resources of the `Engine`
    pub fn deinit(self: *Engine) void {
        self.inner.deinit();
    }

    /// IncrementEpoch will increase the current epoch number by 1 within the
    /// current engine which will cause any connected stores with their epoch
    /// deadline exceeded to now be interrupted.
    pub fn incrementEpoch(self: *Engine) void {
        wasmtime_engine_increment_epoch(self.inner);
    }

    extern "c" fn wasmtime_engine_increment_epoch(*wasm.Engine) void;
};

test "withConfig" {
    const o = Config.Options{
        .debugInfo = true,
    };

    var c: Config = try Config.init(o);

    var engine = try Engine.withConfig(&c);
    defer engine.deinit();
}
