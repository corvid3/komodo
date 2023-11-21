const builtins = @import("builtin");
const std = @import("std");

pub const Tag = enum(u7) {
    Integer,
    Floating,
    Structure,

    /// function objects are primitives in the language,
    /// so they are given their own special tag instead of having
    /// to store type info in the Obj.type val
    FuncObject,

    /// array that stores primitive, -> *PrimArrObj
    PrimArray,

    /// array that stores references, -> *ArrayObj
    ObjArray,
};

pub const Data = union(usize) {
    integer: isize,
    floating: f64,
    dynlist: **anyopaque,
    structure: *anyopaque,
};

tag: Tag,
data: Data,
