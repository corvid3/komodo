const builtins = @import("builtin");
const std = @import("std");

const Tag = enum(u8) {
    Integer,
    Floating,
    Structure,

    /// function objects are primitives in the language,
    /// so they are given their own special tag instead of having
    /// to store type info in the Obj.type val
    FuncObject,
};

const Type = struct {
    /// if (is_list == true), then the type is the element type of the dynlist,
    /// and the data union is set to .dynlist
    is_list: bool,
    type: Tag,
};

const Data = union(usize) {
    integer: isize,
    floating: f64,
    dynlist: **anyopaque,
    structure: *anyopaque,
};

ty: Type,
data: Data,
