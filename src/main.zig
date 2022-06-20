const std = @import("std");
const testing = std.testing;
const log = std.log.scoped(.wasmtime_zig);

pub const wasm = @import("wasm");

pub const Config = @import("config.zig").Config;
pub const Engine = @import("engine.zig").Engine;

test "" {
    testing.refAllDecls(@This());
}
