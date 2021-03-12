const std = @import("std");
const testing = std.testing;
const meta = std.meta;
const trait = std.meta.trait;
const log = std.log.scoped(.wasmtime_zig);

pub const c = @import("c.zig");

var CALLBACK: usize = undefined;

// @TODO: Split these up into own error sets
pub const Error = error{
    /// Failed to initialize an `Engine` (i.e. invalid config)
    EngineInit,
    /// Failed to initialize a `Store`
    StoreInit,
    /// Failed to initialize a `Module`
    ModuleInit,
    /// Failed to create a wasm function based on
    /// the given `Store` and functype
    FuncInit,
    /// Failed to initialize a new `Instance`
    InstanceInit,
    /// When the user provided a different ResultType to `Func.call`
    /// than what is defined by the wasm binary
    InvalidResultType,
    /// The given argument count to `Func.call` mismatches that
    /// of the func argument count of the wasm binary
    InvalidParamCount,
    /// The wasm function number of results mismatch that of the given
    /// ResultType to `Func.Call`. Note that `void` equals to 0 result types.
    InvalidResultCount,
};

pub const Engine = opaque {
    /// Initializes a new `Engine`
    pub fn init() !*Engine {
        return wasm_engine_new() orelse Error.EngineInit;
    }

    /// Frees the resources of the `Engine`
    pub fn deinit(self: *Engine) void {
        wasm_engine_delete(self);
    }

    extern fn wasm_engine_new() ?*Engine;
    extern fn wasm_engine_delete(*Engine) void;
};

pub const Store = opaque {
    /// Initializes a new `Store` based on the given `Engine`
    pub fn init(engine: *Engine) !*Store {
        return wasm_store_new(engine) orelse Error.StoreInit;
    }

    /// Frees the resource of the `Store` itself
    pub fn deinit(self: *Store) void {
        wasm_store_delete(self);
    }

    extern fn wasm_store_new(*Engine) ?*Store;
    extern fn wasm_store_delete(*Store) void;
};

pub const Module = opaque {
    /// Initializes a new `Module` using the supplied engine and wasm bytecode
    pub fn initFromWasm(engine: *Engine, wasm: []const u8) !*Module {
        var wasm_bytes = c.ByteVec.initWithCapacity(wasm.len);
        defer wasm_bytes.deinit();

        var i: usize = 0;
        var ptr = wasm_bytes.data;
        while (i < wasm.len) : (i += 1) {
            ptr.* = wasm[i];
            ptr += 1;
        }

        return Module.init(engine, wasm_bytes);
    }

    /// Initializes a new `Module` by first converting the given wat format
    /// into wasm bytecode.
    pub fn initFromWat(engine: *Engine, wat: []const u8) !*Module {
        var wat_bytes = c.ByteVec.initWithCapacity(wat.len);
        defer wat_bytes.deinit();

        var i: usize = 0;
        var ptr = wat_bytes.data;
        while (i < wat.len) : (i += 1) {
            ptr.* = wat[i];
            ptr += 1;
        }

        var wasm_bytes: c.ByteVec = undefined;
        const err = c.wasmtime_wat2wasm(&wat_bytes, &wasm_bytes);
        defer if (err == null) wasm_bytes.deinit();

        if (err) |e| {
            defer e.deinit();
            var msg = e.getMessage();
            defer msg.deinit();

            log.err("unexpected error occurred: '{s}'", .{msg.toSlice()});
            return Error.ModuleInit;
        }

        return Module.init(engine, &wasm_bytes);
    }

    fn init(engine: *Engine, wasm_bytes: *c.ByteVec) !*Module {
        var module: ?*Module = undefined;
        const err = wasmtime_module_new(engine, wasm_bytes, &module);

        if (err) |e| {
            defer e.deinit();
            var msg = e.getMessage();
            defer msg.deinit();

            log.err("unexpected error occurred: '{s}'", .{msg.toSlice()});
            return Error.ModuleInit;
        }

        return module.?;
    }

    pub fn deinit(self: *Module) void {
        wasm_module_delete(self);
    }

    extern fn wasmtime_module_new(*Engine, *c.ByteVec, *?*Module) ?*c.WasmError;
    extern fn wasm_module_delete(*Module) void;
};

