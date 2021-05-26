const std = @import("std");
const testing = std.testing;
const meta = std.meta;
const trait = std.meta.trait;
const log = std.log.scoped(.wasmtime_zig);

pub const wasm = @import("wasm");

// Re-exports
pub const ByteVec = wasm.ByteVec;
pub const NameVec = wasm.NameVec;
pub const ValVec = wasm.ValVec;
pub const Value = wasm.Value;
pub const Extern = wasm.Extern;
pub const ExternVec = wasm.ExternVec;
pub const Engine = wasm.Engine;
pub const Store = wasm.Store;
pub const Error = wasm.Error;
pub const Trap = wasm.Trap;
pub const Memory = wasm.Memory;
pub const MemoryType = wasm.MemoryType;
pub const WasiInstance = wasm.WasiInstance;
pub const WasiConfig = wasm.WasiConfig;

// Helpers
extern "c" fn wasmtime_wat2wasm(wat: *ByteVec, wasm: *ByteVec) ?*WasmError;

pub const WasmError = opaque {
    /// Gets the error message
    pub fn getMessage(self: *WasmError) *ByteVec {
        var bytes: ?*ByteVec = null;
        wasmtime_error_message(self, &bytes);
        return bytes.?;
    }

    pub fn deinit(self: *WasmError) void {
        wasmtime_error_delete(self);
    }

    extern "c" fn wasmtime_error_message(*const WasmError, *?*ByteVec) void;
    extern "c" fn wasmtime_error_delete(*WasmError) void;
};

pub const Config = struct {
    inner: *wasm.Config,

    const Options = struct {
        interruptable: bool = false,
    };

    pub fn init(options: Options) !Config {
        var config = Config{
            .inner = try wasm.Config.init(),
        };
        if (options.interruptable) {
            config.setInterruptable(true);
        }
        return config;
    }

    pub fn setInterruptable(self: Config, opt: bool) void {
        wasmtime_config_interruptable_set(self.inner, opt);
    }

    extern "c" fn wasmtime_config_interruptable_set(*wasm.Config, bool) void;
};

pub const Module = struct {
    inner: *wasm.Module,

    /// Initializes a new `Module` using the supplied engine and wasm bytecode
    pub fn initFromWasm(engine: *Engine, wasm: []const u8) !Module {
        var wasm_bytes = ByteVec.initWithCapacity(wasm.len);
        defer wasm_bytes.deinit();

        var i: usize = 0;
        var ptr = wasm_bytes.data;
        while (i < wasm.len) : (i += 1) {
            ptr.* = wasm[i];
            ptr += 1;
        }

        var module = Module{
            .inner = try Module.initInner(engine, &wasm_bytes),
        };
        return module;
    }

    /// Initializes a new `Module` by first converting the given wat format
    /// into wasm bytecode.
    pub fn initFromWat(engine: *Engine, wat: []const u8) !Module {
        var wat_bytes = ByteVec.initWithCapacity(wat.len);
        defer wat_bytes.deinit();

        var i: usize = 0;
        var ptr = wat_bytes.data;
        while (i < wat.len) : (i += 1) {
            ptr.* = wat[i];
            ptr += 1;
        }

        var wasm_bytes: ByteVec = undefined;
        const err = wasmtime_wat2wasm(&wat_bytes, &wasm_bytes);
        defer if (err == null) wasm_bytes.deinit();

        if (err) |e| {
            defer e.deinit();
            var msg = e.getMessage();
            defer msg.deinit();

            log.err("unexpected error occurred: '{s}'", .{msg.toSlice()});
            return Error.ModuleInit;
        }

        var module = Module{
            .inner = try Module.initInner(engine, &wasm_bytes),
        };
        return module;
    }

    fn initInner(engine: *Engine, wasm_bytes: *ByteVec) !*wasm.Module {
        var inner: ?*wasm.Module = undefined;
        const err = wasmtime_module_new(engine, wasm_bytes, &inner);

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
        self.inner.deinit();
    }

    extern "c" fn wasmtime_module_new(*Engine, *ByteVec, *?*wasm.Module) ?*WasmError;
};

