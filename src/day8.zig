const std = @import("std");
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;

const glut = @cImport(@cInclude("GL/glut.h"));

const HeightMap = struct {
    size: usize,
    input: []const u8,

    fn init(input: []const u8) HeightMap {
        const index = std.mem.indexOf(u8, input, "\n");
        return .{ .input = input, .size = index.? };
    }

    inline fn toTop(self: HeightMap, row: usize, col: usize, i: usize) usize {
        std.debug.assert(row - i >= 0 and row - i < self.size);
        return (row - i) * (self.size + 1) + col;
    }

    inline fn toBottom(self: HeightMap, row: usize, col: usize, i: usize) usize {
        std.debug.assert(row + i >= 0 and row + i < self.size);
        return (row + i) * (self.size + 1) + col;
    }

    inline fn toLeft(self: HeightMap, row: usize, col: usize, i: usize) usize {
        std.debug.assert(col - i >= 0 and col - i < self.size);
        return row * (self.size + 1) + col - i;
    }

    inline fn toRight(self: HeightMap, row: usize, col: usize, i: usize) usize {
        std.debug.assert(col + i >= 0 and col + i < self.size);
        return row * (self.size + 1) + col + i;
    }

    inline fn fromTop(self: HeightMap, col: usize, i: usize) usize {
        std.debug.assert(i < self.size);
        return i * (self.size + 1) + col;
    }

    inline fn fromBottom(self: HeightMap, col: usize, i: usize) usize {
        return self.fromTop(col, self.size - i - 1);
    }

    inline fn fromLeft(self: HeightMap, row: usize, i: usize) usize {
        std.debug.assert(i < self.size);
        return row * (self.size + 1) + i;
    }

    inline fn fromRight(self: HeightMap, row: usize, i: usize) usize {
        return self.fromLeft(row, self.size - i - 1);
    }

    inline fn height(self: HeightMap, index: usize) u8 {
        return self.input[index] - '0' + 1;
    }
};

fn part1(allocator: Allocator, input: []const u8) !usize {
    const height_map = HeightMap.init(input);

    var visible_set = try std.bit_set.DynamicBitSet.initEmpty(allocator, input.len);
    defer visible_set.deinit();

    inline for (.{ "fromTop", "fromBottom", "fromLeft", "fromRight" }) |method| {
        var col: usize = 0;
        while (col < height_map.size) : (col += 1) {
            var max: u8 = 0;
            var i: usize = 0;
            while (i < height_map.size) : (i += 1) {
                const index = @field(HeightMap, method)(height_map, col, i);
                const height = height_map.height(index);
                if (height > max) {
                    max = height;
                    visible_set.set(index);
                    continue;
                }
            }
        }
    }

    return visible_set.count();
}

fn part2(allocator: Allocator, input: []const u8) !usize {
    const height_map = HeightMap.init(input);

    const scores = try allocator.alloc(usize, input.len);
    defer allocator.free(scores);

    for (scores) |*score| {
        score.* = 1;
    }

    var row: usize = 0;
    while (row < height_map.size) : (row += 1) {
        var col: usize = 0;
        while (col < height_map.size) : (col += 1) {
            const current_index = height_map.fromLeft(row, col);
            const current_height = height_map.height(current_index);

            inline for (.{ "toTop", "toBottom", "toLeft", "toRight" }) |method, method_idx| {
                var upper_limit = switch (method_idx) {
                    0 => row,
                    1 => height_map.size - 1 - row,
                    2 => col,
                    3 => height_map.size - 1 - col,
                    else => unreachable,
                };
                var local_count: usize = 0;

                var i: usize = 1;
                while (i <= upper_limit) : (i += 1) {
                    const index = @field(HeightMap, method)(height_map, row, col, i);
                    const height = height_map.height(index);
                    local_count += 1;
                    if (height >= current_height) {
                        break;
                    }
                }
                scores[current_index] *= local_count;
            }
        }
    }

    return std.sort.max(usize, scores, {}, struct {
        fn lessThan(_: void, lhs: usize, rhs: usize) bool {
            return lhs < rhs;
        }
    }.lessThan).?;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input/day8.txt", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

    const total = try part1(allocator, content);
    std.debug.print("part 1: {d}\n", .{total});
    const score = try part2(allocator, content);
    std.debug.print("part 2: {d}\n", .{score});
}

test "sample" {
    const allocator = std.testing.allocator;
    const content =
        \\30373
        \\25512
        \\65332
        \\33549
        \\35390
        \\
    ;
    const total = try part1(allocator, content);
    try expectEqual(@as(usize, 21), total);
    const score = try part2(allocator, content);
    try expectEqual(@as(usize, 8), score);
}