fn cb(params: ?*const c.Valtype, results: ?*c.Valtype) callconv(.C) ?*c.Trap {
    const func = @intToPtr(fn () void, CALLBACK);
    func();
    return null;
}

pub const Func = opaque {
    pub fn init(store: *Store, callback: anytype) !*Func {
        const cb_meta = @typeInfo(@TypeOf(callback));
        switch (cb_meta) {
            .Fn => {
                if (cb_meta.Fn.args.len > 0 or cb_meta.Fn.return_type.? != void) {
                    @compileError("only callbacks with no input args and no results are currently supported");
                }
            },
            else => @compileError("only functions can be used as callbacks into Wasm"),
        }
        CALLBACK = @ptrToInt(callback);

        var args = c.ValtypeVec.empty();
        var results = c.ValtypeVec.empty();

        const functype = c.wasm_functype_new(&args, &results) orelse return Error.FuncInit;
        defer c.wasm_functype_delete(functype);

        return wasm_func_new(store, functype, cb) orelse Error.FuncInit;
    }

    /// Returns the `Func` as an `c.Extern`
    ///
    /// Owned by `self` and shouldn't be deinitialized
    pub fn asExtern(self: *Func) *c.Extern {
        return wasm_func_as_extern(self).?;
    }

    /// Returns the `Func` from an `c.Extern`
    /// return null if extern's type isn't a functype
    ///
    /// Owned by `extern_func` and shouldn't be deinitialized
    pub fn fromExtern(extern_func: *c.Extern) ?*Func {
        return @ptrCast(?*Func, extern_func.asFunc());
    }

    /// Creates a copy of the current `Func`
    /// returned copy is owned by the caller and must be freed
    /// by the owner
    pub fn copy(self: *Func) *Func {
        return self.wasm_func_copy().?;
    }

    /// Tries to call the wasm function
    /// expects `args` to be tuple of arguments
    pub fn call(self: *Func, comptime ResultType: type, args: anytype) !ResultType {
        if (!comptime trait.isTuple(@TypeOf(args)))
            @compileError("Expected 'args' to be a tuple, but found type '" ++ @typeName(@TypeOf(args)) ++ "'");

        const args_len = args.len;
        comptime var wasm_args: [args_len]c.Value = undefined;
        inline for (wasm_args) |*arg, i| {
            arg.* = switch (@TypeOf(args[i])) {
                i32, u32 => .{ .kind = .i32, .of = .{ .i32 = @intCast(i32, args[i]) } },
                i64, u64 => .{ .kind = .i64, .of = .{ .i64 = @intCast(i64, args[i]) } },
                f32 => .{ .kind = .f32, .of = .{ .f32 = args[i] } },
                f64 => .{ .kind = .f64, .of = .{ .f64 = args[i] } },
                *Func => .{ .kind = .funcref, .of = .{ .ref = args[i] } },
                *c.Extern => .{ .kind = .anyref, .of = .{ .ref = args[i] } },
                else => |ty| @compileError("Unsupported argument type '" ++ @typeName(ty) + "'"),
            };
        }

        // TODO multiple return values
        const result_len: usize = if (ResultType == void) 0 else 1;
        if (result_len != self.wasm_func_result_arity()) return Error.InvalidResultCount;
        if (args_len != self.wasm_func_param_arity()) return Error.InvalidParamCount;

        const final_args = c.ValVec{
            .size = args_len,
            .data = if (args_len == 0) undefined else @ptrCast([*]c.Value, &wasm_args),
        };

        var trap: ?*c.Trap = null;
        var result_list = c.ValVec.initWithCapacity(result_len);
        defer result_list.deinit();
        const err = wasmtime_func_call(self, &final_args, &result_list, &trap);

        if (err) |e| {
            defer e.deinit();
            var msg = e.getMessage();
            defer msg.deinit();

            log.err("Unable to call function: '{s}'", .{msg.toSlice()});
            return Error.InstanceInit;
        }
        if (trap) |t| {
            t.deinit();
            // TODO handle trap message
            log.err("code unexpectedly trapped", .{});
            return Error.InstanceInit;
        }

        if (ResultType == void) return;

        // TODO: Handle multiple returns
        const result_ty = result_list.data[0];
        if (!matchesKind(ResultType, result_ty.kind)) return Error.InvalidResultType;

        return switch (ResultType) {
            i32, u32 => @intCast(ResultType, result_ty.of.i32),
            i64, u64 => @intCast(ResultType, result_ty.of.i64),
            f32 => result_ty.of.f32,
            f64 => result_ty.of.f64,
            *Func => @ptrCast(?*Func, result_ty.of.ref).?,
            *c.Extern => @ptrCast(?*c.Extern, result_ty.of.ref).?,
            else => |ty| @compileError("Unsupported result type '" ++ @typeName(ty) ++ "'"),
        };
    }

    /// Returns tue if the given `kind` of `c.Valkind` can coerce to type `T`
    fn matchesKind(comptime T: type, kind: c.Valkind) bool {
        return switch (T) {
            i32, u32 => kind == .i32,
            i64, u64 => kind == .i64,
            f32 => kind == .f32,
            f64 => kind == .f64,
            *Func => kind == .funcref,
            *c.Extern => kind == .ref,
            else => false,
        };
    }

    extern fn wasm_func_new(*Store, functype: ?*c_void, callback: c.Callback) ?*Func;
    extern fn wasm_func_as_extern(*Func) ?*c.Extern;
    extern fn wasm_func_copy(*Func) ?*Func;
    extern fn wasmtime_func_call(
        ?*Func,
        args: *const c.ValVec,
        results: *c.ValVec,
        trap: *?*c.Trap,
    ) ?*c.WasmError;
    extern fn wasm_func_result_arity(*Func) usize;
    extern fn wasm_func_param_arity(*Func) usize;
};

