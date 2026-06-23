const std = @import("std");
const Io = std.Io;

const alphabet_start = 33;
const alphabet_end = 127;
const alphabet_len = alphabet_end - alphabet_start;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var key: [32]u8 = @splat('0');
    defer std.crypto.secureZero(u8, &key);

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 2) return error.TooManyArguments;
    if (args.len == 2) {
        const action = args[1];
        if (std.mem.eql(u8, "help", action) or std.mem.eql(u8, "--help", action)) {
            std.log.info("{s}", .{help});
            return;
        } else if (std.mem.eql(u8, "clear", action)) {
            // clear clipboard
        } else if (std.mem.eql(u8, "generate", action)) {
            try mapToAlphabet(io, &key);
        } else return error.UnrecognizedAction;
    } else try mapToAlphabet(io, &key);

    var pbcopy = try std.process.spawn(io, .{
        .argv = &.{"pbcopy"},
        .stdin = .pipe,
    });

    if (pbcopy.stdin) |stdin| {
        var buffer: [128]u8 = undefined;
        defer std.crypto.secureZero(u8, &buffer);
        var w = pbcopy.stdin.?.writer(io, &buffer);
        try w.interface.writeAll(&key);
        try w.flush();
        stdin.close(io);
    } else std.log.err("stdin failed", .{});
    switch (try pbcopy.wait(io)) {
        .exited => |ret| if (ret == 0) {
            std.log.info("copied password to clipboard", .{});
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

fn mapToAlphabet(io: std.Io, out: []u8) !void {
    const range = std.math.maxInt(u8);
    const limit = range - (range % alphabet_len);

    var entropy: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &entropy);
    var idx: usize = 0;
    while (true) {
        try io.randomSecure(std.mem.sliceAsBytes(&entropy));
        for (&entropy) |val| {
            if (val < limit) {
                out[idx] = val % alphabet_len + alphabet_start;
                idx += 1;
                if (idx >= out.len) return;
            }
        }
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
;
