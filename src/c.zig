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
    pub fn asFunc(self: *Extern) ?*c_void {
        return wasm_extern_as_func(self);
    }
};

pub const Callback = fn (?*const wasm_val_t, ?*wasm_val_t) callconv(.C) ?*c_void;

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
};

// pub const ByteVec = ByteVec;

pub extern fn wasm_byte_vec_new_uninitialized(ptr: *ByteVec, size: usize) void;
extern fn wasm_byte_vec_delete(ptr: *ByteVec) void;

pub const wasm_extern_vec_t = extern struct {
    size: usize,
    data: [*]?*Extern,
};

pub extern fn wasm_extern_vec_new_empty(ptr: *wasm_extern_vec_t) void;
pub extern fn wasm_extern_vec_new_uninitialized(ptr: *wasm_extern_vec_t, size: usize) void;
pub extern fn wasm_extern_vec_delete(ptr: *wasm_extern_vec_t) void;

pub const wasm_valkind_t = u8;
pub const VALKIND_WASM_I32 = 0;
pub const VALKIND_WASM_I64 = 1;
pub const VALKIND_WASM_F32 = 2;
pub const VALKIND_WASM_F64 = 3;
pub const VALKIND_WASM_ANYREF = 128;
pub const VALKIND_WASM_FUNCREF = 129;

pub const wasm_val_t = extern struct {
    kind: wasm_valkind_t,
    of: extern union {
        int32: i32,
        int64: i64,
        float32: f32,
        float64: f64,
        ref: *c_void,
    },
};

pub const wasm_valtype_vec_t = extern struct {
    size: usize,
    data: [*]?*c_void,

    pub fn empty() wasm_valtype_vec_t {
        var ptr: wasm_valtype_vec_t = undefined;
        wasm_valtype_vec_new_empty(&ptr);
        return ptr;
    }
};

pub const ValtypeVec = wasm_valtype_vec_t;

pub extern fn wasm_valtype_vec_new_empty(ptr: *wasm_valtype_vec_t) void;

// Engine
pub extern fn wasm_engine_delete(engine: *c_void) void;

// Store
pub extern fn wasm_store_new(engine: *c_void) ?*c_void;
pub extern fn wasm_store_delete(store: *c_void) void;

// Func
pub extern fn wasm_functype_new(args: *wasm_valtype_vec_t, results: *wasm_valtype_vec_t) ?*c_void;
pub extern fn wasm_functype_delete(functype: *c_void) void;

pub extern fn wasm_func_new(store: *c_void, functype: *c_void, callback: Callback) ?*c_void;
pub extern fn wasm_func_copy(func: *c_void) ?*c_void;

pub extern fn wasm_func_as_extern(func: *c_void) ?*c_void;
pub extern fn wasm_extern_as_func(external: *c_void) ?*c_void;

pub extern fn wasmtime_func_call(func: *c_void, args: ?*const wasm_val_t, args_size: usize, results: ?*wasm_val_t, results_size: usize, trap: *?*c_void) ?*WasmError;

// Error handling
pub extern fn wasm_trap_delete(trap: *c_void) void;

// Helpers
pub extern fn wasmtime_wat2wasm(wat: *ByteVec, wasm: *ByteVec) ?*WasmError;
