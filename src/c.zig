const Store = @import("main.zig").Store;
const Module = @import("main.zig").Module;
const Func = @import("main.zig").Func;
const Instance = @import("main.zig").Instance;

pub const WasmError = opaque {
    /// Gets the error message
    pub fn getMessage(self: *WasmError) *ByteVec {
        var bytes: ?*ByteVec = null;
        wasmtime_error_message(self, &bytes);
        return bytes.?;
    }

    /// Frees the error resources
    pub fn deinit(self: *WasmError) void {
        wasmtime_error_delete(self);
    }

    extern fn wasmtime_error_delete(*WasmError) void;
    extern fn wasmtime_error_message(?*const WasmError, *?*ByteVec) void;
};

pub const Trap = opaque {
    pub fn deinit(self: *Trap) void {
        wasm_trap_delete(self);
    }

    /// Returns the trap message.
    /// Memory of the returned `ByteVec` must be freed using `deinit`
    pub fn message(self: *Trap) *ByteVec {
        var bytes: ?*ByteVec = null;
        wasm_trap_message(&bytes);
        return bytes.?;
    }

    extern fn wasm_trap_delete(*Trap) void;
    extern fn wasm_trap_message(?*const Trap, out: *?*ByteVec) void;
};

pub const Extern = opaque {
    /// Returns the `Extern` as a function
    /// returns `null` when the given `Extern` is not a function
    ///
    /// Asserts `Extern` is of type `Func`
    pub fn asFunc(self: *Extern) *Func {
        return wasm_extern_as_func(self).?;
    }

    /// Returns the `Extern` as a `Memory` object
    /// returns `null` when the given `Extern` is not a memory object
    ///
    /// Asserts `Extern` is of type `Memory`
    pub fn asMemory(self: *Extern) *Memory {
        return wasm_extern_as_memory(self).?;
    }

    /// Returns the `Extern` as a `Global`
    /// returns `null` when the given `Extern` is not a global
    ///
    /// Asserts `Extern` is of type `Global`
    pub fn asGlobal(self: *Extern) *Global {
        return wasm_extern_as_global(self).?;
    }

    /// Returns the `Extern` as a `Table`
    /// returns `null` when the given `Extern` is not a table
    ///
    /// Asserts `Extern` is of type `Table`
    pub fn asTable(self: *Extern) *Table {
        return wasm_extern_as_table(self).?;
    }

    /// Frees the memory of the `Extern`
    pub fn deinit(self: *Extern) void {
        wasm_extern_delete(self);
    }

    /// Creates a copy of the `Extern` and returns it
    /// Memory of the copied version must be freed manually by calling `deinit`
    ///
    /// Asserts the copy succeeds
    pub fn copy(self: *Extern) *Extern {
        return wasm_extern_copy(self).?;
    }

    /// Checks if the given externs are equal and returns true if so
    pub fn eql(self: *const Extern, other: *const Extern) bool {
        return wasm_extern_same(self, other);
    }

    extern fn wasm_extern_as_func(?*Extern) ?*Func;
    extern fn wasm_extern_as_memory(?*Extern) ?*Memory;
    extern fn wasm_extern_as_global(?*Extern) ?*Global;
    extern fn wasm_extern_as_table(?*Extern) ?*Table;
    extern fn wasm_extern_delete(?*Extern) void;
    extern fn wasm_extern_copy(?*Extern) ?*Extern;
    extern fn wasm_extern_same(?*const Extern, ?*const Extern) bool;
};

