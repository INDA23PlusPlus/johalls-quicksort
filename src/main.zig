const std = @import("std");
const builtin = @import("builtin");

const MAXN = 500_000;
var global_buf: [MAXN * 16]u8 align(4) = undefined;
var ints: [MAXN]i32 = undefined;
var n: usize = 0;

// x has to be a pointer
fn as_bytes(x: anytype) []u8 {
    switch (@typeInfo(@TypeOf(x))) {
        .Pointer => {},
        else => @compileError("x should be a pointer"),
    }

    var res: []u8 = undefined;
    res.ptr = @ptrCast(@alignCast(x));
    res.len = @sizeOf(@TypeOf(x.*));
    return res;
}

fn map_two(val: u16) u16 {
    return (val % 10 << 8) + val / 10;
}

// writes the string representation of val to buf if val < 100 and returns the rest of the buffer
fn write_1e2(buf: []u8, val: u32) []u8 {
    var t: u16 = map_two(@intCast(val));

    inline for (0..2) |e| {
        t += '0' << 8 * e;
    }

    t >>= 8 * @as(u4, @intFromBool(val < 10));
    const len: usize = @as(usize, 2) - @intFromBool(val < 10);

    // should compile to a single mov
    for (as_bytes(&t), 0..2) |b, i| {
        buf[i] = b;
    }

    return buf[len..];
}

test "write_1e2" {
    var b1: [2]u8 = undefined;
    var b2: [2]u8 = undefined;
    for (0..100) |i| {
        const printed_to = try std.fmt.bufPrint(&b2, "{}", .{i});
        const len = printed_to.len;
        _ = write_1e2(&b1, @intCast(i));
        // std.debug.print("{s} {s}\n", .{ b1, b2 });
        try std.testing.expect(std.mem.eql(u8, b1[0..len], b2[0..len]));
    }
}

// writes the string representation of val to buf if val < 10000 and returns the rest of the buffer
fn write_1e4(buf: []u8, val: u32) []u8 {
    const t1: u32 = map_two(@intCast(val / 100));
    const t2: u32 = map_two(@intCast(val % 100));

    var t: u32 = t1 + (t2 << 16);

    const zeros = @ctz(t);

    // gotta special case it if val is 0
    const len = 4 - zeros / 8 + @intFromBool(val == 0);
    const shift = 8 * (4 - len);

    inline for (0..4) |e| {
        t += '0' << 8 * e;
    }

    t = @intCast(@as(u64, t) >> @intCast(shift));

    // call to memcpy wasnt being inlined
    // should compile to a single mov
    for (as_bytes(&t), 0..4) |b, i| {
        buf[i] = b;
    }

    return buf[len..];
}

test "write_1e4" {
    var b1: [4]u8 = undefined;
    var b2: [4]u8 = undefined;
    for (0..10_000) |i| {
        const printed_to = try std.fmt.bufPrint(&b2, "{}", .{i});
        const len = printed_to.len;
        _ = write_1e4(&b1, @intCast(i));
        try std.testing.expect(std.mem.eql(u8, b1[0..len], b2[0..len]));
    }
}

fn write_1e4_full(buf: []u8, val: u32) void {
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
    // should compile to a single mov
    for (as_bytes(&t), 0..4) |b, i| {
        buf[i] = b;
    }
}

test "write_1e4_full" {
    var b1: [8]u8 = undefined;
    var b2: [4]u8 = undefined;
    for (0..1_000) |i| {
        const printed_to = try std.fmt.bufPrint(&b2, "{}", .{i});
        const len = printed_to.len;
        write_1e4_full(&b1, @intCast(i));
        const leading_zeros = 4 - len;
        try std.testing.expect(std.mem.eql(u8, b1[leading_zeros..4], b2[0..len]));
    }
    for (1_000..10_000) |i| {
        const printed_to = try std.fmt.bufPrint(&b2, "{}", .{i});
        const len = printed_to.len;
        write_1e4_full(&b1, @intCast(i));
        try std.testing.expect(std.mem.eql(u8, b1[0..len], b2[0..len]));
    }
}

fn write_1e8(buf: []u8, val: u32) []u8 {
    var ret = write_1e4(buf, val / 10_000);
    write_1e4_full(ret, val % 10_000);
    return ret[4..];
}

// idea behind this is to break dependency chains to leverage ILP
// (and let the compiler to the heavy lifting)
fn write_1e8_full(buf: []u8, val: u32) void {
    write_1e4_full(buf[0..4], val / 10_000);
    write_1e4_full(buf[4..8], val % 10_000);
}

// note: may write up to three garbage values into buffer after the end
fn write_fast(buf: []u8, val: u32) []u8 {
    switch (builtin.target.cpu.arch.endian()) {
        .big => return write_slow(buf, val),
        else => {},
    }

    if (val < 100) {
        return write_1e2(buf, val);
    }
    if (val < 10_000) {
        return write_1e4(buf, val);
    }
    if (val < 100_000_000) {
        return write_1e8(buf, val);
    }

    const ret = write_1e2(buf, val / 100_000_000);
    write_1e8_full(ret, val % 100_000_000);

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
