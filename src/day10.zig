const std = @import("std");
const Allocator = std.mem.Allocator;

const Opcode = enum {
    add_x,
    noop,

    fn parse(content: []const u8) !Opcode {
        const map = comptime std.ComptimeStringMap(Opcode, .{
            .{ "addx", .add_x },
            .{ "noop", .noop },
        });
        return map.get(content) orelse error.InvalidOpcode;
    }
};

const Instruction = union(Opcode) {
    add_x: i32,
    noop,
};

const InstructionList = std.ArrayList(Instruction);

fn Interpreter(comptime Context: anytype) type {
    return struct {
        const Self = @This();

        register_x: i32 = 1,

        cycle: usize = 1,
        pc: usize = 0,

        executing: Instruction = .noop,
        cycle_left: u8 = 0,

        instruction_list: []const Instruction,

        context: Context,

        fn next(self: *Self) !void {
            // start of cycle
            if (self.cycle_left == 0) {
                if (self.pc == self.instruction_list.len) return error.Terminated;
                self.executing = self.instruction_list[self.pc];
                switch (self.executing) {
                    .add_x => self.cycle_left = 2,
                    .noop => self.cycle_left = 1,
                }
            }

            // during cycle
            try self.context.during_cycle(self);

            // end of cycle
            self.cycle_left -= 1;
            if (self.cycle_left == 0) {
                switch (self.executing) {
                    .add_x => |offset| {
                        self.register_x += offset;
                    },
                    .noop => {},
                }
                self.pc += 1;
            }
            self.cycle += 1;
        }
    };
}

fn parse(allocator: Allocator, input: []const u8) !InstructionList {
    var instruction_list = InstructionList.init(allocator);

    var line_iter = std.mem.split(u8, std.mem.trimRight(u8, input, "\n"), "\n");
    while (line_iter.next()) |line| {
        var token_iter = std.mem.tokenize(u8, line, " ");

        const opcode = try Opcode.parse(token_iter.next().?);
        const instruction: Instruction = switch (opcode) {
            .add_x => .{
                .add_x = try std.fmt.parseInt(i32, token_iter.next().?, 10),
            },
            .noop => .noop,
        };
        try instruction_list.append(instruction);
    }

    return instruction_list;
}

fn part1(instruction_list: []const Instruction) i32 {
    const Context = struct {
        const Self = @This();

        const milestones = [_]u8{ 20, 60, 100, 140, 180, 220 };

        signal_strength: i32 = 0,
        milestone_idx: u8 = 0,

        fn during_cycle(self: *Self, intpr: *const Interpreter(Self)) !void {
            if (intpr.cycle == @This().milestones[self.milestone_idx]) {
                self.signal_strength += @intCast(i32, intpr.cycle) * intpr.register_x;
                if (self.milestone_idx == milestones.len - 1) return error.MilestoneReached;
                self.milestone_idx += 1;
            }
        }
    };

    var interpreter: Interpreter(Context) = .{
        .instruction_list = instruction_list,
        .context = .{},
    };

    while (true) {
        interpreter.next() catch break;
    }

    return interpreter.context.signal_strength;
}

fn part2(writer: anytype, instruction_list: []const Instruction) !void {
    const Context = struct {
        const Self = @This();

        crt_x: u8 = 0,
        writer: @TypeOf(writer),

        fn during_cycle(self: *Self, intpr: *const Interpreter(Self)) !void {
            if (std.math.absCast(intpr.register_x - self.crt_x) <= 1) {
                _ = try self.writer.write(&[_]u8{'#'});
            } else {
                _ = try self.writer.write(&[_]u8{'.'});
            }

            self.crt_x += 1;
            if (self.crt_x == 40) {
                self.crt_x = 0;
                _ = try self.writer.write(&[_]u8{'\n'});
            }
        }
    };

    var interpreter: Interpreter(Context) = .{
        .instruction_list = instruction_list,
        .context = .{ .writer = writer },
    };

    while (true) {
        interpreter.next() catch break;
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input/day10.txt", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    const instruction_list = try parse(allocator, content);
    defer instruction_list.deinit();

    std.debug.print("part 1: {d}\n", .{part1(instruction_list.items)});
    std.debug.print("part 2:\n", .{});
    try part2(std.io.getStdErr(), instruction_list.items);
}

test "sample" {
    const allocator = std.testing.allocator;
    const testcase =
        \\addx 15
        \\addx -11
        \\addx 6
        \\addx -3
        \\addx 5
        \\addx -1
        \\addx -8
        \\addx 13
        \\addx 4
        \\noop
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx -35
        \\addx 1
        \\addx 24
        \\addx -19
        \\addx 1
        \\addx 16
        \\addx -11
        \\noop
        \\noop
        \\addx 21
        \\addx -15
        \\noop
        \\noop
        \\addx -3
        \\addx 9
        \\addx 1
        \\addx -3
        \\addx 8
        \\addx 1
        \\addx 5
        \\noop
        \\noop
        \\noop
        \\noop
        \\noop
        \\addx -36
        \\noop
        \\addx 1
        \\addx 7
        \\noop
        \\noop
        \\noop
        \\addx 2
        \\addx 6
        \\noop
        \\noop
        \\noop
        \\noop
        \\noop
        \\addx 1
        \\noop
        \\noop
        \\addx 7
        \\addx 1
        \\noop
        \\addx -13
        \\addx 13
        \\addx 7
        \\noop
        \\addx 1
        \\addx -33
        \\noop
        \\noop
        \\noop
        \\addx 2
        \\noop
        \\noop
        \\noop
        \\addx 8
        \\noop
        \\addx -1
        \\addx 2
        \\addx 1
        \\noop
        \\addx 17
        \\addx -9
        \\addx 1
        \\addx 1
        \\addx -3
        \\addx 11
        \\noop
        \\noop
        \\addx 1
        \\noop
        \\addx 1
        \\noop
        \\noop
        \\addx -13
        \\addx -19
        \\addx 1
        \\addx 3
        \\addx 26
        \\addx -30
        \\addx 12
        \\addx -1
        \\addx 3
        \\addx 1
        \\noop
        \\noop
        \\noop
        \\addx -9
        \\addx 18
        \\addx 1
        \\addx 2
        \\noop
        \\noop
        \\addx 9
        \\noop
        \\noop
        \\noop
        \\addx -1
        \\addx 2
        \\addx -37
        \\addx 1
        \\addx 3
        \\noop
        \\addx 15
        \\addx -21
        \\addx 22
        \\addx -6
        \\addx 1
        \\noop
        \\addx 2
        \\addx 1
        \\noop
        \\addx -10
        \\noop
        \\noop
        \\addx 20
        \\addx 1
        \\addx 2
        \\addx 2
        \\addx -6
        \\addx -11
        \\noop
        \\noop
        \\noop
        \\
    ;
    const instruction_list = try parse(allocator, testcase);
    defer instruction_list.deinit();
    const strength = part1(instruction_list.items);
    try std.testing.expectEqual(@as(i32, 13140), strength);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try part2(buffer.writer(), instruction_list.items);
    try std.testing.expectEqualStrings(
        \\##..##..##..##..##..##..##..##..##..##..
        \\###...###...###...###...###...###...###.
        \\####....####....####....####....####....
        \\#####.....#####.....#####.....#####.....
        \\######......######......######......####
        \\#######.......#######.......#######.....
        \\
    , buffer.items);
}
