const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;

const Directory = struct {
    parent: *Directory,
    files: std.StringHashMap(File),
    dirs: std.StringHashMap(Directory),

    allocator: Allocator,

    fn init(allocator: Allocator, parent: *Directory) Directory {
        var self: Directory = undefined;
        self.parent = parent;
        self.files = std.StringHashMap(File).init(allocator);
        self.dirs = std.StringHashMap(Directory).init(allocator);
        self.allocator = allocator;
        return self;
    }

    fn deinit(self: *Directory) void {
        self.files.deinit();
        var child_iter = self.dirs.valueIterator();
        while (child_iter.next()) |child| {
            child.deinit();
        }
        self.dirs.deinit();
    }

    fn directSize(self: Directory) u32 {
        var sum: u32 = 0;
        var iter = self.files.valueIterator();
        while (iter.next()) |file| {
            sum += file.size;
        }
        return sum;
    }

    fn totalSize(self: Directory) u32 {
        var sum = self.directSize();
        var iter = self.dirs.valueIterator();
        while (iter.next()) |dir| {
            sum += dir.totalSize();
        }
        return sum;
    }

    fn sizeAtMost(self: Directory, total: *u32, comptime at_most: u32) u32 {
        var sum = self.directSize();

        var iter = self.dirs.valueIterator();
        while (iter.next()) |dir| {
            sum += dir.sizeAtMost(total, at_most);
        }

        if (sum <= at_most) total.* += sum;

        return sum;
    }

    fn free(self: Directory, best: *u32, minimum: u32) u32 {
        var sum = self.directSize();
        var iter = self.dirs.valueIterator();
        while (iter.next()) |dir| {
            const child_size = dir.free(best, minimum);
            sum += child_size;
            if (child_size > minimum) best.* = @min(child_size, best.*);
        }
        return sum;
    }
};

fn lessThan(_: void, a: u32, b: u32) std.math.Order {
    return std.math.order(a, b);
}

const File = struct {
    name: []const u8,
    size: u32,
};

const Parser = struct {
    dir_iter: *Directory,
    root_dir: *Directory,

    fn init() Parser {
        return undefined;
    }

    fn parse(self: *Parser, allocator: Allocator, input: []const u8) !*Directory {
        self.root_dir = try allocator.create(Directory);
        errdefer allocator.destroy(self.root_dir);

        self.root_dir.* = Directory.init(allocator, self.root_dir);
        errdefer self.root_dir.deinit();

        self.dir_iter = self.root_dir;
        var iter = std.mem.split(u8, std.mem.trimRight(u8, input, "\n"), "\n");
        while (iter.next()) |line| {
            try self.parseLine(allocator, line);
        }

        return self.root_dir;
    }

    fn parseLine(self: *Parser, allocator: Allocator, line: []const u8) !void {
        var token_iter = std.mem.tokenize(u8, line, " ");
        const first = token_iter.next().?;

        // commands
        if (std.mem.eql(u8, first, "$")) {
            try self.parseCommand(&token_iter);
            return;
        }

        // directories
        if (std.mem.eql(u8, first, "dir")) {
            const name = token_iter.next().?;
            try self.dir_iter.dirs.put(
                name,
                Directory.init(allocator, self.dir_iter),
            );
            return;
        }

        // files
        const name = token_iter.next().?;
        try self.dir_iter.files.put(name, .{
            .name = name,
            .size = try std.fmt.parseInt(u32, first, 10),
        });
    }

    fn parseCommand(self: *Parser, iter: *std.mem.TokenIterator(u8)) !void {
        const command = iter.next().?;
        if (std.mem.eql(u8, command, "ls")) {
            return;
        }
        if (std.mem.eql(u8, command, "cd")) {
            const arg = iter.next().?;
            if (std.mem.eql(u8, arg, "/")) {
                self.dir_iter = self.root_dir;
                return;
            }
            if (std.mem.eql(u8, arg, "..")) {
                self.dir_iter = self.dir_iter.parent;
                return;
            }
            self.dir_iter = self.dir_iter.dirs.getPtr(arg) orelse return error.DirNotFound;
            return;
        }
        return error.BadInput;
    }
};

fn partOne(dir: Directory) u32 {
    var part1: u32 = 0;
    _ = dir.sizeAtMost(&part1, 1e5);
    return part1;
}

fn partTwo(dir: Directory) u32 {
    var part2: u32 = std.math.maxInt(u32);
    _ = dir.free(&part2, @as(u32, 3e7) - (@as(u32, 7e7) - dir.totalSize()));
    return part2;
}

pub fn main() !void {
    const allocator: Allocator = std.heap.page_allocator;
    const file = try std.fs.cwd().openFile("input/day7.txt", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    var parser = Parser.init();
    const root_dir = try parser.parse(allocator, content);
    defer allocator.destroy(root_dir);
    defer root_dir.deinit();

    std.debug.print("part 1: {d}\n", .{partOne(root_dir.*)});
    std.debug.print("part 2: {d}\n", .{partTwo(root_dir.*)});
}

test "sample" {
    const allocator = std.testing.allocator;
    const testcase =
        \\$ cd /
        \\$ ls
        \\dir a
        \\14848514 b.txt
        \\8504156 c.dat
        \\dir d
        \\$ cd a
        \\$ ls
        \\dir e
        \\29116 f
        \\2557 g
        \\62596 h.lst
        \\$ cd e
        \\$ ls
        \\584 i
        \\$ cd ..
        \\$ cd ..
        \\$ cd d
        \\$ ls
        \\4060174 j
        \\8033020 d.log
        \\5626152 d.ext
        \\7214296 k
        \\
    ;

    var parser = Parser.init();
    const root_dir = try parser.parse(allocator, testcase);
    defer allocator.destroy(root_dir);
    defer root_dir.deinit();

    try expectEqual(@as(u32, 95437), partOne(root_dir.*));
    try expectEqual(@as(u32, 24933642), partTwo(root_dir.*));
}
