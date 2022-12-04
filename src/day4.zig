const std = @import("std");

const Parser = struct {
    file: std.fs.File,

    fn pair(self: Parser) ![2]Assignment {
        const ass1 = Assignment.init(try self.id('-'), try self.id(','));
        const ass2 = Assignment.init(try self.id('-'), try self.id('\n'));
        return .{ ass1, ass2 };
    }

    fn id(self: Parser, delimiter: u8) !u8 {
        var buf: [5]u8 = undefined;
        const slice = try self.file.reader().readUntilDelimiter(&buf, delimiter);
        return try std.fmt.parseInt(u8, slice, 10);
    }
};

const Assignment = struct {
    const BitSet = std.bit_set.IntegerBitSet(100);
    sections: BitSet,

    fn init(start: u8, end: u8) Assignment {
        var ass: Assignment = .{ .sections = BitSet.initEmpty() };
        ass.sections.setRangeValue(.{ .start = start, .end = end + 1 }, true);
        return ass;
    }

    fn lessThan(_: void, a1: Assignment, a2: Assignment) bool {
        return a1.sections.count() < a2.sections.count();
    }
};

fn checkAssignmentsContain(assignments: [2]Assignment) bool {
    const i = std.sort.argMax(Assignment, &assignments, {}, Assignment.lessThan).?;
    var merged = assignments[i];
    merged.sections.setUnion(assignments[1 - i].sections);
    return merged.sections.mask == assignments[i].sections.mask;
}

fn checkAssignmentsOverlap(assignments: [2]Assignment) bool {
    var intersected = assignments[0];
    intersected.sections.setIntersection(assignments[1].sections);
    return intersected.sections.mask != 0;
}

test "sample" {
    const TestFile = @import("test_utils.zig").TestFile;
    var file = try TestFile.init(
        \\2-4,6-8
        \\2-3,4-5
        \\5-7,7-9
        \\2-8,3-7
        \\6-6,4-6
        \\2-6,4-8
        \\
    );
    defer file.deinit();

    const parser: Parser = .{ .file = file.file };
    try std.testing.expect(!checkAssignmentsContain(try parser.pair()));
    try file.file.seekTo(0);

    var contains_count: u32 = 0;
    var overlaps_count: u32 = 0;
    while (true) {
        const pair = parser.pair() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        if (checkAssignmentsContain(pair)) contains_count += 1;
        if (checkAssignmentsOverlap(pair)) overlaps_count += 1;
    }

    try std.testing.expectEqual(@as(u32, 2), contains_count);
    try std.testing.expectEqual(@as(u32, 4), overlaps_count);
}

pub fn main() !void {
    const file: std.fs.File = try std.fs.cwd().openFile("input/day4.txt", .{});
    defer file.close();
    const parser: Parser = .{ .file = file };

    var contains_count: u32 = 0;
    var overlaps_count: u32 = 0;
    while (true) {
        const pair = parser.pair() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        if (checkAssignmentsContain(pair)) contains_count += 1;
        if (checkAssignmentsOverlap(pair)) overlaps_count += 1;
    }
    std.debug.print("{d}", .{contains_count});
    std.debug.print("{d}", .{overlaps_count});
}
