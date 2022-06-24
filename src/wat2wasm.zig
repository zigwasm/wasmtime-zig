const std = @import("std");
const testing = std.testing;
const log = std.log.scoped(.wasmtime_zig);

pub const er = @import("./error.zig");
pub const Error = er.Error;

// pub const wasm = @import(".gyro/wasm-zig-zigwasm-github.com-3a96556d/pkg/src/main.zig");
pub const wasm = @import(".gyro/wasm-zig-zigwasm-github.com-3a96556d/pkg/src/main.zig");

pub const ByteVec = wasm.ByteVec;

pub const WasmError = opaque {
    /// Gets the error message
    pub fn getMessage(self: *WasmError) ByteVec {

        // log.info("self (*WasmError): {s}", .{ self });

        // log.info("> Initializing bytes...", .{ });
        var bytes: ByteVec = ByteVec.initWithCapacity(0);
        // log.info("bytes: {s}", .{ bytes });
        // log.info("&bytes: {s}", .{ &bytes });
        // log.info("> Calling wasmtime_error_message(self, &bytes)...", .{ });
        wasmtime_error_message(self, &bytes);
        // log.info("self (*WasmError): {s}", .{ self });
        // log.info("bytes: {s}", .{ bytes });
        // log.info("&bytes: {s}", .{ &bytes });
        // log.info("bytes.toSlice(): {s}", .{ bytes.toSlice() });
        // log.info("&bytes.toSlice(): {s}", .{ &bytes.toSlice() });
        // std.debug.print("\nbytes WasmError: {s}\n", .{ bytes.?.toSlice() });
        // std.debug.print("\nbytes WasmError: {s}\n", .{ &bytes.?.toSlice() });

        // var ret: ByteVec = bytes.?;

        // log.info("\nreturning bytes WasmError: {s}\n", .{ bytes });


        // log.info("-------------------------------------------", .{ });
        return bytes;
        // return @ptrCast(*ByteVec, bytes.?);
    }

    pub fn deinit(self: *WasmError) void {
        // std.debug.print("\ndeinit() WasmError: {s}\n", .{ self });
        wasmtime_error_delete(self);
    }

    extern "c" fn wasmtime_error_message(*const WasmError, *ByteVec) void;
    extern "c" fn wasmtime_error_delete(*WasmError) void;
};

pub const Convert = struct {
    // Wat2Wasm converts the text format of WebAssembly to the binary format.
    //
    // Takes the text format in-memory as input, and returns either the binary
    // encoding of the text format or an error if parsing fails.
    pub fn wat2wasm(wat: []const u8) !ByteVec {

        var wat_bytes = ByteVec.initWithCapacity(wat.len);
        defer wat_bytes.deinit();

        var retVec: ByteVec = undefined;

        // log.info("\nwat: {s}\n", .{wat});
        // log.info("wat.len: {d}\n", .{wat.len});
        // log.info("&wat: {s}\n", .{&wat});
        // log.info("wat_bytes.size: {d}\n", .{wat_bytes.size});

        const err = wasmtime_wat2wasm(wat.ptr, wat.len, &retVec);
        defer if (err == null) retVec.deinit();

        if (err) |e| {
            defer e.deinit();
            var msg = e.getMessage();
            // log.info("Message &msg.toSlice(): {s}\n", .{ &msg.toSlice() });
            // log.info("Message msg.toSlice(): {s}\n", .{ msg.toSlice() });
            // defer msg.?.deinit();
            defer msg.deinit();

            log.err("unexpected error occurred: '{s}'", .{msg.toSlice()});

            return Error.ModuleWat2Wasm;
        }

        return retVec;
    }

    extern "c" fn wasmtime_wat2wasm(wat: [*]const u8, wat_len: usize, retVec: *ByteVec) ?*WasmError;
};

test "wat2wasm" {

    const wasm_data1 = try Convert.wat2wasm("(module)");
    // Return value should be of type ByteVec
    try testing.expectEqual(@TypeOf(wasm_data1), @TypeOf(ByteVec.initWithCapacity(0)));

    // Return value should be len == 8
    try testing.expectEqual(wasm_data1.toSlice().len, 8);

    // Converting wat "____" to wasm should fail
    var v = Convert.wat2wasm("asd__") catch |err| {
        // log.info("Am I called?: {s}\n", .{ err });
        try testing.expect(@TypeOf(err) != @TypeOf(ByteVec.initWithCapacity(0)));
        // log.info("Am I called?: {s}\n", .{ err });
        return;
    };
    _ = v;

}