const std = @import("std");
const mem = std.mem;
const log = std.log;
const process = std.process;

extern fn display(*const u8) void;

const config = @import("config.zig");
const Block = @import("Block.zig");

const cache_path = "/tmp/dwmbar";

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = process.ArgIteratorPosix.init();
    _ = args.next();
    const cmd = args.next();
    const param = args.next();

    // Print usage.
    if (cmd != null and (mem.eql(u8, cmd.?, "-h") or mem.eql(u8, cmd.?, "--help"))) {
        printUsageAndExit(std.io.getStdOut().writer(), 0);
        // unreachable;
    }

    const blocks = config.readConfigFile(allocator) catch {
        log.err("parsing error, exiting...", .{});
        process.exit(1);
    };

    const cwd = std.fs.cwd();
    const cache = try cwd.createFile(cache_path, .{
        .read = true,
        .truncate = false,
        .lock = .Exclusive,
    });
    defer cache.close();

    // Always run all commands if there is no cache.
    const run_all = blk: {
        const stat = try cache.stat();
        break :blk stat.size == 0;
    };

    var outputs = std.ArrayList([]const u8).init(allocator);

    // `dwmbar` OR cache newly created.
    if (cmd == null or run_all) {
        for (blocks) |b| {
            const output = try b.run(allocator);
            try outputs.append(output);
        }
    }

    // `dwmbar <block>`
    else {
        const index = for (blocks) |b, i| {
            if (std.mem.eql(u8, cmd.?, b.name)) {
                break i;
            }
        } else {
            log.err("non-existent block: `{s}`", .{cmd.?});
            printUsageAndExit(std.io.getStdErr().writer(), 1);
        };

        const contents = try cache.readToEndAlloc(allocator, std.math.maxInt(u16));
        var it = mem.split(u8, contents, "\n");

        for (blocks) |b, i| {
            const line = it.next().?;
            if (i == index) {
                const output = param orelse try b.run(allocator);
                try outputs.append(output);
            } else {
                try outputs.append(line);
            }
        }
    }

    try cache.seekTo(0);

    var bar = std.ArrayList(u8).init(allocator);
    try bar.appendSlice(config.global_prefix);

    // Append outputs to cache file and dwmbar output.
    for (outputs.items) |output, i| {
        try cache.writer().print("{s}\n", .{output});
        if (output.len != 0) {
            if (blocks[i].prefix) |prefix| {
                try bar.writer().print("{s} ", .{prefix});
            }
            try bar.appendSlice(output);
            try bar.appendSlice(config.delim);
        }
    }

    // Update cache file length.
    const cache_len = try cache.getPos();
    try cache.setEndPos(cache_len);

    // Remove last delim and zero-terminate bar output.
    bar.resize(bar.items.len - config.delim.len) catch unreachable;
    try bar.appendSlice(config.global_suffix);
    try bar.append(0);

    log.info("setting bar to:", .{});
    log.info("  `{s}`", .{bar.items});

    display(@ptrCast(*const u8, bar.items.ptr));
}

fn printUsageAndExit(writer: anytype, status: u8) noreturn {
    writer.writeAll(
        \\Usage:
        \\  dwmbar                 | Update all blocks.
        \\  dwmbar [block]         | Update [block].
        \\  dwmbar [block] [param] | Set [block] to "[param]".
        \\
    ) catch {};
    process.exit(status);
}
