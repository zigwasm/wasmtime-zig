const std = @import("std");
const wasmtime = @import("wasmtime");

pub fn main() !void {
    var engine = try wasmtime.Engine.init();
    defer engine.deinit();
    std.debug.warn("Engine initialized...\n", .{});

    var store = try wasmtime.Store.init(&engine);
    defer store.deinit();
    std.debug.warn("Store initialized...\n", .{});
}
