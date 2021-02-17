const std = @import("std");
const testing = std.testing;
const log = std.log.scoped(.wasmtime_zig);

pub const c = @import("c.zig");

var CALLBACK: usize = undefined;

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
        errdefer err.?.deinit();
        defer wasm_bytes.deinit();

        if (err) |e| {
            var msg = e.getMessage();
            defer msg.deinit();

            // TODO print error message
            log.err("unexpected error occurred", .{});
            return Error.ModuleInit;
        }

        return Module.init(engine, &wasm_bytes);
    }

    fn init(engine: *Engine, wasm_bytes: *c.ByteVec) !*Module {
        var module: ?*Module = undefined;
        const err = wasmtime_module_new(engine, wasm_bytes, &module);
        errdefer err.?.deinit();

        if (err) |e| {
            var msg = e.getMessage();
            defer msg.deinit();

            // TODO print error message
            log.err("unexpected error occurred", .{});
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

fn cb(params: ?*const c.wasm_val_t, results: ?*c.wasm_val_t) callconv(.C) ?*c_void {
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
    pub fn asExtern(self: *Func) ?*c.Extern {
        return wasm_func_as_extern(self);
    }

    /// Returns the `Func` from an `c.Extern`
    pub fn fromExtern(extern_func: *c.Extern) ?*Func {
        return @ptrCast(?*Func, extern_func.asFunc());
    }

    /// Returns an owned copy of the current `Func`
    pub fn copy(self: *Func) ?*Func {
        return self.wasm_func_copy();
    }

    /// Tries to call the wasm function
    pub fn call(self: *Func) !void {
        var trap: ?*c.Trap = null;
        const err = wasmtime_func_call(self, null, 0, null, 0, &trap);
        errdefer {
            if (err) |e| e.deinit();
            if (trap) |t| t.deinit();
        }

        if (err) |e| {
            var msg = e.getMessage();
            defer msg.deinit();

            // TODO print error message
            log.err("Unable to call function: {s}", .{msg.toSlice()});
            return Error.InstanceInit;
        }
        if (trap) |t| {
            // TODO handle trap message
            log.err("code unexpectedly trapped", .{});
            return Error.InstanceInit;
        }
    }

    extern fn wasm_func_new(*Store, functype: ?*c_void, callback: c.Callback) ?*Func;
    extern fn wasm_func_as_extern(*Func) ?*c.Extern;
    extern fn wasm_func_copy(*Func) ?*Func;
    extern fn wasmtime_func_call(
        *Func,
        args: ?*const c.wasm_val_t,
        args_size: usize,
        results: ?*c.wasm_val_t,
        results_size: usize,
        trap: *?*c.Trap,
    ) ?*c.WasmError;
};

pub const Instance = opaque {
    // TODO accepts a list of imports
    pub fn init(store: *Store, module: *Module, import: *Func) !*Instance {
        var trap: ?*c.Trap = null;
        var instance: ?*Instance = null;
        const imports = [_]?*c.Extern{import.asExtern()};

        const err = wasmtime_instance_new(store, module, &imports, 1, &instance, &trap);
        errdefer {
            if (err) |e| e.deinit();
            if (trap) |t| t.deinit();
        }

        if (err) |e| {
            var msg = e.getMessage();
            defer msg.deinit();

            // TODO print error message
            log.err("unexpected error occurred", .{});
            return Error.InstanceInit;
        }
        if (trap) |t| {
            // TODO handle trap message
            log.err("code unexpectedly trapped", .{});
            return Error.InstanceInit;
        }

        return instance.?;
    }

    pub fn getFirstFuncExport(self: *Instance) !?*Func {
        var externs: c.wasm_extern_vec_t = undefined;
        wasm_instance_exports(self, &externs);
        defer c.wasm_extern_vec_delete(&externs);

        // TODO handle finding the export by name.
        const run_func = Func.fromExtern(externs.data[0].?) orelse return null;
        const owned = run_func.copy();
        return owned.?;
    }

    pub fn deinit(self: *Instance) void {
        self.wasm_instance_delete();
    }

    extern fn wasmtime_instance_new(
        store: *Store,
        module: *const Module,
        imports: [*]const ?*const c.Extern,
        size: usize,
        instance: *?*Instance,
        trap: *?*c.Trap,
    ) ?*c.WasmError;
    extern fn wasmtime_instance_delete(*Instance) void;
    extern fn wasm_instance_exports(*Instance, *c.wasm_extern_vec_t) void;
};

test "" {
    testing.refAllDecls(@This());
}
