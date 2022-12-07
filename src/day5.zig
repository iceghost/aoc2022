const std = @import("std");
const Allocator = std.mem.Allocator;

const Parser = struct {
    fn singleLevel(allocator: Allocator, input: []const u8) ![]const ?u8 {
        const n_crates = (input.len + 1) / 4;
        var bytes = try allocator.alloc(?u8, n_crates);
        var i: usize = 0;
        while (i < n_crates) : (i += 1) {
            bytes[i] = if (input[4 * i + 1] == ' ') blk: {
                break :blk null;
            } else blk: {
                break :blk input[4 * i + 1];
            };
        }
        return bytes;
    }

    fn singleInstruction(input: []const u8) !Instruction {
        var instruction: Instruction = undefined;
        var token_iterator = std.mem.tokenize(u8, input, " ");
        inline for (.{ "n_crates", "from", "to" }) |field_name| {
            // ignore text
            _ = token_iterator.next().?;
            const value = try std.fmt.parseInt(u8, token_iterator.next().?, 10);
            @field(instruction, field_name) = value;
        }
        return instruction;
    }
};

const Instruction = struct {
    n_crates: u8,
    from: u8,
    to: u8,
};

const CrateStackListBuilder = struct {
    const List = std.ArrayList(*CrateStack);

    list: List,
    allocator: Allocator,

    fn init(allocator: Allocator) CrateStackListBuilder {
        const list = List.init(allocator);
        return .{ .list = list, .allocator = allocator };
    }

    fn addLevel(self: *CrateStackListBuilder, level: []const ?u8) !void {
        while (self.list.items.len < level.len) {
            const crate_stack = try self.allocator.create(CrateStack);
            crate_stack.* = CrateStack.init(self.allocator);
            try self.list.append(crate_stack);
        }
        for (level) |crate, i| {
            if (crate) |c| {
                try self.list.items[i].stack.append(c);
            }
        }
    }

    fn finalize(self: CrateStackListBuilder) []const *CrateStack {
        for (self.list.items) |stack| {
            std.mem.reverse(u8, stack.stack.items);
        }
        return self.list.items;
    }
};

const CrateStack = struct {
    const Stack = std.ArrayList(u8);

    stack: Stack,

    fn init(allocator: Allocator) CrateStack {
        return .{ .stack = Stack.init(allocator) };
    }

    fn deinit(self: CrateStack) void {
        self.stack.deinit();
    }
};

const Version = enum {
    cm9000,
    cm9001,
};

fn execute(allocator: Allocator, input: []const u8, comptime version: Version) ![]u8 {
    var section_iterator = std.mem.split(u8, input, "\n\n");

    const crate_stack_list = init: {
        var crate_stack_list_builder = CrateStackListBuilder.init(allocator);
        var crates_section_iterator = std.mem.split(
            u8,
            section_iterator.next().?,
            "\n",
        );
        while (crates_section_iterator.next()) |line| {
            const level = try Parser.singleLevel(allocator, line);
            defer allocator.free(level);

            if (level[0]) |l| if (l == '1') break;
            try crate_stack_list_builder.addLevel(level);
        }
        break :init crate_stack_list_builder.finalize();
    };

    defer allocator.free(crate_stack_list);
    defer for (crate_stack_list) |crate_stack| {
        crate_stack.deinit();
        allocator.destroy(crate_stack);
    };

    var instruction_section_iterator = std.mem.split(
        u8,
        std.mem.trimRight(u8, section_iterator.next().?, "\n"),
        "\n",
    );

    while (instruction_section_iterator.next()) |line| {
        const instruction = try Parser.singleInstruction(line);
        _ = try execInstruction(crate_stack_list, instruction, version);
    }

    var result = try allocator.alloc(u8, crate_stack_list.len);
    for (crate_stack_list) |stack, i| {
        result[i] = stack.stack.items[stack.stack.items.len - 1];
    }
    return result;
}

fn execInstruction(crate_stack_list: []const *CrateStack, instruction: Instruction, comptime version: Version) !void {
    const from_slice = crate_stack_list[instruction.from - 1].stack.items;
    const move_slice = from_slice[from_slice.len - instruction.n_crates ..];
    if (version == .cm9000) {
        std.mem.reverse(u8, move_slice);
    }
    try crate_stack_list[instruction.to - 1].stack.appendSlice(move_slice);
    try crate_stack_list[instruction.from - 1].stack.resize(from_slice.len - instruction.n_crates);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const file = try std.fs.cwd().openFile("input/day5.txt", .{});
    defer file.close();
    const testcase = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

    const part1 = try execute(allocator, testcase, .cm9000);
    defer allocator.free(part1);
    std.debug.print("part 1: {s}\n", .{part1});

    const part2 = try execute(allocator, testcase, .cm9001);
    defer allocator.free(part2);
    std.debug.print("part 2: {s}\n", .{part2});
}

test "sample" {
    const allocator = std.testing.allocator;
    const testcase =
        \\    [D]
        \\[N] [C]
        \\[Z] [M] [P]
        \\ 1   2   3
        \\
        \\move 1 from 2 to 1
        \\move 3 from 1 to 3
        \\move 2 from 2 to 1
        \\move 1 from 1 to 2
    ;
    const result1 = try execute(allocator, testcase, .cm9000);
    defer allocator.free(result1);
    try std.testing.expectEqualSlices(u8, "CMZ", result1);

    const result2 = try execute(allocator, testcase, .cm9001);
    defer allocator.free(result2);
    try std.testing.expectEqualSlices(u8, "MCD", result2);
}

test "parse instruction" {
    const raw = "move 3 from 10 to 4";
    const instruction = try Parser.singleInstruction(raw);
    try std.testing.expectEqual(@as(u8, 3), instruction.n_crates);
    try std.testing.expectEqual(@as(u8, 10), instruction.from);
    try std.testing.expectEqual(@as(u8, 4), instruction.to);
}

test "parse level" {
    const allocator: Allocator = std.testing.allocator;
    const raw = "    [D]     [E]";
    const level = try Parser.singleLevel(allocator, raw);
    defer allocator.free(level);

    try std.testing.expectEqualSlices(?u8, &[_]?u8{ null, 'D', null, 'E' }, level);
}
