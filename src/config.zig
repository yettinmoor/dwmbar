const std = @import("std");
const mem = std.mem;
const log = std.log;

pub const Block = struct {
    name: []const u8,
    cmd: []const u8,
    prefix: ?[]const u8 = null,
};

pub var delim: []const u8 = " | ";

const known_folders = @import("known-folders/known-folders.zig");

/// Caller owns returned slice.
pub fn readConfig(allocator: *mem.Allocator) ![]Block {
    const config = blk: {
        const dir = (try known_folders.open(allocator, .local_configuration, .{})) orelse {
            log.err("config file not found; create `dwmbar.cfg` in your config dir.", .{});
            return error.ParseError;
        };
        const file = try dir.openFile("dwmbar.cfg", .{});
        defer file.close();

        var config = std.ArrayList(u8).init(allocator);
        try file.reader().readAllArrayList(&config, std.math.maxInt(u16));
        try config.appendSlice("\n[dummy]");

        break :blk config.toOwnedSlice();
    };
    // defer allocator.free(config);

    var blocks = std.ArrayList(Block).init(allocator);
    var names = std.StringHashMap(void).init(allocator);
    defer names.deinit();

    var it = mem.split(config, "\n");

    var current_name: ?[]const u8 = null;
    var cmd: ?[]const u8 = null;
    var prefix: ?[]const u8 = null;

    var line_no: usize = 1;
    while (it.next()) |untrimmed_line| : (line_no += 1) {
        const line = mem.trim(u8, untrimmed_line, " \t\r");
        if (line.len == 0) {
            continue;
        }
        switch (line[0]) {
            '#' => {},
            '[' => {
                if (current_name) |name| blk: {
                    if (mem.eql(u8, name, "!global")) {
                        break :blk;
                    }
                    if (cmd) |given_cmd| {
                        if (names.contains(name)) {
                            log.err("line {}: duplicate block: `{s}`", .{ line_no, name });
                            return error.ParseError;
                        }
                        try blocks.append(.{ .name = name, .cmd = given_cmd, .prefix = prefix });
                        try names.put(name, {});
                        cmd = null;
                        prefix = null;
                    } else {
                        log.err("block `{s}` has no command!", .{name});
                        return error.ParseError;
                    }
                }

                const end = mem.lastIndexOfScalar(u8, line, ']') orelse {
                    log.err("line {}: invalid header fmt: `{s}`", .{ line_no, line });
                    return error.ParseError;
                };
                current_name = mem.trim(u8, line[1..end], " \t");
                if (current_name.?.len == 0) {
                    log.err("line {}: empty name", .{line_no});
                    return error.ParseError;
                }
            },
            else => {
                const name = current_name orelse {
                    log.err("line {}: field outside block", .{line_no});
                    return error.ParseError;
                };

                var line_it = mem.tokenize(line, " ");

                const key = line_it.next().?;

                if (!mem.eql(u8, "=", line_it.next() orelse "")) {
                    log.err("line {}: expected `=`", .{line_no});
                    return error.ParseError;
                }

                const value = blk: {
                    const value = line_it.rest();
                    if (value.len == 0) {
                        log.err("line {}: expected value", .{line_no});
                        return error.ParseError;
                    }
                    break :blk mem.trim(u8, value, "\"");
                };

                if (mem.eql(u8, key, "cmd")) {
                    cmd = value;
                } else if (mem.eql(u8, key, "prefix")) {
                    prefix = value;
                } else if (mem.eql(u8, key, "delim")) {
                    if (!mem.eql(u8, name, "!global")) {
                        log.err("`delim` field must be in [!global]", .{});
                        return error.ParseError;
                    }
                    delim = value;
                } else {
                    log.err("line {}: invalid key: `{s}`", .{ line_no, key });
                    return error.ParseError;
                }
            },
        }
    }

    return blocks.toOwnedSlice();
}
