const std = @import("std");
const assert = std.debug.assert;
const Io = std.Io;

const Action = enum {
    generate,
    clear,
    help,
};

// ASCII '!' - '~'
const alphabet_start = 33;
const alphabet_end = 127;
const alphabet_len = alphabet_end - alphabet_start;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var key: [32]u8 = @splat('0');
    defer std.crypto.secureZero(u8, &key);

    const action: Action = blk: {
        var iter = init.minimal.args.iterate();
        _ = iter.skip(); // Program name
        const arg = iter.next();
        if (iter.skip()) return error.TooManyArguments;
        if (arg) |action| {
            if (std.mem.eql(u8, "help", action) or std.mem.eql(u8, "--help", action)) {
                break :blk .help;
            } else if (std.mem.eql(u8, "clear", action)) {
                break :blk .clear;
            } else if (std.mem.eql(u8, "generate", action)) {
                break :blk .generate;
            } else return error.UnrecognizedAction;
        } else break :blk .generate;
    };

    var message: []const u8 = "copied password to clipboard";
    var buffer: [128]u8 = undefined;

    switch (action) {
        .generate => try generateKey(io, &key),
        .clear => message = "cleared clipboard",
        .help => {
            const stdout = std.Io.File.stdout();
            var w = stdout.writer(io, &buffer);
            try w.interface.writeAll(help);
            try w.flush();
            return;
        },
    }

    var pbcopy = try std.process.spawn(io, .{
        .argv = &.{"pbcopy"},
        .stdin = .pipe,
    });

    if (pbcopy.stdin) |stdin| {
        defer std.crypto.secureZero(u8, &buffer);
        var w = pbcopy.stdin.?.writer(io, &buffer);
        try w.interface.writeAll(&key);
        try w.flush();
        stdin.close(io);
    } else std.log.err("stdin failed", .{});
    switch (try pbcopy.wait(io)) {
        .exited => |ret| if (ret == 0) {
            std.log.info("{s}", .{message});
            return;
        } else {
            std.log.err("pbcopy exited with non-zero return code: {}", .{ret});
            return error.ChildFailed;
        },
        .signal => |ret| {
            std.log.err("pbcopy failed: signal {}", .{ret});
            return error.ChildFailed;
        },
        .stopped => |ret| {
            std.log.err("pbcopy failed: stopped {}", .{ret});
            return error.ChildFailed;
        },
        .unknown => |ret| {
            std.log.err("pbcopy failed: unknown {}", .{ret});
            return error.ChildFailed;
        },
    }
}

fn generateKey(io: std.Io, out: []u8) !void {
    const range = std.math.maxInt(u8);
    comptime assert(range >= alphabet_len);
    const limit = range - (range % alphabet_len);
    comptime assert(limit % alphabet_len == 0);

    var entropy: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &entropy);
    var idx: usize = 0;
    for (0..1 << 10) |_| {
        try io.randomSecure(&entropy);
        for (&entropy) |val| {
            if (val < limit) {
                out[idx] = val % alphabet_len + alphabet_start;
                idx += 1;
                if (idx >= out.len) return;
            }
        }
    }
    return error.TryAgain;
}

const help =
    \\rapa - RAndom PAssword Generator
    \\
    \\Usage:
    \\  rapa [action]
    \\
    \\Actions:
    \\  (none)      generate a new password and copy to clipboard
    \\  generate    same as (none)
    \\  help        show this help message
    \\  clear       wipe the system clipboard
    \\
    \\
;
