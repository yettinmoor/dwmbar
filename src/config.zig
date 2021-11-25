const std = @import("std");
const mem = std.mem;
const log = std.log;
const StringArrayHashMap = std.StringArrayHashMap;

const Block = @import("Block.zig");

pub var delim: []const u8 = " | ";

pub var global_prefix: []const u8 = " ";
pub var global_suffix: []const u8 = " ";

const known_folders = @import("known-folders/known-folders.zig");

/// Caller owns returned slice.
pub fn readConfigFile(allocator: *mem.Allocator) ![]Block {
    const config = blk: {
        const dir =
            (try known_folders.open(allocator, .local_configuration, .{})) orelse
            return error.FileNotFound;
        break :blk try dir.readFileAlloc(allocator, "dwmbar.cfg", std.math.maxInt(u32));
    };
    defer allocator.free(config);
    return readConfig(allocator, config);
}

fn readConfig(allocator: *mem.Allocator, config: []const u8) ![]Block {
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
                log.err("[{s}]: missing `cmd` parameter.", .{name});
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

    return blocks.toOwnedSlice();
}

const KeyValuePairs = StringArrayHashMap([]const u8);

fn getKvBlocks(allocator: *mem.Allocator, config: []const u8) !StringArrayHashMap(KeyValuePairs) {
    var it = mem.split(config, "\n");

    var kv_blocks = StringArrayHashMap(KeyValuePairs).init(allocator);
    var current_block: []const u8 = "";

    var line_no: usize = 1;
    while (it.next()) |untrimmed_line| : (line_no += 1) {
        const line = mem.trim(u8, untrimmed_line, " \t\r");
        if (line.len == 0) {
            continue;
        }
        switch (line[0]) {
            '#' => {},
            '[' => {
                const end = mem.lastIndexOfScalar(u8, line, ']') orelse {
                    log.err("line {}: invalid header fmt: `{s}`", .{ line_no, line });
                    return error.ParseError;
                };
                current_block = line[1..end];
                if (current_block.len == 0) {
                    log.err("line {}: empty name", .{line_no});
                    return error.ParseError;
                }
                if (kv_blocks.contains(current_block)) {
                    log.err("line {}: duplicate block: `{s}`", .{ line_no, current_block });
                    return error.ParseError;
                }
                try kv_blocks.put(current_block, KeyValuePairs.init(allocator));
            },
            else => {
                var line_it = mem.tokenize(line, "=");
                const key = mem.trim(u8, line_it.next().?, " \t");
                const value = mem.trim(u8, line_it.rest(), " \t");
                if (value.len == 0) {
                    log.err("line {}: expected value", .{line_no});
                    return error.ParseError;
                }
                var kv_block_entry = kv_blocks.getPtr(current_block) orelse {
                    log.err("line {}: key-value pair outside block", .{line_no});
                    return error.ParseError;
                };
                try kv_block_entry.put(key, mem.trim(u8, value, "\""));
            },
        }
    }

    return kv_blocks;
}

const testing = std.testing;

test {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    _ = try readConfig(&arena.allocator,
        \\[!global]
        \\delim = " | "
        \\
        \\[mpc]
        \\cmd = "mpc current -f '%artist% - %title%'"
        \\prefix = "♫"
        \\
        \\[updates]
        \\cmd = "pacman -Qu | wc -l | grep -v '^0'"
        \\prefix = ""
        \\
        \\[time]
        \\cmd = "date +%R"
        \\
    );

    try testing.expectError(error.MissingParam, readConfig(&arena.allocator,
        \\[hello]
        \\prefix = "!"
        \\
    ));

    try testing.expectError(error.ParseError, readConfig(&arena.allocator,
        \\[hello
        \\cmd = "printf hello!"
        \\
    ));

    try testing.expectError(error.ParseError, readConfig(&arena.allocator,
        \\[hello]
        \\cmd =
        \\
    ));

    arena.deinit();
}
