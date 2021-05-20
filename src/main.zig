const std = @import("std");
const mem = std.mem;

extern fn display(*const u8) void;

const config = @import("config.zig");
const path = "/tmp/dwmbar";

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(&gpa.allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var args = std.process.ArgIteratorPosix.init();
    _ = args.next();
    const cmd = args.next();
    const param = args.next();

    const cwd = std.fs.cwd();
    const file = try cwd.createFile(path, .{ .read = true, .truncate = false });
    defer file.close();

    const always_run_all = blk: {
        const stat = try file.stat();
        break :blk stat.size == 0 or stat.mtime < compile_timestamp;
    };

    var outputs = std.ArrayList([]const u8).init(allocator);

    // `dwmbar` OR file newly created OR file is older than compiled program
    if (cmd == null or always_run_all) {
        for (config.blocks) |b| {
            const output = try runCmd(allocator, b.cmd);
            try outputs.append(output);
        }
    }

    // `dwmbar <cmd>`
    else {
        const block_index = for (config.blocks) |b, i| {
            if (std.mem.eql(u8, cmd.?, b.name)) {
                break i;
            }
        } else {
            try std.io.getStdErr().writer().print("Non-existent block: `{s}`\n", .{cmd.?});
            std.process.exit(1);
        };

        const contents = try file.readToEndAlloc(allocator, 2048);
        var it = mem.split(contents, "\n");

        for (config.blocks) |b, i| {
            const line = it.next().?;
            if (i == block_index) {
                const output = param orelse try runCmd(allocator, config.blocks[i].cmd);
                try outputs.append(output);
            } else {
                try outputs.append(line);
            }
        }
    }

    try file.seekTo(0);

    var bar = std.ArrayList(u8).init(allocator);
    try bar.appendSlice(" ");

    for (outputs.items) |o, i| {
        // output to dwmbar
        if (o.len != 0) {
            if (config.blocks[i].prefix) |prefix| {
                try bar.writer().print("{s} ", .{prefix});
            }
            try bar.appendSlice(mem.trimRight(u8, o, " \t\r\n"));
            try bar.appendSlice(config.delim);
        }

        // output to /tmp/dwmbar
        try file.writer().print("{s}\n", .{o});
    }

    bar.items.len -= config.delim.len;
    try bar.appendSlice(" \x00");

    try file.setEndPos(try file.getPos());

    display(@ptrCast(*const u8, bar.items.ptr));
}

fn runCmd(allocator: *mem.Allocator, cmd: []const u8) ![]const u8 {
    const exec = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = &[3][]const u8{ "sh", "-c", cmd } });
    allocator.free(exec.stderr);
    for (exec.stdout) |*c| {
        if (c.* == '\n') c.* = ' ';
    }
    return exec.stdout;
}

// build.zig
pub var compile_timestamp = comptime std.fmt.parseInt(i64, @embedFile("timestamp"), 10) catch unreachable;
