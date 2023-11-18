const std = @import("std");
const Token = @import("../Token.zig");

tag: Tag,
data: Data,

pub const Index = usize;

pub const Tag = enum(u8) {
    IntegerConstant,
    FloatingConstant,

    Addition,
    Subtraction,
    Multiplication,
    Division,
};

comptime {
    std.debug.assert(@sizeOf(Data) <= 8);
}

pub const Data = union {
    Binary: struct {
        left: Index,
        right: Index,
    },

    Integer: i64,
    Floating: f64,
};
