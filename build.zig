const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .os_tag = .windows,
            .abi = .gnu,
            .cpu_arch = .x86_64
        }
    });
    const optimize = b.standardOptimizeOption(.{});

    const zigwin32_dep = b.dependency("zigwin32", .{});
    const zigwin32 = zigwin32_dep.module("win32");

    const exe = b.addExecutable(.{
        .name = "zig_direct2d",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "win32", .module = zigwin32 },
            },
        }),
    });

    b.installArtifact(exe);

    const emit_docs = b.option(bool, "emit-docs", "Whether to install docs in the build step");
    if (emit_docs) |_| {
        const install_docs = b.addInstallDirectory(.{
            .source_dir = exe.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });
        // const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
        b.default_step.dependOn(&install_docs.step);

        // docs_step.dependOn(&install_docs.step);
    }

    // STEPS //////////////////////////////////////////////////////////////////

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // TESTS //////////////////////////////////////////////////////////////////

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
