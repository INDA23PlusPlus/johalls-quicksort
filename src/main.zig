const std = @import("std");

const T = i32;

const MAXN = 500_000;
var buf: [MAXN * 16]u8 align(4) = undefined;
var ints: [MAXN]i32 = undefined;
var n: usize = 0;

fn less(_: @TypeOf(.{}), a: i32, b: i32) bool {
    return a < b;
}

pub fn main() !void {
    _ = try std.io.getStdIn().reader().readAll(&buf);
    var slice: []u8 = &buf;

    while ('0' <= slice[0] and slice[0] <= '9') : (slice = slice[1..]) {
        n = n * 10 + slice[0] - '0';
    }

    for (0..n) |i| {
        var parsed: i32 = 0;
        var sign: i32 = 1;
        slice = slice[1..];
        if (slice[0] == '-') {
            slice = slice[1..];
            sign = -1;
        }
        while ('0' <= slice[0] and slice[0] <= '9') : (slice = slice[1..]) {
            parsed = parsed * 10 + slice[0] - '0';
        }

        ints[i] = parsed * sign;
    }

    std.sort.pdq(i32, ints[0..n], .{}, less);

    slice = &buf;
    for (ints[0..n]) |i| {
        var x: i64 = i;
        if (x < 0) {
            x = -x;
            slice[0] = '-';
            slice = slice[1..];
        }
        var non_neg: u64 = @intCast(x);

        var number_slice: []u8 = slice[0..20];
        var digits_used: usize = 1;
        number_slice[0] = @intCast(non_neg % 10 + '0');
        non_neg /= 10;

        while (non_neg > 0) {
            number_slice[digits_used] = @intCast(non_neg % 10 + '0');
            digits_used += 1;
            non_neg /= 10;
        }
        std.mem.reverse(u8, number_slice[0..digits_used]);
        slice = slice[digits_used..];

        slice[0] = ' ';
        slice = slice[1..];
    }
    try std.io.getStdOut().writer().writeAll(buf[0..buf.len - slice.len]);
}
