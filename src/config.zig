const std = @import("std");
const Error = @import("error.zig").Error;
pub const wasm = @import("wasm");

// wasmtime_strategy_t
// Strategy is the compilation strategies for wasmtime
pub const Strategy = enum(u8) {
    // WASMTIME_STRATEGY_AUTO
    // StrategyAuto will let wasmtime automatically pick an appropriate compilation strategy
    strategyAuto = 0,
    // WASMTIME_STRATEGY_CRANELIFT
    // StrategyCranelift will force wasmtime to use the Cranelift backend
    strategyCranelift = 1,
};

// wasmtime_opt_level_t
// OptLevel decides what degree of optimization wasmtime will perform on generated machine code
pub const OptLevel = enum(u8) {
    // WASMTIME_OPT_LEVEL_NONE
    // OptLevelNone will perform no optimizations
    optLevelNone = 0,
    // WASMTIME_OPT_LEVEL_SPEED
    // OptLevelSpeed will optimize machine code to be as fast as possible
    optLevelSpeed = 1,
    // WASMTIME_OPT_LEVEL_SPEED_AND_SIZE
    // OptLevelSpeedAndSize will optimize machine code for speed, but also optimize
    // to be small, sometimes at the cost of speed.
    optLevelSpeedAndSize = 2,
};

// wasmtime_profiling_strategy_t
// ProfilingStrategy decides what sort of profiling to enable, if any.
pub const ProfilerStrategy = enum(u8) {
    // WASMTIME_PROFILING_STRATEGY_NONE
    // profilingStrategyNone means no profiler will be used
    profilingStrategyNone = 0,
    // WASMTIME_PROFILING_STRATEGY_JITDUMP
    // profilingStrategyJitdump will use the "jitdump" linux support
    profilingStrategyJitdump = 1,
    // WASMTIME_PROFILING_STRATEGY_VTUNE
    // Support for VTune will be enabled and the VTune runtime will be informed,
    // at runtime, about JIT code.
    //
    // Note that this isn't always enabled at build time.
    profileingStrategyVTune = 2,
};

