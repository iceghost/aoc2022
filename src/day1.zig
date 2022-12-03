const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().writer();

pub fn main() !void {
    const allocator: std.mem.Allocator = std.heap.page_allocator;

    const file: std.fs.File = try std.fs.cwd().openFile("input/day1.txt", .{});
    defer file.close();

    var parser = Parser.init(allocator, file);
    var elf_list = try parser.parse();
    defer elf_list.deinit();

    const top_n = elf_list.top_n();

    try stdout.print("part 1: {}\n", .{top_n.max_calories()});
    try stdout.print("part 2: {}\n", .{top_n.top_calories()});
}

const Parser = struct {
    file: std.fs.File,
    allocator: std.mem.Allocator,
    isEOF: bool = false,

    fn init(allocator: std.mem.Allocator, file: std.fs.File) Parser {
        return .{ .file = file, .allocator = allocator };
    }

    fn parse(self: *Parser) !ElfList {
        var elfs = ElfList.init(self.allocator);
        errdefer elfs.deinit();

        while (!self.isEOF) {
            const elf = try self.parseElf();
            try elfs.add_elf(elf);
        }

        return elfs;
    }

    fn parseElf(self: *Parser) !Elf {
        var elf = Elf.init();

        while (try self.parseCalory()) |calory| {
            try elf.add_item(calory);
        }

        return elf;
    }

    fn parseCalory(self: *Parser) !?u32 {
        const calory_text: []u8 = try self.file.reader().readUntilDelimiterOrEofAlloc(self.allocator, '\n', 10) orelse {
            self.isEOF = true;
            return null;
        };
        defer self.allocator.free(calory_text);

        if (calory_text.len == 0) return null;

        return try std.fmt.parseInt(u32, calory_text, 10);
    }
};

const Elf = struct {
    total_calories: u32 = 0,

    pub fn init() Elf {
        return .{};
    }

    pub fn add_item(self: *Elf, calory: u32) !void {
        self.total_calories += calory;
    }
};

const ElfList = struct {
    const CAP = 3;

    fn compareFn(c: void, a: Elf, b: Elf) std.math.Order {
        _ = c;
        return std.math.order(a.total_calories, b.total_calories);
    }
    const Heap = std.PriorityQueue(Elf, void, compareFn);
    top_calories: Heap,

    pub fn init(allocator: std.mem.Allocator) ElfList {
        return .{ .top_calories = Heap.init(allocator, {}) };
    }

    pub fn deinit(self: ElfList) void {
        self.top_calories.deinit();
    }

    pub fn add_elf(self: *ElfList, elf: Elf) !void {
        try self.top_calories.add(elf);
        if (self.top_calories.count() == CAP + 1) {
            _ = self.top_calories.remove();
        }
    }

    pub fn top_n(self: *ElfList) ElfTopN {
        return ElfTopN.init(self);
    }

    const ElfTopN = struct {
        const List = std.BoundedArray(Elf, CAP);

        list: List,

        pub fn init(elf_list: *ElfList) ElfTopN {
            var list = List.init(0) catch unreachable;
            while (elf_list.top_calories.removeOrNull()) |elf| {
                list.append(elf) catch unreachable;
            }
            return .{ .list = list };
        }

        pub fn max_calories(self: ElfTopN) u32 {
            return self.list.buffer[self.list.len - 1].total_calories;
        }

        pub fn top_calories(self: ElfTopN) u32 {
            var sum: u32 = 0;
            for (self.list.buffer) |elf| {
                sum += elf.total_calories;
            }
            return sum;
        }
    };
};

test "sample" {
    const allocator: std.mem.Allocator = std.testing.allocator;

    const text =
        \\1000
        \\2000
        \\3000
        \\
        \\4000
        \\
        \\5000
        \\6000
        \\
        \\7000
        \\8000
        \\9000
        \\
        \\10000
        \\
    ;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file: std.fs.File = try tmp_dir.dir.createFile("sample.txt", .{ .read = true });
    defer file.close();

    try file.writeAll(text);
    try file.seekTo(0);

    var parser = Parser.init(allocator, file);
    var elf_list = try parser.parse();
    defer elf_list.deinit();

    var top_n = elf_list.top_n();

    const max_calories: u32 = top_n.max_calories();
    try std.testing.expectEqual(@as(u32, 24000), max_calories);

    const sum = top_n.top_calories();
    try std.testing.expectEqual(@as(u32, 45000), sum);
}
