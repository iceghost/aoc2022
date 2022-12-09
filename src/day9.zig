const std = @import("std");
const Allocator = std.mem.Allocator;
const expectEqual = std.testing.expectEqual;

const Position = struct {
    x: i32,
    y: i32,

    fn origin() Position {
        return .{ .x = 0, .y = 0 };
    }

    const HashContext = struct {
        pub fn hash(_: @This(), pos: Position) u64 {
            // pack two i32s into an u64
            return @intCast(u64, @bitCast(u32, pos.x)) << 32 | @intCast(u64, @bitCast(u32, pos.y));
        }

        pub fn eql(_: @This(), a: Position, b: Position) bool {
            return a.x == b.x and a.y == b.y;
        }
    };
};

const Direction = enum {
    left,
    right,
    up,
    down,
};

fn Rope(comptime n_knots: comptime_int) type {
    return struct {
        const Self = @This();

        knot_list: [n_knots]Position,

        fn init() Self {
            return .{
                .knot_list = .{Position.origin()} ** n_knots,
            };
        }

        fn move(self: *Self, dir: Direction) void {
            var head = &self.knot_list[0];
            switch (dir) {
                .left => head.x -= 1,
                .right => head.x += 1,
                .up => head.y += 1,
                .down => head.y -= 1,
            }

            // preserve physics

            var i: u8 = 0;
            while (i < n_knots - 1) : (i += 1) {
                head = &self.knot_list[i];
                const tail = &self.knot_list[i + 1];

                const dx = head.x - tail.x;
                const dy = head.y - tail.y;

                const hdx = @divTrunc(dx, 2);
                const hdy = @divTrunc(dy, 2);

                if (hdx == 0 and hdy == 0) break;

                tail.x += if (hdx == 0) dx else hdx;
                tail.y += if (hdy == 0) dy else hdy;
            }
        }

        fn tailPosition(self: Self) Position {
            return self.knot_list[self.knot_list.len - 1];
        }
    };
}

fn exec(allocator: Allocator, input: []const u8, comptime n_knots: comptime_int) !usize {
    var rope = Rope(n_knots).init();

    var position_set = std.HashMap(
        Position,
        void,
        Position.HashContext,
        std.hash_map.default_max_load_percentage,
    ).init(allocator);
    defer position_set.deinit();

    try position_set.put(Position.origin(), {});

    var line_iter = std.mem.split(u8, std.mem.trimRight(u8, input, "\n"), "\n");
    while (line_iter.next()) |line| {
        var token_iter = std.mem.split(u8, line, " ");

        const direction: Direction = switch (token_iter.next().?[0]) {
            'R' => .right,
            'L' => .left,
            'U' => .up,
            'D' => .down,
            else => unreachable,
        };

        var times = try std.fmt.parseInt(u8, token_iter.next().?, 10);
        while (times > 0) : (times -= 1) {
            rope.move(direction);
            try position_set.put(rope.tailPosition(), {});
        }
    }

    return position_set.count();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const file = try std.fs.cwd().openFile("input/day9.txt", .{});
    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    std.debug.print("part 1: {d}\n", .{try exec(allocator, content, 2)});
    std.debug.print("part 2: {d}\n", .{try exec(allocator, content, 10)});
}

test {
    const allocator = std.testing.allocator;
    const testcase =
        \\R 4
        \\U 4
        \\L 3
        \\D 1
        \\R 4
        \\D 1
        \\L 5
        \\R 2
        \\
    ;
    const part1 = try exec(allocator, testcase, 2);
    try expectEqual(@as(usize, 13), part1);
    const part2 = try exec(allocator, testcase, 10);
    try expectEqual(@as(usize, 1), part2);

    const bigger =
        \\R 5
        \\U 8
        \\L 8
        \\D 3
        \\R 17
        \\D 10
        \\L 25
        \\U 20
        \\
    ;
    try expectEqual(@as(usize, 36), try exec(allocator, bigger, 10));
}
