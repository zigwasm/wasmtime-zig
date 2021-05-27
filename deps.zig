const std = @import("std");
pub const pkgs = struct {
    pub const wasm = std.build.Pkg{
        .name = "wasm",
        .path = ".gyro/wasm-zig-zigwasm-3041a2dce58a41b49e9e6623bb07154e17e4911a/pkg/src/main.zig",
    };

    pub fn addAllTo(artifact: *std.build.LibExeObjStep) void {
        @setEvalBranchQuota(1_000_000);
        inline for (std.meta.declarations(pkgs)) |decl| {
            if (decl.is_pub and decl.data == .Var) {
                artifact.addPackage(@field(pkgs, decl.name));
            }
        }
    }
};

pub const base_dirs = struct {
    pub const wasm = ".gyro/wasm-zig-zigwasm-3041a2dce58a41b49e9e6623bb07154e17e4911a/pkg";
};
