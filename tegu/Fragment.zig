const std = @import("std");

ptr: []u8,

pub fn dump(self: @This(), writer: anytype) void {
    writer.print("== CODE FRAGMENT START ==\n");

    for(self.ptr) |b| {
        writer.print("")
    }

    writer.print("== CODE FRAGMENT END ==\n");
}
