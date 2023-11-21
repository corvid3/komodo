// structure definitions
// TODO

const Value = @import("Value.zig");

const FieldDef = struct {
    name: ?[]const u8,
    hash: usize,
    offset: usize,
    ty: Value.Type,
};

name: []const u8,
hash: u64,
fields: []const FieldDef,
