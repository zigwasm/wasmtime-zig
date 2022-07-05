// @TODO: Split these up into own error sets
pub const Error = error{
    /// Failed to initialize a `Config`
    ConfigInit,
    ConfigStrategySet,
    ConfigOptLevelSet,
    ConfigProfilerStrategySet,
    ConfigLoadDefault,
    /// Failed to initialize an `Engine` (i.e. invalid config)
    EngineInit,
    /// Failed to initialize a `Store`
    StoreInit,
    StoreContext,
    /// Failed to initialize a `Module`
    ModuleInit,
    ModuleWat2Wasm,
    /// Failed to create a wasm function based on
    /// the given `Store` and functype
    FuncInit,
    /// Failed to initialize a new `Instance`
    InstanceInit,
};
