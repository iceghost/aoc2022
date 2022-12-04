const std = @import("std");

pub const TmpFile = struct {
    tmp_dir: std.testing.TmpDir,
    file: std.fs.File,

    pub fn init(testcase: []const u8) !TmpFile {
        var tmp_dir = std.testing.tmpDir(.{});
        const file: std.fs.File = try tmp_dir.dir.createFile("sample.txt", .{ .read = true });
        try file.writeAll(testcase);
        try file.seekTo(0);
        return .{ .tmp_dir = tmp_dir, .file = file };
    }

    pub fn deinit(self: *TmpFile) void {
        self.tmp_dir.cleanup();
        self.file.close();
    }
};
