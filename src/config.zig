const std = @import("std");
const mem = std.mem;
const log = std.log;

pub const Block = struct {
    name: []const u8,
    cmd: []const u8,
    prefix: ?[]const u8 = null,
};

pub const delim = " | ";

const known_folders = @import("known-folders/known-folders.zig");

pub fn readConfig(allocator: *mem.Allocator) ![]Block {
    const config_dir = try known_folders.open(allocator, .local_configuration, .{});
    const config_txt = try config_dir.?.readFileAlloc(allocator, "dwmbar.cfg", std.math.maxInt(u32));

    var blocks = std.ArrayList(Block).init(allocator);

    var it = mem.split(config_txt, "\n");

    var name: ?[]const u8 = null;
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
                if (name) |given_name| {
                    if (cmd) |given_cmd| {
                        try blocks.append(.{ .name = given_name, .cmd = given_cmd, .prefix = prefix });
                        cmd = null;
                        prefix = null;
                    } else {
                        log.err("block `{s}` has no command!", .{given_name});
                        return error.ParseError;
                    }
                }
                const end = mem.lastIndexOfScalar(u8, line, ']') orelse {
                    log.err("line {}: invalid header fmt: `{s}`", .{ line_no, line });
                    return error.ParseError;
                };
                name = mem.trim(u8, line[1..end], " \t");
            },
            else => {
                var line_it = mem.tokenize(line, " ");
                const key = line_it.next().?;
                const equals = line_it.next() orelse "";
                if (!mem.eql(u8, equals, "=")) {
                    log.err("line {}: expected `=`", .{line_no});
                    return error.ParseError;
                }
                const value = mem.trim(u8, line_it.rest(), "\"");
                if (mem.eql(u8, key, "cmd")) {
                    cmd = value;
                } else if (mem.eql(u8, key, "prefix")) {
                    prefix = value;
                } else {
                    log.err("line {}: invalid key: `{s}`", .{ line_no, key });
                }
            },
        }
    }

    if (name) |given_name| {
        if (cmd) |given_cmd| {
            try blocks.append(.{ .name = given_name, .cmd = given_cmd, .prefix = prefix });
        } else {
            log.err("block `{s}` has no command!", .{given_name});
            return error.ParseError;
        }
    }

    return blocks.toOwnedSlice();
}
