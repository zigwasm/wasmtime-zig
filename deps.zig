const std = @import("std");
pub const pkgs = struct {
    pub const wasm = std.build.Pkg{
        .name = "wasm",
        .path = ".gyro/wasm-zig-kubkon-a8f98d100ae0ede37f42d5c084d1401805e1e843/pkg/src/main.zig",
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
    pub const wasm = ".gyro/wasm-zig-kubkon-a8f98d100ae0ede37f42d5c084d1401805e1e843/pkg";
};
