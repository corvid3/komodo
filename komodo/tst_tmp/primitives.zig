const Type = @import("TypeManager.zig").Type;

pub const Primitives: []const Type = &.{
    .{
        .name = "integer",
        .of = .Primitive,
        .size = 8,
    },
    .{
        .name = "floating",
        .of = .Primitive,
        .size = 8,
    },
};
