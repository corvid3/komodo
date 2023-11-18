const std = @import("std");
const Primitives = @import("primitives.zig").Primitives;

// identifier struct used for both data structures and traits
pub const TypeID = struct {
    // all types and traits require a name obv
    name: []const u8,

    // TODO: generic types
};

pub const Type = struct {
    name: []const u8,

    of: enum(u8) {
        Primitive,
        Structure,
        Union,

        Function,
    },

    // size in bytes
    size: u64,

    // what traits this type implements
    implements: std.ArrayListUnmanaged(TypeID) = .{},
};

const Self = @This();

types: std.StringHashMapUnmanaged(Type) = .{},

pub fn init(alloc: std.mem.Allocator) Self {
    var self = Self{};

    self.generate_primitives(alloc);

    return self;
}

pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
    self.types.deinit(alloc);
}

// fills the type-table with the basic primitive types
fn generate_primitives(self: *Self) void {
    for (Primitives) |prim| {
        self.types.put(self.alloc, prim.name, prim);
    }
}
