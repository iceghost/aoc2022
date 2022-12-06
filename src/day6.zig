const std = @import("std");

fn marker(comptime size: comptime_int, buf: []const u8) ?usize {
    // iterate over windows of size
    var i: usize = 0;
    outer: while (i + size - 1 < buf.len) : (i += 1) {
        var bit_set = std.bit_set.IntegerBitSet('z' - 'a' + 1).initEmpty();

        // build an array of 0, 1, 2, ..., size - 1
        const j_values = comptime blk: {
            var initial: [size]u8 = undefined;
            for (initial) |*value, index| {
                value.* = index;
            }
            break :blk initial;
        };

        // check for duplicated element
        inline for (j_values) |j| {
            const index = buf[i + j] - 'a';
            if (bit_set.isSet(index)) {
                continue :outer;
            }
            if (j != size - 1) {
                bit_set.set(index);
            }
        }

        return i + size;
    }

    return null;
}

fn startOfPacket(buf: []const u8) ?usize {
    return marker(4, buf);
}

fn startOfMessage(buf: []const u8) ?usize {
    return marker(14, buf);
}

const expectEqual = std.testing.expectEqual;

test "sample" {
    const Testcase = struct {
        message: []const u8,
        start_of_packet: usize,
        start_of_message: usize,
    };

    var testcases = std.BoundedArray(Testcase, 5).init(0) catch unreachable;
    try testcases.append(.{ .message = "bvwbjplbgvbhsrlpgdmjqwftvncz", .start_of_packet = 5, .start_of_message = 23 });
    try testcases.append(.{ .message = "nppdvjthqldpwncqszvftbrmjlhg", .start_of_packet = 6, .start_of_message = 23 });
    try testcases.append(.{ .message = "nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg", .start_of_packet = 10, .start_of_message = 29 });
    try testcases.append(.{ .message = "zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw", .start_of_packet = 11, .start_of_message = 26 });

    for (testcases.slice()) |testcase| {
        try expectEqual(@as(usize, testcase.start_of_packet), startOfPacket(testcase.message).?);
    }
    for (testcases.slice()) |testcase| {
        try expectEqual(@as(usize, testcase.start_of_message), startOfMessage(testcase.message).?);
    }
}

pub fn main() !void {
    const allocator: std.mem.Allocator = std.heap.page_allocator;
    const file = try std.fs.cwd().openFile("input/day6.txt", .{});
    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);
    std.debug.print("part 1: {d}\n", .{startOfPacket(content).?});
    std.debug.print("part 2: {d}\n", .{startOfMessage(content).?});
}
