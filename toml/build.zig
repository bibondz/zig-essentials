const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Public module
    _ = b.addModule("toml", .{
        .root_source_file = b.path("src/toml.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Tests
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/toml_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);
}
