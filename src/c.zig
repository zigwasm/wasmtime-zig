pub const Callback = fn (?*const wasm_val_t, ?*wasm_val_t) callconv(.C) ?*c_void;

// Bits
pub const wasm_byte_vec_t = extern struct {
    size: usize,
    data: [*]u8,
};

pub extern fn wasm_byte_vec_new_uninitialized(ptr: *wasm_byte_vec_t, size: usize) void;
pub extern fn wasm_byte_vec_delete(ptr: *wasm_byte_vec_t) void;

pub const wasm_extern_vec_t = extern struct {
    size: usize,
    data: [*]?*c_void,
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
};

pub extern fn wasm_valtype_vec_new_empty(ptr: *wasm_valtype_vec_t) void;

// Engine
pub extern fn wasm_engine_new() ?*c_void;
pub extern fn wasm_engine_delete(engine: *c_void) void;

// Store
pub extern fn wasm_store_new(engine: *c_void) ?*c_void;
pub extern fn wasm_store_delete(store: *c_void) void;

// Module
pub extern fn wasmtime_module_new(engine: *c_void, wasm: *wasm_byte_vec_t, module: *?*c_void) ?*c_void;
pub extern fn wasm_module_delete(module: *c_void) void;

// Instance
pub extern fn wasm_instance_new(store: *c_void, module: *const c_void, imports: *const wasm_extern_vec_t, trap: *?*c_void) ?*c_void;
pub extern fn wasmtime_instance_new(store: *c_void, module: *const c_void, imports: *const wasm_extern_vec_t, instance: *?*c_void, trap: *?*c_void) ?*c_void;
pub extern fn wasm_instance_delete(instance: *c_void) void;
pub extern fn wasm_instance_exports(instance: *c_void, externs: *wasm_extern_vec_t) void;

// Func
pub extern fn wasm_functype_new(args: *wasm_valtype_vec_t, results: *wasm_valtype_vec_t) ?*c_void;
pub extern fn wasm_functype_delete(functype: *c_void) void;

pub extern fn wasm_func_new(store: *c_void, functype: *c_void, callback: Callback) ?*c_void;
pub extern fn wasm_func_copy(func: *c_void) ?*c_void;

pub extern fn wasm_func_as_extern(func: *c_void) ?*c_void;
pub extern fn wasm_extern_as_func(external: *c_void) ?*c_void;

pub extern fn wasmtime_func_call(func: *c_void, args: ?*const wasm_val_t, args_size: usize, results: ?*wasm_val_t, results_size: usize, trap: *?*c_void) ?*c_void;

// Error handling
pub extern fn wasmtime_error_delete(err: *c_void) void;
pub extern fn wasmtime_error_message(err: *c_void, msg: *wasm_byte_vec_t) void;
pub extern fn wasm_trap_delete(trap: *c_void) void;

// Helpers
pub extern fn wasmtime_wat2wasm(wat: *wasm_byte_vec_t, wasm: *wasm_byte_vec_t) ?*c_void;