pub const Memory = opaque {
    /// Creates a new `Memory` object for the given `Store` and `MemoryType`
    pub fn init(store: *Store, mem_type: *const MemoryType) !*Memory {
        return wasm_memory_new(store, mem_type) orelse error.MemoryInit;
    }

    /// Returns the `MemoryType` of a given `Memory` object
    pub fn getType(self: *const Memory) *MemoryType {
        return wasm_memory_type(self).?;
    }

    /// Frees the memory of the `Memory` object
    pub fn deinit(self: *Memory) void {
        wasm_memory_delete(self);
    }

    /// Creates a copy of the given `Memory` object
    /// Returned copy must be freed manually.
    pub fn copy(self: *const Memory) ?*Memory {
        return wasm_memory_copy(self);
    }

    /// Returns true when the given `Memory` objects are equal
    pub fn eql(self: *const Memory, other: *const Memory) bool {
        return wasm_memory_same(self, other);
    }

    /// Returns a pointer-to-many bytes
    ///
    /// Tip: Use toSlice() to get a slice for better ergonomics
    pub fn data(self: *Memory) [*]u8 {
        return wasm_memory_data(self);
    }

    /// Returns the data size of the `Memory` object.
    pub fn size(self: *const Memory) usize {
        return wasm_memory_data_size(self);
    }

    /// Returns the amount of pages the `Memory` object consists of
    /// where each page is 65536 bytes
    pub fn pages(self: *const Memory) u32 {
        return wasm_memory_size(self);
    }

    /// Convenient helper function to represent the memory
    /// as a slice of bytes. Memory is however still owned by wasm
    /// and must be freed by calling `deinit` on the original `Memory` object
    pub fn toSlice(self: *Memory) []const u8 {
        var slice: []const u8 = undefined;
        slice.ptr = self.data();
        slice.len = self.size();
        return slice;
    }

    /// Increases the amount of memory pages by the given count.
    pub fn grow(self: *Memory, page_count: u32) error{OutOfMemory}!void {
        if (!wasm_memory_grow(self, page_count)) return error.OutOfMemory;
    }

    extern fn wasm_memory_delete(?*Memory) void;
    extern fn wasm_memory_copy(?*const Memory) ?*Memory;
    extern fn wasm_memory_same(?*const Memory, ?*const Memory) bool;
    extern fn wasm_memory_new(?*Store, ?*const MemoryType) ?*Memory;
    extern fn wasm_memory_type(?*const Memory) ?*MemoryType;
    extern fn wasm_memory_data(?*Memory) [*]u8;
    extern fn wasm_memory_data_size(?*const Memory) usize;
    extern fn wasm_memory_grow(?*Memory, delta: u32) bool;
    extern fn wasm_memory_size(?*const Memory) u32;
};

pub const Limits = extern struct {
    min: u32,
    max: u32,
};

pub const MemoryType = opaque {
    pub fn init(limits: Limits) !*MemoryType {
        return wasm_memorytype_new(&limits) orelse return error.InitMemoryType;
    }

    pub fn deinit(self: *MemoryType) void {
        wasm_memorytype_delete(self);
    }

    extern fn wasm_memorytype_new(*const Limits) ?*MemoryType;
    extern fn wasm_memorytype_delete(?*MemoryType) void;
};

// TODO: implement table and global types
pub const Table = opaque {};
pub const Global = opaque {};

pub const ExportType = opaque {
    /// Returns the name of the given `ExportType`
    pub fn name(self: *ExportType) *ByteVec {
        return self.wasm_exporttype_name().?;
    }
    extern fn wasm_exporttype_name(*ExportType) ?*ByteVec;
};

pub const ExportTypeVec = extern struct {
    size: usize,
    data: [*]?*ExportType,

    /// Returns a slice of an `ExportTypeVec`
    /// memory is still owned by wasmtime and can only be freed using
    /// `deinit()` on the original `ExportTypeVec`
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

    /// Returns a vector of `ExportType` in a singular type `ExportTypeVec`
    pub fn exports(self: *InstanceType) ExportTypeVec {
        var export_vec: ExportTypeVec = undefined;
        self.wasm_instancetype_exports(&export_vec);
        return export_vec;
    }

    extern fn wasm_instancetype_delete(*InstanceType) void;
    extern fn wasm_instancetype_exports(*InstanceType, ?*ExportTypeVec) void;
};

pub const Callback = fn (?*const Valtype, ?*Valtype) callconv(.C) ?*Trap;

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

pub const NameVec = extern struct {
    size: usize,
    data: [*]const u8,

    pub fn fromSlice(slice: []const u8) NameVec {
        return .{ .size = slice.len, .data = slice.ptr };
    }
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
        wasm_instance_delete(self);
    }

    extern fn wasi_instance_new(?*Store, [*:0]const u8, ?*WasiConfig, *?*Trap) ?*WasiInstance;
    extern fn wasm_instance_delete(?*WasiInstance) void;
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
    pub fn defineInstance(self: *Linker, name: *const NameVec, instance: *const Instance) ?*WasmError {
        return wasmtime_linker_define_instance(self, name, instance);
    }

    /// Instantiates the `Linker` for the given `Module` and creates a new `Instance` for it
    /// Returns a `WasmError` when failed to instantiate
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
    extern fn wasmtime_linker_define_instance(?*Linker, ?*const NameVec, ?*const Instance) ?*WasmError;
    extern fn wasmtime_linker_instantiate(
        linker: ?*const Linker,
        module: ?*const Module,
        instance: *?*Instance,
        trap: *?*Trap,
    ) ?*WasmError;
};
