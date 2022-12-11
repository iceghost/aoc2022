const std = @import("std");
const Allocator = std.mem.Allocator;

const Part = enum {
    one,
    two,
};

const Parser = struct {
    fn parse(allocator: Allocator, input: []const u8, comptime part: Part) !MonkeyList(part) {
        const len = std.mem.count(u8, input, "\n\n") + 1;
        const monkey_list = try allocator.alloc(Monkey, len);

        var monkey_input_iter = std.mem.split(
            u8,
            std.mem.trimRight(u8, input, "\n"),
            "\n\n",
        );
        var i: usize = 0;
        while (monkey_input_iter.next()) |monkey_input| : (i += 1) {
            monkey_list[i] = try Parser.parseMonkey(allocator, monkey_input);
        }

        const inspect_counts = try allocator.alloc(u64, len);
        for (inspect_counts) |*count| {
            count.* = 0;
        }

        return .{
            .monkey_list = monkey_list,
            .inspect_counts = inspect_counts,
        };
    }

    fn parseMonkey(allocator: Allocator, input: []const u8) !Monkey {
        var line_iter = std.mem.split(u8, input, "\n");
        _ = line_iter.next().?;
        const item_list = try Parser.parseItemList(allocator, line_iter.next().?[18..]);
        const operation = try Parser.parseOperation(line_iter.next().?[19..]);
        const divisor = try std.fmt.parseInt(u8, line_iter.next().?[21..], 0);
        const true_branch = try std.fmt.parseInt(u8, line_iter.next().?[29..], 0);
        const false_branch = try std.fmt.parseInt(u8, line_iter.next().?[30..], 0);

        return .{
            .items = item_list,
            .operation = operation,
            .divisor = divisor,
            .true_branch = true_branch,
            .false_branch = false_branch,
        };
    }

    fn parseItemList(allocator: Allocator, input: []const u8) !Monkey.Queue {
        var item_list: Monkey.Queue = Monkey.Queue.init(allocator);
        errdefer item_list.deinit();

        var i: usize = 0;
        var token_iter = std.mem.tokenize(u8, input, ", ");
        while (token_iter.next()) |token| : (i += 1) {
            try item_list.writeItem(try std.fmt.parseInt(u64, token, 0));
        }

        return item_list;
    }

    fn parseOperation(input: []const u8) !Operation {
        var token_iter = std.mem.tokenize(u8, input, " ");
        const left = try Parser.parseOperand(token_iter.next().?);
        const operator = try Parser.parseOperator(token_iter.next().?);
        const right = try Parser.parseOperand(token_iter.next().?);
        return .{ .left = left, .op = operator, .right = right };
    }

    fn parseOperand(input: []const u8) !Operation.Operand {
        if (std.mem.eql(u8, input, "old")) {
            return .old;
        }
        return .{ .lit = try std.fmt.parseInt(u64, input, 0) };
    }

    fn parseOperator(input: []const u8) !Operation.Operator {
        inline for (.{ .{ "+", .add }, .{ "*", .mul } }) |item| {
            if (std.mem.eql(u8, input, item[0])) {
                return item[1];
            }
        }
        return error.UnrecognizedOperator;
    }
};

const Operation = struct {
    const Operand = union(enum) {
        lit: u64,
        old,
    };
    const Operator = enum {
        add,
        mul,
    };

    left: Operand,
    op: Operator,
    right: Operand,

    fn evalMod(self: Operation, input: u64, common_multiplier: u64) u64 {
        return self.eval(input) % common_multiplier;
    }

    fn eval(self: Operation, input: u64) u64 {
        const left = Operation.evalOperand(self.left, input);
        const right = Operation.evalOperand(self.right, input);
        return switch (self.op) {
            .add => left + right,
            .mul => left * right,
        };
    }

    fn evalOperand(operand: Operand, input: u64) u64 {
        return switch (operand) {
            .lit => |lit| lit,
            .old => input,
        };
    }
};

