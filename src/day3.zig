const std = @import("std");

fn part1(input: []const u8) u32 {
    var line_it = std.mem.split(u8, std.mem.trimRight(u8, input, "\n"), "\n");
    var sum: u32 = 0;
    while (line_it.next()) |line| {
        const first = Compartment.init(line[0 .. line.len / 2]);
        const second = Compartment.init(line[line.len / 2 ..]);
        var working_set = first;
        working_set.items.setIntersection(second.items);
        if (working_set.items.findFirstSet()) |index| {
            sum += @intCast(u32, index);
        }
    }
    return sum;
}

fn part2(input: []const u8) u32 {
    var line_it = std.mem.split(u8, std.mem.trimRight(u8, input, "\n"), "\n");
    var sum: u32 = 0;
    while (true) {
        const first = Compartment.init(line_it.next() orelse break);
        const second = Compartment.init(line_it.next().?);
        const third = Compartment.init(line_it.next().?);
        var working_set = first;
        working_set.items.setIntersection(second.items);
        working_set.items.setIntersection(third.items);
        if (working_set.items.findFirstSet()) |index| {
            sum += @intCast(u32, index);
        }
    }
    return sum;
}

const Compartment = struct {
    const BitSet = std.bit_set.IntegerBitSet('z' - 'a' + 1 + 'Z' - 'A' + 1 + 1); // one more space for zero
    items: BitSet,

    fn init(line: []const u8) Compartment {
        var bit_set = BitSet.initEmpty();
        for (line) |b| {
            const item: Item = .{ .id = b };
            bit_set.set(item.getPriority());
        }
        return .{ .items = bit_set };
    }
};

const Item = struct {
    id: u8,

    fn getPriority(self: Item) u8 {
        std.debug.assert(self.id >= 'A' and self.id <= 'Z' or self.id >= 'a' and self.id <= 'z');
        if (self.id >= 'a') {
            return self.id - 'a' + 1;
        } else {
            return self.id - 'A' + 27;
        }
    }

    fn initPriority(value: u8) Item {
        std.debug.assert(value >= 1 and value < 27);
        return .{ .id = if (value >= 27) {
            return 'A' + value - 27;
        } else {
            return 'a' + value - 1;
        } };
    }
};

test "sample" {
    const testcase: []const u8 =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
        \\
    ;
    try std.testing.expectEqual(@as(u32, 157), part1(testcase));
    try std.testing.expectEqual(@as(u32, 70), part2(testcase));
}

pub fn main() !void {
    const allocator: std.mem.Allocator = std.heap.page_allocator;

    const file: std.fs.File = try std.fs.cwd().openFile("input/day3.txt", .{});
    defer file.close();

    const stat = try file.stat();

    const input = try allocator.alloc(u8, stat.size);
    defer allocator.free(input);

    _ = try file.readAll(input);

    std.log.info("part 1: {d}", .{part1(input)});
    std.log.info("part 2: {d}", .{part2(input)});
}
