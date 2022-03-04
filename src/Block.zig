const std = @import("std");
const mem = std.mem;
const log = std.log;

const Block = @This();
const config = @import("config.zig");

name: []const u8,
cmd: []const u8,
prefix: ?[]const u8 = null,

/// Returns whitespace-trimmed stdout of `sh -e '{block.cmd}'`.
/// Newlines replaced with spaces.
/// Caller must free returned slice.
pub fn run(block: Block, allocator: mem.Allocator) ![]const u8 {
    log.info("running block [{s}]", .{block.name});
    const exec = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{ "sh", "-c", block.cmd },
    });
    allocator.free(exec.stderr);

    const output = try mem.replaceOwned(u8, allocator, exec.stdout, "%DELIM", config.getDelim());
    mem.replaceScalar(u8, output, '\n', ' ');

    const trimmed = mem.trim(u8, output, " \t\r");
    log.info("  `{s}`", .{trimmed});
    return trimmed;
}
