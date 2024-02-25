const std = @import("std");
const builtin = @import("builtin");

const MAXN = 500_000;
var global_buf: [MAXN * 16]u8 align(64) = undefined;
var ints: [MAXN]i32 = undefined;
var glob_n: usize = 0;

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
    const t1: u32 = map_two(@intCast(val / 100));
    const t2: u32 = map_two(@intCast(val % 100));

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

inline fn write_1e8(buf: []u8, val: u32) []u8 {
    if (val < 1e4) {
        return write_1e4(buf, val);
    }
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
    // switch (builtin.target.cpu.arch.endian()) {
    //     .big => return write_slow(buf, val),
    //     else => {},
    // }

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

fn test_sort_impl(sorting_fn: anytype, comptime T: type, comptime len: comptime_int) !void {
    var nums: [len]T = undefined;
    var check: [len]T = undefined;
    var rand: T = 0;
    rand +%= 127;
    const utils = struct {
        fn less(_: @TypeOf(.{}), a: T, b: T) bool {
            return a < b;
        }
    };
    for (0..len) |i| {
        rand *%= 7;
        nums[i] = rand;
        check[i] = rand;
    }

    sorting_fn(nums[0..len]);
    std.sort.pdq(T, check[0..len], .{}, utils.less);

    for (0..len) |i| {
        try std.testing.expectEqual(check[i], nums[i]);
    }
}

fn test_sortf_impl(sorting_fn: anytype, comptime T: type, comptime len: comptime_int) !void {
    var nums: [len]T = undefined;
    var check: [len]T = undefined;
    var rand: usize = 0;
    rand +%= 63799;
    const utils = struct {
        fn less(_: @TypeOf(.{}), a: T, b: T) bool {
            return a < b;
        }
    };
    for (0..len) |i| {
        rand *%= 13789;
        rand +%= 19237;
        const t1: T = @floatFromInt(rand);

        rand *%= 13789;
        rand +%= 19237;
        const t2: T = @floatFromInt(rand);

        nums[i] = t1 + t2 / 1000.0;
        check[i] = t1 + t2 / 1000.0;
    }

    sorting_fn(nums[0..len]);
    std.sort.pdq(T, check[0..len], .{}, utils.less);

    for (0..len) |i| {
        try std.testing.expectEqual(check[i], nums[i]);
    }
}

fn test_sort(sorting_fn: anytype, comptime T: type, comptime len: comptime_int) !void {
    return switch (@typeInfo(T)) {
        .Int => test_sort_impl(sorting_fn, T, len),
        .Float => test_sortf_impl(sorting_fn, T, len),
        else => @compileError("unsupported"),
    };
}

fn insertion_sort(arr: anytype) void {
    for (1..arr.len) |i| {
        const to_be_inserted = arr[i];
        var j = i;
        while (j > 0 and arr[j - 1] > to_be_inserted) : (j -= 1) {
            arr[j] = arr[j - 1];
        }
        arr[j] = to_be_inserted;
    }
}

test "insertion_sort" {
    inline for ([_]type{ u8, i8, u16, i16, u32, i32, u64, i64, u128, i128, f32, f64, f80, f128 }) |T| {
        inline for ([_]comptime_int{ 1, 2, 3, 4, 10, 100, 1000 }) |len| {
            try test_sort(radix_sort, T, len);
        }
    }
}

fn basic_radix_sort_unsigned_impl(comptime Log2NumBuckets: comptime_int, arr: anytype, out: anytype) void {
    const Bits = @bitSizeOf(@TypeOf(arr[0]));
    const NumBuckets = 1 << Log2NumBuckets;
    const uvec = @Vector(NumBuckets, usize);
    var counts: uvec = undefined;
    const n = arr.len;

    const iters = (Bits + Log2NumBuckets - 1) / Log2NumBuckets;
    var a = arr;
    var b = out;
    for (0..iters) |offset| {
        const shift = Log2NumBuckets * offset;
        const mask = NumBuckets - 1;

        counts = @splat(0);
        for (a) |e| {
            counts[@intCast((e >> @intCast(shift)) & mask)] += 1;
        }

        for (1..NumBuckets) |i| {
            counts[i] += counts[i - 1];
        }

        for (0..n) |r| {
            const i = n - r - 1;
            const c = &counts[@intCast((a[i] >> @intCast(shift)) & mask)];

            c.* -= 1;
            b[c.*] = a[i];
        }
        const c = a;
        a = b;
        b = c;
    }

    if (iters % 2 == 1) {
        @memcpy(arr, a);
    }
}

fn SliceCast(comptime T: type, ptr: anytype, len: usize) []T {
    const p: [*]T = @ptrCast(@alignCast(ptr));
    return p[0..len];
}

fn radix_sort(arr: anytype) void {
    const Bits = @bitSizeOf(@TypeOf(arr[0]));
    const SortType = std.meta.Int(.unsigned, Bits);
    const to_sort = SliceCast(SortType, arr.ptr, arr.len);

    const FlipHighest = switch (@typeInfo(@TypeOf(arr[0]))) {
        .Int => |info| switch (info.signedness) {
            .signed => true,
            .unsigned => false,
        },
        else => false,
    };

    const utils = struct {
        fn flip(a: []SortType) void {
            const VecSize = 16;
            const Vec = @Vector(VecSize, SortType);
            var s = a;

            const mask = 1 << (Bits - 1);

            while (s.len >= VecSize) : (s = s[VecSize..]) {
                var tmp: Vec = s[0..VecSize].*;
                tmp ^= @splat(mask);

                for (0..VecSize) |i| {
                    s[i] = tmp[i];
                }
            }

            for (s) |*e| {
                e.* ^= mask;
            }
        }
    };

    if (FlipHighest) {
        // std.testing.expect(false) catch @panic("sad");
        utils.flip(to_sort);
    }

    // we already have a global buffer thats big enough and aligned properly so why not use it
    const out = SliceCast(SortType, &global_buf[0], arr.len);
    basic_radix_sort_unsigned_impl(8, to_sort, out);

    @memcpy(out, to_sort);

    if (FlipHighest) {
        utils.flip(to_sort);
    }
}

test "radix_sort" {
    inline for ([_]type{ u8, i8, u16, i16, u32, i32, u64, i64, u128, i128, f32, f64, f80, f128 }) |T| {
        inline for ([_]comptime_int{ 1, 2, 3, 4, 10, 100, 1000, 10000 }) |len| {
            try test_sort(radix_sort, T, len);
        }
    }
}

pub fn main() !void {
    _ = try std.io.getStdIn().reader().readAll(&global_buf);
    var slice: []u8 = &global_buf;
    const print = false;
    var timer = try std.time.Timer.start();

    while ('0' <= slice[0] and slice[0] <= '9') : (slice = slice[1..]) {
        glob_n = glob_n * 10 + slice[0] - '0';
    }

    for (0..glob_n) |i| {
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

    if (print) {
        std.debug.print("parsing input {}us\n", .{timer.read() / 1000});
        timer.reset();
    }

    // std.sort.pdq(i32, ints[0..glob_n], .{}, less);
    radix_sort(ints[0..glob_n]);

    if (print) {
        std.debug.print("sorting {}us\n", .{timer.read() / 1000});
        timer.reset();
    }

    slice = &global_buf;
    for (ints[0..glob_n]) |i| {
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

    if (print) {
        std.debug.print("printing output {}us\n", .{timer.read() / 1000});
        timer.reset();
    }
}
