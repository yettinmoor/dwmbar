const std = @import("std");
const mem = std.mem;
const log = std.log;

const Block = @This();

name: []const u8,
cmd: []const u8,
prefix: ?[]const u8 = null,

/// Returns whitespace-trimmed stdout of `sh -e '{block.cmd}'`.
/// Newlines replaced with spaces.
pub fn run(block: Block, allocator: mem.Allocator) ![]const u8 {
    log.info("running block [{s}]", .{block.name});
    const exec = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{ "sh", "-c", block.cmd },
    });
    allocator.free(exec.stderr);
    mem.replaceScalar(u8, exec.stdout, '\n', ' ');
    const output = mem.trim(u8, exec.stdout, " \t\r");
    log.info("  `{s}`", .{output});
    return output;
}
