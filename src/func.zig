const std = @import("std");

pub const Config = @import("./config.zig").Config;
pub const Error = @import("./error.zig").Error;
pub const Engine = @import("engine.zig").Engine;
pub const Store = @import("./store.zig").Store;
pub const Convert = @import("./utils.zig").Convert;
pub const WasmError = @import("./utils.zig").WasmError;

pub const wasm = @import("wasm");

const log = std.log.scoped(.wasmtime_zig);

pub const ValVec = wasm.ByteVec;
pub const Trap = wasm.Trap;

pub const Func = struct {
    inner: *wasm.Func,

    pub const CallError = wasm.Func.CallError;

    pub fn init(store: *Store, callback: anytype) !Func {
        return Func{
            .inner = try wasm.Func.init(store.inner, callback),
        };
    }

    pub fn call(self: Func, store: *Store, comptime ResultType: type, args: anytype) CallError!ResultType {
        if (!comptime trait.isTuple(@TypeOf(args)))
            @compileError("Expected 'args' to be a tuple, but found type '" ++ @typeName(@TypeOf(args)) ++ "'");

        const args_len = args.len;
        comptime var wasm_args: [args_len]Value = undefined;
        inline for (wasm_args) |*arg, i| {
            arg.* = switch (@TypeOf(args[i])) {
                i32, u32 => .{ .kind = .i32, .of = .{ .i32 = @bitCast(i32, args[i]) } },
                i64, u64 => .{ .kind = .i64, .of = .{ .i64 = @bitCast(i64, args[i]) } },
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

        var trap: ?*wasm.Trap = null;
        var result_list = ValVec.initWithCapacity(result_len);
        defer result_list.deinit();

        const err = wasmtime_func_call(store.inner, // wasmtime_context_t *store,
            self.inner, // const wasmtime_func_t *func,
            &final_args, // const wasmtime_val_t *args,
            final_args.size, // size_t nargs,
            &result_list, // wasmtime_val_t *results,
            result_list.size, // size_t nresults,
            &trap // wasm_trap_t **trap
        );

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
            *Extern => @ptrCast(?*Extern, result_ty.of.ref).?,
            else => |ty| @compileError("Unsupported result type '" ++ @typeName(ty) ++ "'"),
        };
    }

    pub fn deinit(self: Func) void {
        self.inner.deinit();
    }

    //  \brief Call a WebAssembly function.
    //
    //  This function is used to invoke a function defined within a store. For
    //  example this might be used after extracting a function from a
    //  #wasmtime_instance_t.
    //
    //  \param store the store which owns `func`
    //  \param func the function to call
    //  \param args the arguments to the function call
    //  \param nargs the number of arguments provided
    //  \param results where to write the results of the function call
    //  \param nresults the number of results expected
    //  \param trap where to store a trap, if one happens.
    //
    //  There are three possible return states from this function:
    //
    //  1. The returned error is non-null. This means `results`
    //     wasn't written to and `trap` will have `NULL` written to it. This state
    //     means that programmer error happened when calling the function, for
    //     example when the size of the arguments/results was wrong, the types of the
    //     arguments were wrong, or arguments may come from the wrong store.
    //  2. The trap pointer is filled in. This means the returned error is `NULL` and
    //     `results` was not written to. This state means that the function was
    //     executing but hit a wasm trap while executing.
    //  3. The error and trap returned are both `NULL` and `results` are written to.
    //     This means that the function call succeeded and the specified results were
    //     produced.
    //
    //  The `trap` pointer cannot be `NULL`. The `args` and `results` pointers may be
    //  `NULL` if the corresponding length is zero.
    //
    //  Does not take ownership of #wasmtime_val_t arguments. Gives ownership of
    //  #wasmtime_val_t results.
    //
    extern "c" fn wasmtime_func_call(
        *wasm.Store, // wasmtime_context_t *store,
        *wasm.Func, // const wasmtime_func_t *func,
        *const wasm.ValVec, // const wasmtime_val_t *args,
        usize, // size_t nargs,
        *wasm.ValVec, // wasmtime_val_t *results,
        usize, // size_t nresults,
        *wasm.Trap, // wasm_trap_t **trap
    ) ?*WasmError;
    extern "c" fn wasm_func_result_arity(*const wasm.Func) usize;
    extern "c" fn wasm_func_param_arity(*const wasm.Func) usize;
};
