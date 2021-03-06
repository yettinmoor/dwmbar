// TODO: Use a better config parser from astrolabe.

const std = @import("std");
const mem = std.mem;
const log = std.log;
const StringArrayHashMap = std.StringArrayHashMap;
const string_literal = std.zig.string_literal;

const config_file_name = "dwmbar.cfg";

const Block = @import("Block.zig");

var delim: []const u8 = " | ";
var global_prefix: []const u8 = " ";
var global_suffix: []const u8 = " ";

pub fn getDelim() []const u8 {
    return delim;
}

pub fn getGlobalPrefix() []const u8 {
    return global_prefix;
}

pub fn getGlobalSuffix() []const u8 {
    return global_suffix;
}

const known_folders = @import("known-folders/known-folders.zig");

/// Caller owns returned slice.
pub fn readConfigFile(allocator: mem.Allocator) ![]Block {
    const config = blk: {
        const dir = try known_folders.open(allocator, .local_configuration, .{});
        if (dir == null) {
            return error.FileNotFound;
        }
        log.debug("reading config file...", .{});
        break :blk try dir.?.readFileAlloc(allocator, config_file_name, std.math.maxInt(u32));
    };
    defer allocator.free(config);
    return parseConfig(allocator, config);
}

fn parseConfig(allocator: mem.Allocator, config: []const u8) ![]Block {
    var kv_blocks = try getKvBlocks(allocator, config);
    defer kv_blocks.deinit();

    var blocks = std.ArrayList(Block).init(allocator);

    var kv_it = kv_blocks.iterator();
    while (kv_it.next()) |kvs| {
        const name = kvs.key_ptr.*;
        if (mem.eql(u8, name, "!global")) {
            if (kvs.value_ptr.get("delim")) |cfg_delim| {
                delim = try allocator.dupe(u8, cfg_delim);
            }
            if (kvs.value_ptr.get("prefix")) |cfg_prefix| {
                global_prefix = try allocator.dupe(u8, cfg_prefix);
            }
            if (kvs.value_ptr.get("suffix")) |cfg_suffix| {
                global_suffix = try allocator.dupe(u8, cfg_suffix);
            }
        } else {
            const cmd = kvs.value_ptr.get("cmd") orelse {
                log.err("[{s}] has no `cmd` parameter", .{name});
                return error.MissingParam;
            };
            const prefix = kvs.value_ptr.get("prefix");
            try blocks.append(.{
                .name = try allocator.dupe(u8, name),
                .cmd = try allocator.dupe(u8, cmd),
                .prefix = if (prefix) |p| try allocator.dupe(u8, p) else null,
            });
        }
        kvs.value_ptr.deinit();
    }

    log.debug("parsed {} blocks", .{blocks.items.len});

    return blocks.toOwnedSlice();
}

const KeyValuePairs = StringArrayHashMap([]const u8);

fn getKvBlocks(allocator: mem.Allocator, config: []const u8) !StringArrayHashMap(KeyValuePairs) {
    var it = mem.split(u8, config, "\n");

    var kv_blocks = StringArrayHashMap(KeyValuePairs).init(allocator);
    var current_block: []const u8 = "";

    var line_no: usize = 1;
    while (it.next()) |untrimmed_line| : (line_no += 1) {
        const line = trimWhitespace(untrimmed_line);
        if (line.len == 0) {
            continue;
        }
        switch (line[0]) {
            '#' => {},
            '[' => {
                if (line[line.len - 1] != ']') {
                    log.err("line {}: invalid header: expected `[<blockname>]`", .{line_no});
                    return error.ParseError;
                }
                current_block = trimWhitespace(line[1 .. line.len - 1]);
                if (current_block.len == 0) {
                    log.err("line {}: empty name", .{line_no});
                    return error.ParseError;
                }
                if (!kv_blocks.contains(current_block)) {
                    try kv_blocks.put(current_block, KeyValuePairs.init(allocator));
                }
            },
            else => {
                var line_it = mem.tokenize(u8, line, " \t\r\n");
                const key = line_it.next().?;
                if (!mem.eql(u8, "=", line_it.next() orelse "")) {
                    log.err("line {}: expected `<key> = <value>`", .{line_no});
                    return error.ParseError;
                }
                const value = line_it.rest();
                if (value.len == 0) {
                    log.err("line {}: expected value", .{line_no});
                    return error.ParseError;
                }
                var kv_block_entry = kv_blocks.getPtr(current_block) orelse {
                    log.err("line {}: key-value pair outside block", .{line_no});
                    return error.ParseError;
                };
                const string = try string_literal.parseAlloc(allocator, value);
                try kv_block_entry.put(key, string);
            },
        }
    }

    return kv_blocks;
}

fn trimWhitespace(s: []const u8) []const u8 {
    return mem.trim(u8, s, " \t\r\n");
}

const testing = std.testing;

test {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);

    _ = try parseConfig(&arena.allocator,
        \\[!global]
        \\delim = " | "
        \\
        \\[mpc]
        \\cmd = "mpc current -f '%artist% - %title%'"
        \\prefix = "???"
        \\
        \\[updates]
        \\cmd = "pacman -Qu | wc -l | grep -v '^0'"
        \\prefix = "???"
        \\
        \\[time]
        \\cmd = "date +%R"
        \\
    );

    try testing.expectError(error.MissingParam, parseConfig(&arena.allocator,
        \\[hello]
        \\prefix = "!"
        \\
    ));

    try testing.expectError(error.ParseError, parseConfig(&arena.allocator,
        \\[hello
        \\cmd = "printf hello!"
        \\
    ));

    try testing.expectError(error.ParseError, parseConfig(&arena.allocator,
        \\[hello]
        \\cmd =
        \\
    ));

    arena.deinit();
}
