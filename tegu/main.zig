const std = @import("std");

pub fn main() !void {
    _ = try std.io.getStdOut().writer().print("Hello, World!\n", .{});
}
