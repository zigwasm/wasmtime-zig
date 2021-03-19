const Store = @import("main.zig").Store;
const Module = @import("main.zig").Module;
const Func = @import("main.zig").Func;
const Instance = @import("main.zig").Instance;

pub const WasmError = opaque {
    /// Gets the error message
    pub fn getMessage(self: *WasmError) ByteVec {
        var bytes: ByteVec = undefined;
        wasmtime_error_message(self, &bytes);
        return bytes;
    }

    /// Frees the error resources
    pub fn deinit(self: *WasmError) void {
        wasmtime_error_delete(self);
    }

    extern fn wasmtime_error_delete(*WasmError) void;
    extern fn wasmtime_error_message(*WasmError, *ByteVec) void;
};

pub const Trap = opaque {
    pub fn deinit(self: *Trap) void {
        wasm_trap_delete(self);
    }

    extern fn wasm_trap_delete(*Trap) void;
};

pub const Extern = opaque {
    /// Returns the `Extern` as a function
    pub fn asFunc(self: *Extern) ?*Func {
        return wasm_extern_as_func(self);
    }

    extern fn wasm_extern_as_func(external: *c_void) ?*Func;
};

pub const ExportType = opaque {
    pub fn name(self: *ExportType) *ByteVec {
        return self.wasm_exporttype_name().?;
    }
    extern fn wasm_exporttype_name(*ExportType) ?*ByteVec;
};

pub const ExportTypeVec = extern struct {
    size: usize,
    data: [*]?*ExportType,

    pub fn toSlice(self: *const ExportTypeVec) []const ?*ExportType {
        return self.data[0..self.size];
    }

    pub fn deinit(self: *ExportTypeVec) void {
        self.wasm_exporttype_vec_delete();
    }

    extern fn wasm_exporttype_vec_delete(*ExportTypeVec) void;
};

pub const InstanceType = opaque {
    pub fn deinit(self: *InstanceType) void {
        self.wasm_instancetype_delete();
    }

    pub fn exports(self: *InstanceType) ExportTypeVec {
        var export_vec: ExportTypeVec = undefined;
        self.wasm_instancetype_exports(&export_vec);
        return export_vec;
    }

    extern fn wasm_instancetype_delete(*InstanceType) void;
    extern fn wasm_instancetype_exports(*InstanceType, ?*ExportTypeVec) void;
};

pub const Callback = fn (?*const Valtype, ?*Valtype) callconv(.C) ?*Trap;

// Bits
pub const ByteVec = extern struct {
    size: usize,
    data: [*]u8,

    /// Initializes a new wasm byte vector
    pub fn initWithCapacity(size: usize) ByteVec {
        var bytes: ByteVec = undefined;
        wasm_byte_vec_new_uninitialized(&bytes, size);
        return bytes;
    }

    /// Returns a slice to the byte vector
    pub fn toSlice(self: ByteVec) []const u8 {
        return self.data[0..self.size];
    }

    /// Frees the memory allocated by initWithCapacity
    pub fn deinit(self: *ByteVec) void {
        wasm_byte_vec_delete(self);
    }

    extern fn wasm_byte_vec_new_uninitialized(ptr: *ByteVec, size: usize) void;
    extern fn wasm_byte_vec_delete(ptr: *ByteVec) void;
};

pub const ExternVec = extern struct {
    size: usize,
    data: [*]?*Extern,

    pub fn empty() ExternVec {
        return .{ .size = 0, .data = undefined };
    }

    pub fn deinit(self: *ExternVec) void {
        wasm_extern_vec_delete(self);
    }

    pub fn initWithCapacity(size: usize) ExternVec {
        var externs: ExternVec = undefined;
        wasm_extern_vec_new_uninitialized(&externs, size);
        return externs;
    }

    extern fn wasm_extern_vec_new_empty(ptr: *ExternVec) void;
    extern fn wasm_extern_vec_new_uninitialized(ptr: *ExternVec, size: usize) void;
    extern fn wasm_extern_vec_delete(ptr: *ExternVec) void;
};

pub const Valkind = extern enum(u8) {
    i32 = 0,
    i64 = 1,
    f32 = 2,
    f64 = 3,
    anyref = 128,
    funcref = 129,
};

pub const Value = extern struct {
    kind: Valkind,
    of: extern union {
        i32: i32,
        i64: i64,
        f32: f32,
        f64: f64,
        ref: ?*c_void,
    },
};

pub const Valtype = opaque {
    /// Initializes a new `Valtype` based on the given `Valkind`
    pub fn init(kind: Valkind) *Valtype {
        return wasm_valtype_new(@enumToInt(kind));
    }

    pub fn deinit(self: *Valtype) void {
        wasm_valtype_delete(self);
    }

    /// Returns the `Valkind` of the given `Valtype`
    pub fn kind(self: *Valtype) Valkind {
        return @intToEnum(Valkind, wasm_valtype_kind(self));
    }

    extern fn wasm_valtype_new(kind: u8) *Valtype;
    extern fn wasm_valtype_delete(*Valkind) void;
    extern fn wasm_valtype_kind(*Valkind) u8;
};

pub const ValtypeVec = extern struct {
    size: usize,
    data: [*]?*Valtype,

    pub fn empty() ValtypeVec {
        return .{ .size = 0, .data = undefined };
    }
};

