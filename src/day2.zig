const std = @import("std");
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    const allocator: std.mem.Allocator = std.heap.page_allocator;

    const file: std.fs.File = try std.fs.cwd().openFile("input/day2.txt", .{});
    defer file.close();

    {
        const parser = Parser.init(file, .hand);
        const guide = try parser.readGuideAllocator(allocator);
        defer guide.deinit();
        try stdout.print("part 1: {}\n", .{guide.total_score});
    }

    try file.seekTo(0);

    {
        const parser = Parser.init(file, .outcome);
        const guide = try parser.readGuideAllocator(allocator);
        defer guide.deinit();
        try stdout.print("part 2: {}\n", .{guide.total_score});
    }
}

const Parser = struct {
    const SecondColumnTag = enum {
        hand,
        outcome,
    };
    const SecondColumn = union(SecondColumnTag) {
        hand: Hand,
        outcome: std.math.Order,
    };

    file: std.fs.File,
    config: SecondColumnTag,

    pub fn init(file: std.fs.File, config: SecondColumnTag) Parser {
        return .{ .file = file, .config = config };
    }

    pub fn readGuideAllocator(self: Parser, allocator: std.mem.Allocator) !Guide {
        var guide = Guide.init(allocator);
        errdefer guide.deinit();

        while (true) {
            const round = self.readRound() catch |err| switch (err) {
                error.EndOfStream => return guide,
                else => return err,
            };
            try guide.addRound(round);
            _ = try self.readByte(); // trailing end-of-line
        }
    }

    pub fn readRound(self: Parser) !Round {
        const opponent = try self.readOpponent();
        _ = try self.readByte(); // separating space
        const yourself = try self.readYourself();
        return .{ .opponent = opponent, .yourself = switch (yourself) {
            .hand => |hand| hand,
            .outcome => |ord| Hand.from_order(opponent, ord),
        } };
    }

    fn readByte(self: Parser) !u8 {
        return try self.file.reader().readByte();
    }

    pub fn readOpponent(self: Parser) !Hand {
        return switch (try self.readByte()) {
            'A' => .rock,
            'B' => .paper,
            'C' => .scissor,
            else => error.InvalidHand,
        };
    }

    pub fn readYourself(self: Parser) !SecondColumn {
        switch (self.config) {
            .hand => return .{ .hand = switch (try self.readByte()) {
                'X' => .rock,
                'Y' => .paper,
                'Z' => .scissor,
                else => return error.InvalidHand,
            } },
            .outcome => return .{ .outcome = switch (try self.readByte()) {
                'X' => .lt,
                'Y' => .eq,
                'Z' => .gt,
                else => return error.InvalidHand,
            } },
        }
    }
};

const Hand = enum(u8) {
    rock,
    paper,
    scissor,

    pub fn order(self: Hand, other: Hand) std.math.Order {
        if (self == other) return .eq;
        if (self == other.from_order(.gt)) return .gt;
        return .lt;
    }

    pub fn score(self: Hand) u8 {
        return switch (self) {
            .rock => 1,
            .paper => 2,
            .scissor => 3,
        };
    }

    pub fn from_order(self: Hand, ord: std.math.Order) Hand {
        return switch (ord) {
            .gt => @intToEnum(Hand, (@enumToInt(self) + 1) % 3),
            .eq => self,
            .lt => @intToEnum(Hand, (@enumToInt(self) + 2) % 3),
        };
    }
};

const Round = struct {
    opponent: Hand,
    yourself: Hand,

    pub fn from_hand(opponent: Hand, yourself: Hand) Round {
        return .{ .opponent = opponent, .yourself = yourself };
    }

    pub fn from_outcome(opponent: Hand, outcome: std.math.Order) Round {
        const yourself = Hand.from_order(opponent, outcome);
        return .{ .opponent = opponent, .yourself = yourself };
    }

    pub fn score(self: Round) u8 {
        const outcome: u8 = switch (Hand.order(self.yourself, self.opponent)) {
            .lt => 0,
            .eq => 3,
            .gt => 6,
        };
        return self.yourself.score() + outcome;
    }
};

const Guide = struct {
    const RoundList = std.ArrayList(Round);

    rounds: RoundList,
    total_score: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) Guide {
        return .{ .rounds = RoundList.init(allocator) };
    }

    pub fn deinit(self: Guide) void {
        self.rounds.deinit();
    }

    pub fn addRound(self: *Guide, round: Round) !void {
        try self.rounds.append(round);
        self.total_score += round.score();
    }
};

const TmpFile = @import("utils.zig").TmpFile;

test "sample" {
    const allocator = std.testing.allocator;

    var file = try TmpFile.init(
        \\A Y
        \\B X
        \\C Z
        \\
    );
    defer file.deinit();

    {
        const parser = Parser.init(file.file, .hand);
        const guide = try parser.readGuideAllocator(allocator);
        defer guide.deinit();
        try std.testing.expectEqual(@as(u32, 15), guide.total_score);
    }

    try file.file.seekTo(0);
    {
        const parser = Parser.init(file.file, .outcome);
        const guide = try parser.readGuideAllocator(allocator);
        defer guide.deinit();
        try std.testing.expectEqual(@as(u32, 12), guide.total_score);
    }
}
