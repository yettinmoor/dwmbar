const std = @import("std");

const root = @import("root");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    makeTimestampFile() catch unreachable;

    const exe = b.addExecutable("dwmbar", "src/main.zig");

    exe.addPackage(.{
        .name = "known-folders",
        .path = "src/known-folders/known-folders.zig",
    });

    exe.addCSourceFile("src/display.c", &[_][]const u8{});
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.linkSystemLibrary("X11");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn makeTimestampFile() !void {
    const f = try std.fs.cwd().createFile("src/timestamp", .{});
    defer f.close();
    try f.writer().print("{}", .{std.time.nanoTimestamp()});
}