pub const Func = struct {
    inner: *wasm.Func,

    pub const CallError = wasm.Func.CallError;

    pub fn init(store: *Store, callback: anytype) !Func {
        return Func{
            .inner = try wasm.Func.init(store, callback),
        };
    }

    /// Tries to call the wasm function
    /// expects `args` to be tuple of arguments
    /// TODO this is a hard-copy of wasm.Func.call implementation. Refactor.
    pub fn call(self: Func, comptime ResultType: type, args: anytype) CallError!ResultType {
        if (!comptime trait.isTuple(@TypeOf(args)))
            @compileError("Expected 'args' to be a tuple, but found type '" ++ @typeName(@TypeOf(args)) ++ "'");

        const args_len = args.len;
        comptime var wasm_args: [args_len]Value = undefined;
        inline for (wasm_args) |*arg, i| {
            arg.* = switch (@TypeOf(args[i])) {
                i32, u32 => .{ .kind = .i32, .of = .{ .i32 = @intCast(i32, args[i]) } },
                i64, u64 => .{ .kind = .i64, .of = .{ .i64 = @intCast(i64, args[i]) } },
                f32 => .{ .kind = .f32, .of = .{ .f32 = args[i] } },
                f64 => .{ .kind = .f64, .of = .{ .f64 = args[i] } },
                *Func => .{ .kind = .funcref, .of = .{ .ref = args[i] } },
                *Extern => .{ .kind = .anyref, .of = .{ .ref = args[i] } },
                else => |ty| @compileError("Unsupported argument type '" ++ @typeName(ty) + "'"),
            };
        }

        // TODO multiple return values
        const result_len: usize = if (ResultType == void) 0 else 1;
        if (result_len != wasm_func_result_arity(self.inner)) return CallError.InvalidResultCount;
        if (args_len != wasm_func_param_arity(self.inner)) return CallError.InvalidParamCount;

        const final_args = ValVec{
            .size = args_len,
            .data = if (args_len == 0) undefined else @ptrCast([*]Value, &wasm_args),
        };

        var trap: ?*Trap = null;
        var result_list = ValVec.initWithCapacity(result_len);
        defer result_list.deinit();
        const err = wasmtime_func_call(self.inner, &final_args, &result_list, &trap);

        if (err) |e| {
            defer e.deinit();
            var msg = e.getMessage();
            defer msg.deinit();

            log.err("Unable to call function: '{s}'", .{msg.toSlice()});
            return CallError.InnerError;
        }

        if (trap) |t| {
            t.deinit();
            // TODO handle trap message
            log.err("code unexpectedly trapped", .{});
            return CallError.Trap;
        }

        if (ResultType == void) return;

        // TODO: Handle multiple returns
        const result_ty = result_list.data[0];
        if (!wasm.Func.matchesKind(ResultType, result_ty.kind)) return CallError.InvalidResultType;

        return switch (ResultType) {
            i32, u32 => @intCast(ResultType, result_ty.of.i32),
            i64, u64 => @intCast(ResultType, result_ty.of.i64),
            f32 => result_ty.of.f32,
            f64 => result_ty.of.f64,
            *Func => @ptrCast(?*Func, result_ty.of.ref).?,
            *Extern => @ptrCast(?*c.Extern, result_ty.of.ref).?,
            else => |ty| @compileError("Unsupported result type '" ++ @typeName(ty) ++ "'"),
        };
    }

    pub fn deinit(self: Func) void {
        self.inner.deinit();
    }

    extern "c" fn wasmtime_func_call(*wasm.Func, *const ValVec, *ValVec, *?*Trap) ?*WasmError;
    extern "c" fn wasm_func_result_arity(*const wasm.Func) usize;
    extern "c" fn wasm_func_param_arity(*const wasm.Func) usize;
};