pub const Config = struct {
    inner: *wasm.Config,

    pub const Options = struct {
        debugInfo: bool = false,
        wasmThreads: bool = false,
        wasmReferenceTypes: bool = false,
        wasmSIMD: bool = false,
        wasmBulkMemory: bool = false,
        wasmMultiValue: bool = false,
        wasmMultiMemory: bool = false,
        wasmMemory64: bool = false,
        consumeFuel: bool = false,
        craneliftDebugVerifier: bool = false,
        // craneLiftOptLevel: OptLevel = OptLevel.optLevelNone,
        epochInterruption: bool = false,
    };

    pub fn init(options: Options) !Config {
        var config = Config{
            .inner = try wasm.Config.init(),
        };

        if (options.debugInfo) {
            config.setDebugInfo(true);
        }
        if (options.wasmThreads) {
            config.setWasmThreads(true);
        }
        if (options.wasmReferenceTypes) {
            config.setWasmReferenceTypes(true);
        }
        if (options.wasmSIMD) {
            config.setWasmSIMD(true);
        }
        if (options.wasmBulkMemory) {
            config.setWasmBulkMemory(true);
        }
        if (options.wasmMultiValue) {
            config.setWasmMultiValue(true);
        }
        if (options.wasmMultiMemory) {
            config.setWasmMultiMemory(true);
        }
        if (options.wasmMemory64) {
            config.setWasmMemory64(true);
        }
        if (options.consumeFuel) {
            config.setConsumeFuel(true);
        }
        if (options.craneliftDebugVerifier) {
            config.setCraneliftDebugVerifier(true);
        }
        // if (options.craneLiftOptLevel != undefined) { config.setCraneLiftOptLevel(options.craneLiftOptLevel); }
        if (options.epochInterruption) {
            try config.setEpochInterruption(true);
        }

        return config;
    }

    // pub fn deinit(self: *Config) void {
    //     wasm_config_delete(*self.inner);
    // }

    // setDebugInfo configures whether dwarf debug information for JIT code is enabled
    pub fn setDebugInfo(self: *Config, opt: bool) void {
        wasmtime_config_debug_info_set(self.inner, opt);
    }

    // setWasmThreads configures whether the wasm threads proposal is enabled
    pub fn setWasmThreads(self: *Config, opt: bool) void {
        wasmtime_config_wasm_threads_set(self.inner, opt);
    }

    // setWasmReferenceTypes configures whether the wasm reference types proposal is enabled
    pub fn setWasmReferenceTypes(self: *Config, opt: bool) void {
        wasmtime_config_wasm_reference_types_set(self.inner, opt);
    }

    // setWasmSIMD configures whether the wasm SIMD proposal is enabled
    pub fn setWasmSIMD(self: *Config, opt: bool) void {
        wasmtime_config_wasm_simd_set(self.inner, opt);
    }

    // setWasmBulkMemory configures whether the wasm bulk memory proposal is enabled
    pub fn setWasmBulkMemory(self: *Config, opt: bool) void {
        wasmtime_config_wasm_bulk_memory_set(self.inner, opt);
    }

    // setWasmMultiValue configures whether the wasm multi value proposal is enabled
    pub fn setWasmMultiValue(self: *Config, opt: bool) void {
        wasmtime_config_wasm_multi_value_set(self.inner, opt);
    }

    // setWasmMultiMemory configures whether the wasm multi memory proposal is enabled
    pub fn setWasmMultiMemory(self: *Config, opt: bool) void {
        wasmtime_config_wasm_multi_memory_set(self.inner, opt);
    }

    // setWasmMemory64 configures whether the wasm memory64 proposal is enabled
    pub fn setWasmMemory64(self: *Config, opt: bool) void {
        wasmtime_config_wasm_memory64_set(self.inner, opt);
    }

    // setConsumFuel configures whether fuel is enabled
    pub fn setConsumeFuel(self: *Config, opt: bool) void {
        wasmtime_config_consume_fuel_set(self.inner, opt);
    }

    // setStrategy configures what compilation strategy is used to compile wasm code
    pub fn setStrategy(self: *Config, strat: *Strategy) !void {
        return wasmtime_config_strategy_set(self.inner, strat) orelse Error.ConfigStrategySet;
    }

    // setCraneliftDebugVerifier configures whether the cranelift debug verifier will be active when
    // cranelift is used to compile wasm code.
    pub fn setCraneliftDebugVerifier(self: *Config, opt: bool) void {
        wasmtime_config_cranelift_debug_verifier_set(self.inner, opt);
    }

    // setCraneliftOptLevel configures the cranelift optimization level for generated code
    pub fn setCraneLiftOptLevel(self: *Config, level: *OptLevel) void {
        wasmtime_config_cranelift_opt_level_set(self.inner, level) orelse Error.ConfigOptLevelSet;
    }

    // setProfiler configures what profiler strategy to use for generated code
    pub fn setProfiler(self: *Config, profiler: *ProfilerStrategy) !void {
        return wasmtime_config_profiler_set(self.inner, profiler) orelse Error.ConfigProfilerStrategySet;
    }

    // cacheConfigLoadDefault enables compiled code caching for this `Config` using the default settings
    // configuration can be found.
    //
    // For more information about caching see
    // https://bytecodealliance.github.io/wasmtime/cli-cache.html
    pub fn cacheConfigLoadDefault(self: *Config) !void {
        return wasmtime_config_cache_config_load(self.inner, null) orelse Error.ConfigLoadDefault;
    }

    // cacheConfigLoad enables compiled code caching for this `Config` using the settings specified
    // in the configuration file `path`.
    //
    // For more information about caching and configuration options see
    // https://bytecodealliance.github.io/wasmtime/cli-cache.html
    pub fn cacheConfigLoad(self: *Config, path: []const u8) !void {
        return wasmtime_config_cache_config_load(self.inner, path);
    }

    // setEpochInterruption enables epoch-based instrumentation of generated code to
    // interrupt WebAssembly execution when the current engine epoch exceeds a
    // defined threshold.
    pub fn setEpochInterruption(self: *Config, opt: bool) !void {
        wasmtime_config_epoch_interruption_set(self.inner, opt);
    }

    extern "c" fn wasmtime_config_debug_info_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_wasm_threads_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_wasm_reference_types_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_wasm_simd_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_wasm_bulk_memory_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_wasm_multi_value_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_wasm_multi_memory_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_wasm_memory64_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_consume_fuel_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_strategy_set(*wasm.Config, *Strategy) void;
    extern "c" fn wasmtime_config_cranelift_debug_verifier_set(*wasm.Config, bool) void;
    extern "c" fn wasmtime_config_cranelift_opt_level_set(*wasm.Config, *OptLevel) void;
    extern "c" fn wasmtime_config_profiler_set(*wasm.Config, *ProfilerStrategy) void;
    extern "c" fn wasmtime_config_cache_config_load(*wasm.Config, []const u8) void; // CString??
    extern "c" fn wasmtime_config_epoch_interruption_set(*wasm.Config, bool) void;
};
