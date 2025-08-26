const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});
  
  const bind_mod = b.addModule("bind", .{
    .target = target,
    .optimize = optimize,
    .root_source_file = b.path("src/bind.zig"),
  });

  const test_exe = b.addExecutable(.{
    .name = "test",
    .root_module = b.createModule(.{
      .target = target,
      .optimize = optimize,
      .root_source_file = b.path("examples/basic.zig"),
      .imports = &.{.{.name = "bind", .module = bind_mod}},
    }),
  });

  b.installArtifact(test_exe);
}