const Monkey = struct {
    const Queue = std.fifo.LinearFifo(u64, .Dynamic);

    items: Queue,
    operation: Operation,
    divisor: u8,
    true_branch: usize,
    false_branch: usize,
};

fn MonkeyList(comptime part: Part) type {
    return struct {
        const Self = @This();

        monkey_list: []Monkey,
        round: usize = 0,

        inspect_counts: []u64,

        common_multiplier: u64 = 0,

        fn roundMonkeyList(self: *Self) !void {
            self.common_multiplier = 1;
            for (self.monkey_list) |monkey| {
                self.common_multiplier *= monkey.divisor;
            }
            for (self.monkey_list) |_, i| {
                try self.roundMonkey(i);
            }
            self.round += 1;
        }

        fn roundMonkey(self: Self, i: usize) !void {
            const monkey = &self.monkey_list[i];
            while (monkey.items.readItem()) |item| {
                var new_item = monkey.operation.evalMod(item, self.common_multiplier);

                if (part == .one) new_item /= 3;

                const branch = if (new_item % monkey.divisor == 0)
                    monkey.true_branch
                else
                    monkey.false_branch;

                try self.monkey_list[branch].items.writeItem(new_item);

                self.inspect_counts[i] += 1;
            }
        }
    };
}

fn part1(allocator: Allocator, input: []const u8) !u64 {
    var monkey_list = try Parser.parse(allocator, input, Part.one);
    while (monkey_list.round != 20) {
        try monkey_list.roundMonkeyList();
    }
    std.sort.sort(u64, monkey_list.inspect_counts, {}, comptime std.sort.desc(u64));
    return monkey_list.inspect_counts[0] * monkey_list.inspect_counts[1];
}

fn part2(allocator: Allocator, input: []const u8) !u64 {
    var monkey_list = try Parser.parse(allocator, input, Part.two);
    while (monkey_list.round != 10000) {
        try monkey_list.roundMonkeyList();
    }
    std.sort.sort(u64, monkey_list.inspect_counts, {}, comptime std.sort.desc(u64));
    return monkey_list.inspect_counts[0] * monkey_list.inspect_counts[1];
}

test "single monkey" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const testcase =
        \\Monkey 0:
        \\  Starting items: 79, 98
        \\  Operation: new = old * 19
        \\  Test: divisible by 23
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 3
    ;
    const monkey = try Parser.parseMonkey(allocator, testcase);

    try std.testing.expectEqual(@as(u8, 23), monkey.divisor);
}

test "operation" {
    const operation = Operation{
        .left = .{ .lit = 10 },
        .op = .add,
        .right = .old,
    };
    try std.testing.expectEqual(@as(u64, 32), operation.eval(22));

    const mul = try Parser.parseOperation("old * 10");
    try std.testing.expectEqual(@as(u64, 220), mul.eval(22));
}

test "sample" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const testcase =
        \\Monkey 0:
        \\  Starting items: 79, 98
        \\  Operation: new = old * 19
        \\  Test: divisible by 23
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 3
        \\
        \\Monkey 1:
        \\  Starting items: 54, 65, 75, 74
        \\  Operation: new = old + 6
        \\  Test: divisible by 19
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 0
        \\
        \\Monkey 2:
        \\  Starting items: 79, 60, 97
        \\  Operation: new = old * old
        \\  Test: divisible by 13
        \\    If true: throw to monkey 1
        \\    If false: throw to monkey 3
        \\
        \\Monkey 3:
        \\  Starting items: 74
        \\  Operation: new = old + 3
        \\  Test: divisible by 17
        \\    If true: throw to monkey 0
        \\    If false: throw to monkey 1
        \\
    ;
    try std.testing.expectEqual(@as(u64, 10605), try part1(allocator, testcase));
    try std.testing.expectEqual(@as(u64, 2713310158), try part2(allocator, testcase));
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input/day11.txt", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    std.debug.print("part 1: {}\n", .{try part1(allocator, content)});
    std.debug.print("part 2: {}\n", .{try part2(allocator, content)});
}
