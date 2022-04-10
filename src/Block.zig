const std = @import("std");
const mem = std.mem;
const log = std.log;

const Block = @This();
const config = @import("config.zig");

name: []const u8,
cmd: []const u8,
prefix: ?[]const u8 = null,

/// Returns whitespace-trimmed stdout of `sh -c '{block.cmd}'`.
/// Newlines replaced with spaces.
/// Caller must free returned slice.
pub fn run(block: Block, allocator: mem.Allocator) ![]const u8 {
    const exec = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{ "sh", "-c", block.cmd },
    });
    if (exec.stderr.len != 0) {
        log.warn("[{s}] stderr:\n{s}", .{ block.name, mem.trimRight(u8, exec.stderr, "\r\n") });
    }
    allocator.free(exec.stderr);

    const output = try mem.replaceOwned(u8, allocator, exec.stdout, "%DELIM", config.getDelim());
    mem.replaceScalar(u8, output, '\n', ' ');

    const trimmed = mem.trim(u8, output, " \t\r");
    log.info("[{s}] = `{s}`", .{ block.name, trimmed });
    return trimmed;
}