pub const Instance = opaque {
    /// Initializes a new `Instance` using the given `store` and `mode`.
    /// The given slice defined in `import` must match what was initialized
    /// using the same `Store` as given.
    pub fn init(store: *Store, module: *Module, import: []const *Func) !*Instance {
        var trap: ?*c.Trap = null;
        var instance: ?*Instance = null;

        var imports = c.ExternVec.initWithCapacity(import.len);
        defer imports.deinit();

        var ptr = imports.data;
        for (import) |func| {
            ptr.* = func.asExtern();
            ptr += 1;
        }

        const err = wasmtime_instance_new(store, module, &imports, &instance, &trap);

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

        return instance.?;
    }

    /// Returns an export by its name if found
    /// returns null if not found
    /// The returned `Func` is a copy and must be freed by the caller
    pub fn getExportFunc(self: *Instance, name: []const u8) ?*Func {
        var externs: c.ExternVec = undefined;
        self.wasm_instance_exports(&externs);
        defer externs.deinit();

        const instance_type = self.getType();
        defer instance_type.deinit();

        var type_exports = instance_type.exports();
        defer type_exports.deinit();

        return for (type_exports.toSlice()) |ty, index| {
            const t = ty orelse continue;
            const type_name = t.name();
            defer type_name.deinit();

            if (std.mem.eql(u8, name, type_name.toSlice())) {
                const ext = externs.data[index] orelse return null;
                break Func.fromExtern(ext).?.copy();
            }
        } else null;
    }

    /// Returns the `c.InstanceType` of the `Instance`
    pub fn getType(self: *Instance) *c.InstanceType {
        return self.wasm_instance_type().?;
    }

    /// Frees the `Instance`'s resources
    pub fn deinit(self: *Instance) void {
        self.wasm_instance_delete();
    }

    extern fn wasmtime_instance_new(
        store: *Store,
        module: *const Module,
        imports: *const c.ExternVec,
        instance: *?*Instance,
        trap: *?*c.Trap,
    ) ?*c.WasmError;
    extern fn wasmtime_instance_delete(*Instance) void;
    extern fn wasm_instance_exports(*Instance, *c.ExternVec) void;
    extern fn wasm_instance_type(*const Instance) ?*c.InstanceType;
};

test "" {
    testing.refAllDecls(@This());
}
