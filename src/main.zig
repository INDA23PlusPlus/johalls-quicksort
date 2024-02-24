const std = @import("std");

const MAXN = 500_000;
var global_buf: [MAXN * 16]u8 align(4) = undefined;
var ints: [MAXN]i32 = undefined;
var n: usize = 0;

// writes the string representation of val to buf if val < 100 and returns the rest of the buffer
fn write_100(buf: []u8, val: u32) []u8 {
    var tmp: u32 = '0' * 257;
    tmp += val % 10 << 8;
    tmp += val / 10;
    tmp >>= 8 * @as(u5, @intFromBool(val < 10));
    const len: usize = @as(usize, 2) - @intFromBool(val < 10);

    buf[0] = @intCast(tmp & 0xff);
    buf[1] = @intCast(tmp >> 8);

    return buf[len..];
}

test "write_100" {
    var b1: [2]u8 = undefined;
    var b2: [2]u8 = undefined;
    for (0..100) |i| {
        const printed_to = try std.fmt.bufPrint(&b2, "{}", .{i});
        const len = printed_to.len;
        _ = write_100(&b1, @intCast(i));
        // std.debug.print("{s} {s}\n", .{ b1, b2 });
        try std.testing.expect(std.mem.eql(u8, b1[0..len], b2[0..len]));
    }
}

// writes the string representation of val to buf if val < 100 and returns the rest of the buffer
fn write_100_full(buf: []u8, val: u32) void {
    var tmp: u32 = '0' * 257;
    tmp += val % 10 << 8;
    tmp += val / 10;

    buf[0] = @intCast(tmp & 0xff);
    buf[1] = @intCast(tmp >> 8);
}

test "write_100_full" {
    var b1: [2]u8 = undefined;
    var b2: [2]u8 = undefined;
    b1[1] = ' ';
    b2[1] = ' ';
    for (0..10) |i| {
        _ = try std.fmt.bufPrint(&b2, "{}", .{i});
        write_100_full(&b1, @intCast(i));
        try std.testing.expect(std.mem.eql(u8, b1[1..2], b2[0..1]));
    }
    for (10..100) |i| {
        _ = try std.fmt.bufPrint(&b2, "{}", .{i});
        write_100_full(&b1, @intCast(i));
        try std.testing.expect(std.mem.eql(u8, &b1, &b2));
    }
}

// writes the string representation of val to buf if val < 10000 and returns the rest of the buffer
fn write_10000(buf: []u8, val: u32) []u8 {
    var t1: u32 = 0;
    t1 += (val / 100) % 10 << 8;
    t1 += (val / 100) / 10;
    var t2: u32 = 0;
    t2 += val % 10 << 8;
    t2 += val / 10 % 10;
    var t: u32 = t1 + (t2 << 16);

    const zeros = @ctz(t);
    const len = 4 - zeros / 8 + @intFromBool(val == 0);
    const shift = 8 * (4 - len);

    inline for (0..4) |e| {
        t += '0' << 8 * e;
    }

    // comforting the compiler
    var t3: u64 = t;
    t3 >>= @intCast(shift);

    // call to memcpy wasnt being inlined
    inline for (0..4) |e| {
        buf[e] = @intCast((t3 >> 8 * e) & 0xff);
    }

    return buf[len..];
}

test "write_10000" {
    var b1: [4]u8 = undefined;
    var b2: [4]u8 = undefined;
    b1[1] = ' ';
    b1[2] = ' ';
    b1[3] = ' ';

    b2[1] = ' ';
    b2[2] = ' ';
    b2[3] = ' ';
    for (0..10000) |i| {
        const printed_to = try std.fmt.bufPrint(&b2, "{}", .{i});
        const len = printed_to.len;
        _ = write_10000(&b1, @intCast(i));
        try std.testing.expect(std.mem.eql(u8, b1[0..len], b2[0..len]));
    }
}

fn write_10000_full(buf: []u8, val: u32) void {
    var t1: u32 = 0;
    t1 += (val / 100) % 10 << 8;
    t1 += (val / 100) / 10;
    var t2: u32 = 0;
    t2 += val % 10 << 8;
    t2 += val / 10 % 10;
    var t: u32 = t1 + (t2 << 16);

    inline for (0..4) |e| {
        t += '0' << 8 * e;
    }

    // call to memcpy wasnt being inlined
    inline for (0..4) |e| {
        buf[e] = @intCast((t >> 8 * e) & 0xff);
    }
}

test "write_10000_full" {
    var b1: [8]u8 = undefined;
    var b2: [4]u8 = undefined;
    for (0..1000) |i| {
        const printed_to = try std.fmt.bufPrint(&b2, "{}", .{i});
        const len = printed_to.len;
        write_10000_full(&b1, @intCast(i));
        const leading_zeros = 4 - len;
        try std.testing.expect(std.mem.eql(u8, b1[leading_zeros..4], b2[0..len]));
    }
    for (1000..10000) |i| {
        const printed_to = try std.fmt.bufPrint(&b2, "{}", .{i});
        const len = printed_to.len;
        write_10000_full(&b1, @intCast(i));
        try std.testing.expect(std.mem.eql(u8, b1[0..len], b2[0..len]));
    }
}

fn write_1e8(buf: []u8, val: u32) []u8 {
    var ret = write_10000(buf, val / 10000);
    write_10000_full(ret, val % 10000);
    return ret[4..];
}

fn write_1e8_full(buf: []u8, val: u32) void {
    write_10000_full(buf[0..4], val / 10000);
    write_10000_full(buf[4..8], val % 10000);
}

fn write_fast(buf: []u8, val: u32) []u8 {
    if (val < 10000) {
        return write_10000(buf, val);
    }
    if (val < 10000 * 10000) {
        return write_1e8(buf, val);
    }
    const ret = write_100(buf, val / 100000000);
    write_1e8_full(ret, val % 100000000);

    return ret[8..];
}

fn write_slow(buf: []u8, inp: u32) []u8 {
    var digits_used: usize = 1;
    var val = inp;
    buf[0] = @intCast(val % 10 + '0');
    val /= 10;

    while (val > 0) {
        buf[digits_used] = @intCast(val % 10 + '0');
        digits_used += 1;
        val /= 10;
    }
    std.mem.reverse(u8, buf[0..digits_used]);
    return buf[digits_used..];
}

fn less(_: @TypeOf(.{}), a: i32, b: i32) bool {
    return a < b;
}

pub fn main() !void {
    _ = try std.io.getStdIn().reader().readAll(&global_buf);
    var slice: []u8 = &global_buf;
    // var timer = try std.time.Timer.start();

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

    // std.debug.print("parsing input {}us\n", .{timer.read() / 1000});
    // timer.reset();

    std.sort.pdq(i32, ints[0..n], .{}, less);
    // std.debug.print("sorting {}us\n", .{timer.read() / 1000});
    // timer.reset();

    slice = &global_buf;
    for (ints[0..n]) |i| {
        var x: i64 = i;
        if (x < 0) {
            x = -x;
            slice[0] = '-';
            slice = slice[1..];
        }
        // slice = write_slow(slice, @intCast(x));
        slice = write_fast(slice, @intCast(x));

        slice[0] = ' ';
        slice = slice[1..];
    }
    try std.io.getStdOut().writer().writeAll(global_buf[0 .. global_buf.len - slice.len]);
    // std.debug.print("parsing output {}us\n", .{timer.read() / 1000});
    // timer.reset();
}
