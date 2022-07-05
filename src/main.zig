const std = @import("std");
const testing = std.testing;
const log = std.log.scoped(.wasmtime_zig);

pub const wasm = @import("wasm");

pub const Convert = @import("utils.zig").Convert;
pub const Config = @import("config.zig").Config;
pub const Engine = @import("engine.zig").Engine;
pub const Store = @import("store.zig").Store;
pub const Module = @import("module.zig").Module;
// pub const Func = @import("func.zig").Func;
// pub const Instance = @import("instance.zig").Instance;

test "" {
    testing.refAllDecls(@This());
}
