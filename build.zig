const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const kmd_exe = b.addExecutable(.{
        .name = "future",
        .root_source_file = .{ .path = "komodo/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const tegu_exe = b.addExecutable(.{
        .name = "tegu",
        .root_source_file = .{ .path = "tegu/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const toml_dep = b.dependency("toml", .{});

    const tegu_mod = b.createModule(
        .{ .source_file = .{ .path = "tegu/main.zig" } },
    );

    kmd_exe.addModule("tegu", tegu_mod);
    kmd_exe.addModule("toml", toml_dep.module("zig-toml"));

    b.installArtifact(kmd_exe);
    b.installArtifact(tegu_exe);

    const run_kmd_cmd = b.addRunArtifact(kmd_exe);
    const run_tegu_cmd = b.addRunArtifact(tegu_exe);

    run_kmd_cmd.step.dependOn(b.getInstallStep());
    run_tegu_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_kmd_cmd.addArgs(args);
        run_tegu_cmd.addArgs(args);
    }

    const run_kmd_step = b.step("kmd", "run komodo with args");
    run_kmd_step.dependOn(&run_kmd_cmd.step);

    const run_tegu_step = b.step("tegu", "run tegu with args");
    run_tegu_step.dependOn(&run_tegu_cmd.step);

    // don't really care about tests right now

    // const unit_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const run_unit_tests = b.addRunArtifact(unit_tests);
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_unit_tests.step);
}
