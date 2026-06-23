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

var buffer: [128]u8 = undefined;

const pbcopy_argv: []const []const u8 = &.{"pbcopy"};

pub fn main(init: std.process.Init) !void {
    const io = init.io;

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

    switch (action) {
        .generate => {
            var key: [32]u8 = undefined;
            defer std.crypto.secureZero(u8, &key);
            try generateKey(io, &key);
            try setClipboard(pbcopy_argv, "copied password to clipboard", io, &key);
        },
        .clear => try setClipboard(pbcopy_argv, "cleared clipboard", io, &.{}),
        .help => {
            const stdout = std.Io.File.stdout();
            var w = stdout.writer(io, &buffer);
            try w.interface.writeAll(help);
            try w.flush();
            return;
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

fn setClipboard(
    comptime argv: []const []const u8,
    comptime message: []const u8,
    io: std.Io,
    payload: []const u8,
) !void {
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .stdin = .pipe,
    });

    if (child.stdin) |stdin| {
        defer std.crypto.secureZero(u8, &buffer);
        var w = stdin.writer(io, &buffer);
        try w.interface.writeAll(payload);
        try w.flush();
        stdin.close(io);
    } else {
        std.log.err(argv[0] ++ " failed: stdin is not open", .{});
        child.kill(io);
        return error.ClibpoardFailed;
    }
    switch (try child.wait(io)) {
        .exited => |ret| if (ret == 0) {
            std.log.info("{s}", .{message});
            return;
        } else {
            std.log.err(argv[0] ++ " exited with non-zero return code: {}", .{ret});
            return error.ClibpoardFailed;
        },
        .signal => |ret| {
            std.log.err(argv[0] ++ " failed: signal {}", .{ret});
            return error.ClibpoardFailed;
        },
        .stopped => |ret| {
            std.log.err(argv[0] ++ " failed: stopped {}", .{ret});
            return error.ClibpoardFailed;
        },
        .unknown => |ret| {
            std.log.err(argv[0] ++ " failed: unknown {}", .{ret});
            return error.ClibpoardFailed;
        },
    }
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
