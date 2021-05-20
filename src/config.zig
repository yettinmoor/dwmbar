pub const Block = struct {
    name: []const u8,
    cmd: []const u8,
    prefix: ?[]const u8 = null,
};

pub const delim = " | ";

pub const blocks = [_]Block{
    .{
        .name = "ib",
        .cmd = "",
    },
    .{
        .name = "updates",
        .cmd = "pacman -Qu | wc -l | grep -v '^0'",
        .prefix = "",
    },
    .{
        .name = "rss",
        .cmd = "newsboat -x print-unread | awk '/^[1-9]/ {print $1}'",
        .prefix = "",
    },
    .{
        .name = "date",
        .cmd = "kyou",
    },
    .{
        .name = "time",
        .cmd = "date +%R",
    },
};
