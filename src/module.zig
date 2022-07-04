const std = @import("std");

pub const Config = @import("./config.zig").Config;
pub const Error = @import("./error.zig").Error;
pub const Engine = @import("engine.zig").Engine;
pub const Store = @import("./store.zig").Store;
pub const Convert = @import("./utils.zig").Convert;
pub const WasmError = @import("./utils.zig").WasmError;

pub const wasm = @import("wasm");

const log = std.log.scoped(.wasmtime_zig);

pub const ByteVec = wasm.ByteVec;

pub const Module = struct {
    inner: *wasm.Module,

    /// Initializes a new `Module` by first converting the given wat format
    /// into wasm bytecode.
    pub fn initFromWat(engine: *Engine, wat: []const u8) !Module {
        var wasm_bytes = try Convert.wat2wasm(wat);
        // defer wasm_bytes.deinit();

        var module = Module{
            .inner = try Module.initInner(engine, &wasm_bytes),
        };

        return module;
    }

    fn initInner(engine: *Engine, wasm_bytes: *ByteVec) !*wasm.Module {
        var inner: ?*wasm.Module = undefined;

        // /**
        // * \brief Compiles a WebAssembly binary into a #wasmtime_module_t
        // *
        // * This function will compile a WebAssembly binary into an owned #wasm_module_t.
        // * This performs the same as #wasm_module_new except that it returns a
        // * #wasmtime_error_t type to get richer error information.
        // *
        // * On success the returned #wasmtime_error_t is `NULL` and the `ret` pointer is
        // * filled in with a #wasm_module_t. On failure the #wasmtime_error_t is
        // * non-`NULL` and the `ret` pointer is unmodified.
        // *
        // * This function does not take ownership of any of its arguments, but the
        // * returned error and module are owned by the caller.
        // */
        const err = wasmtime_module_new( // WASM_API_EXTERN wasmtime_error_t *wasmtime_module_new(
            engine.inner, // wasm_engine_t *engine,
            wasm_bytes.data, // const uint8_t *wasm,
            wasm_bytes.size, // size_t wasm_len,
            &inner.? // wasmtime_module_t **ret
        );

        if (err) |e| {
            defer e.deinit();
            var msg = e.getMessage();
            defer msg.deinit();

            log.err("unexpected error occurred: '{s}'", .{msg.toSlice()});
            return Error.ModuleInit;
        }

        return inner.?;
    }

    pub fn deinit(self: Module) void {
        log.err("self: {s} ({s})", .{ &self, @TypeOf(&self) });
        self.inner.deinit();
    }

    extern "c" fn wasmtime_module_new(*wasm.Engine, [*]const u8, usize, **wasm.Module) ?*WasmError;
};