pub const ValVec = extern struct {
    size: usize,
    data: [*]Value,

    pub fn initWithCapacity(size: usize) ValVec {
        var bytes: ValVec = undefined;
        wasm_val_vec_new_uninitialized(&bytes, size);
        return bytes;
    }

    pub fn deinit(self: *ValVec) void {
        self.wasm_val_vec_delete();
    }

    extern fn wasm_val_vec_new_uninitialized(*ValVec, usize) void;
    extern fn wasm_val_vec_delete(*ValVec) void;
};

// Func
pub extern fn wasm_functype_new(args: *ValtypeVec, results: *ValtypeVec) ?*c_void;
pub extern fn wasm_functype_delete(functype: *c_void) void;

// Helpers
pub extern fn wasmtime_wat2wasm(wat: *ByteVec, wasm: *ByteVec) ?*WasmError;

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

    extern fn wasmtime_interrupt_handle_interrupt(?*InterruptHandle) void;
    extern fn wasmtime_interrupt_handle_delete(?*InterruptHandle) void;
    extern fn wasmtime_interrupt_handle_new(?*Store) ?*InterruptHandle;
};

pub const WasiConfig = opaque {
    /// Options to inherit when inherriting configs
    /// By default all is `true` as you often want to
    /// inherit everything rather than something specifically.
    const InheritOptions = struct {
        argv: bool = true,
        env: bool = true,
        std_in: bool = true,
        std_out: bool = true,
        std_err: bool = true,
    };

    pub fn init() !*WasiConfig {
        return wasi_config_new() orelse error.ConfigInit;
    }

    pub fn deinit(self: *WasiConfig) void {
        wasi_config_delete(self);
    }

    /// Allows to inherit the native environment into the current config.
    /// Inherits everything by default.
    pub fn inherit(self: *WasiConfig, options: InheritOptions) void {
        if (options.argv) self.inheritArgv();
        if (options.env) self.inheritEnv();
        if (options.std_in) self.inheritStdIn();
        if (options.std_out) self.inheritStdOut();
        if (options.std_err) self.inheritStdErr();
    }

    pub fn inheritArgv(self: *WasiConfig) void {
        wasi_config_inherit_argv(self);
    }

    pub fn inheritEnv(self: *WasiConfig) void {
        wasi_config_inherit_env(self);
    }

    pub fn inheritStdIn(self: *WasiConfig) void {
        wasi_config_inherit_stdin(self);
    }

    pub fn inheritStdOut(self: *WasiConfig) void {
        wasi_config_inherit_stdout(self);
    }

    pub fn inheritStdErr(self: *WasiConfig) void {
        wasi_config_inherit_stderr(self);
    }

    extern fn wasi_config_new() ?*WasiConfig;
    extern fn wasi_config_delete(?*WasiConfig) void;
    extern fn wasi_config_inherit_argv(?*WasiConfig) void;
    extern fn wasi_config_inherit_env(?*WasiConfig) void;
    extern fn wasi_config_inherit_stdin(?*WasiConfig) void;
    extern fn wasi_config_inherit_stdout(?*WasiConfig) void;
    extern fn wasi_config_inherit_stderr(?*WasiConfig) void;
};

pub const WasiInstance = opaque {
    pub fn init(store: *Store, name: [*:0]const u8, config: ?*WasiConfig, trap: *?*Trap) !*WasiInstance {
        return wasi_instance_new(store, name, config, trap) orelse error.InstanceInit;
    }

    pub fn deinit(self: *WasiInstance) void {
        was_instance_delete(self);
    }

    extern fn wasi_instance_new(?*Store, [*:0]const u8, ?*WasiConfig, *?*Trap) ?*WasiInstance;
    extern fn was_instance_delete(?*WasiInstance) void;
};

pub const Linker = opaque {
    pub fn init(store: *Store) !*Linker {
        return wasmtime_linker_new(store) orelse error.LinkerInit;
    }

    pub fn deinit(self: *Linker) void {
        wasmtime_linker_delete(self);
    }

    pub fn defineWasi(self: *Linker, wasi: *const WasiInstance) ?*WasmError {
        return wasmtime_linker_define_wasi(self, wasi);
    }

    pub fn defineInstance(self: *Linker, name: *const ByteVec, instance: *const Instance) ?*WasmError {
        wasmtime_linker_define_instance(self, name, instance);
    }

    pub fn instantiate(
        self: *const Linker,
        module: *const Module,
        instance: *?*Instance,
        trap: *?*Trap,
    ) ?*WasmError {
        return wasmtime_linker_instantiate(self, module, instance, trap);
    }

    extern fn wasmtime_linker_new(?*Store) ?*Linker;
    extern fn wasmtime_linker_delete(?*Linker) void;
    extern fn wasmtime_linker_define_wasi(?*Linker, ?*const WasiInstance) ?*WasmError;
    extern fn wasmtime_linker_define_instance(?*Linker, ?*const ByteVec, ?*const Instance) ?*WasmError;
    extern fn wasmtime_linker_instantiate(
        linker: ?*const Linker,
        module: ?*const Module,
        instance: *?*Instance,
        trap: *?*Trap,
    ) ?*WasmError;
};