pub const Instance = struct {
    inner: *wasm.Instance,

    /// Initializes a new `Instance` using the given `store` and `mode`.
    /// The given slice defined in `import` must match what was initialized
    /// using the same `Store` as given.
    pub fn init(store: *Store, module: Module, import: []const Func) !Instance {
        var trap: ?*Trap = null;
        var inner: ?*wasm.Instance = null;

        var imports = ExternVec.initWithCapacity(import.len);
        defer imports.deinit();

        var ptr = imports.data;
        for (import) |func| {
            ptr.* = func.inner.asExtern();
            ptr += 1;
        }

        const err = wasmtime_instance_new(store, module.inner, &imports, &inner, &trap);

        if (err) |e| {
            defer e.deinit();
            var msg = e.getMessage();
            defer msg.deinit();

            log.err("unexpected error occurred: '{s}'", .{msg.toSlice()});
            return Error.InstanceInit;
        }

        if (trap) |t| {
            defer t.deinit();
            // TODO handle trap message
            log.err("code unexpectedly trapped", .{});
            return Error.InstanceInit;
        }

        return Instance{
            .inner = inner.?,
        };
    }

    pub fn getExportFunc(self: Instance, name: []const u8) ?Func {
        var inner = self.inner.getExportFunc(name) orelse return null;
        return Func{ .inner = inner };
    }

    pub fn getExportMem(self: Instance, name: []const u8) ?*Memory {
        return self.inner.getExportMem(name);
    }

    pub fn deinit(self: Instance) void {
        self.inner.deinit();
    }

    extern "c" fn wasmtime_instance_new(*Store, *const wasm.Module, *const ExternVec, *?*wasm.Instance, *?*Trap) ?*WasmError;
};

pub const InterruptHandle = opaque {
    /// Creates a new interrupt handle.
    /// Must be freed by calling `deinit()`
    pub fn init(store: *Store) !*InterruptHandle {
        return wasmtime_interrupt_handle_new(store) orelse error.InterruptsNotEnabled;
    }
    /// Invokes an interrupt in the current wasm module
    pub fn interrupt(self: *InterruptHandle) void {
        wasmtime_interrupt_handle_interrupt(self);
    }

    pub fn deinit(self: *InterruptHandle) void {
        wasmtime_interrupt_handle_delete(self);
    }

    extern "c" fn wasmtime_interrupt_handle_interrupt(*InterruptHandle) void;
    extern "c" fn wasmtime_interrupt_handle_delete(*InterruptHandle) void;
    extern "c" fn wasmtime_interrupt_handle_new(*Store) ?*InterruptHandle;
};

pub const Linker = opaque {
    pub fn init(store: *Store) !*Linker {
        return wasmtime_linker_new(store) orelse error.LinkerInit;
    }

    pub fn deinit(self: *Linker) void {
        wasmtime_linker_delete(self);
    }

    /// Defines a `WasiInstance` for the current `Linker`
    pub fn defineWasi(self: *Linker, wasi: *const WasiInstance) ?*WasmError {
        return wasmtime_linker_define_wasi(self, wasi);
    }

    /// Defines an `Instance` for the current `Linker` object using the given `name`
    pub fn defineInstance(self: *Linker, name: *const NameVec, instance: *const wasm.Instance) ?*WasmError {
        return wasmtime_linker_define_instance(self, name, instance);
    }

    /// Instantiates the `Linker` for the given `Module` and creates a new `Instance` for it
    /// Returns a `WasmError` when failed to instantiate
    pub fn instantiate(
        self: *const Linker,
        module: Module,
        instance: *?*wasm.Instance,
        trap: *?*Trap,
    ) ?*WasmError {
        return wasmtime_linker_instantiate(self, module.inner, instance, trap);
    }

    extern "c" fn wasmtime_linker_new(*Store) ?*Linker;
    extern "c" fn wasmtime_linker_delete(*Linker) void;
    extern "c" fn wasmtime_linker_define_wasi(*Linker, *const WasiInstance) ?*WasmError;
    extern "c" fn wasmtime_linker_define_instance(*Linker, *const NameVec, *const wasm.Instance) ?*WasmError;
    extern "c" fn wasmtime_linker_instantiate(*const Linker, *const wasm.Module, *?*wasm.Instance, *?*Trap) ?*WasmError;
};

test "" {
    testing.refAllDecls(@This());
}
