const std = @import("std");
const Node = @import("Node.zig");
const TypeManager = @import("TypeManager.zig");

// untyped syntax tree
// a simplified, compiler friendly version of the AST
// used for typechecking, type resolution, etc

nodes: std.MultiArrayList(Node),
extra_data: std.ArrayListUnmanaged(Node.ExtraData),

pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
    self.types.deinit(alloc);
    self.nodes.deinit(alloc);
    self.extra_data.deinit(alloc);
    self.functions.deinit(alloc);
}
