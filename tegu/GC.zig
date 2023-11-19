const std = @import("std");
const Self = @This();

pub fn init(alloc: std.mem.Allocator, max_mem: usize) !Self {
    _ = alloc;
    _ = max_mem;

    return Self{};
}

pub fn deinit(self: *Self) void {
    _ = self;
}
