const Value = @import("Value.zig");

// functions should be freely copyable,
// that is, no side effects/memory issues should come from copying a function

const DebugData = struct {
    name: []const u8,
};

const ParamType = union(enum) {
    val: Value.Type,

    /// object values store their type information within themselves,
    /// so we need to store object type hash alongside the value type
    obj: u64,
};

debug: ?DebugData,
hash: u64,
exe: []const u8,
const_pool: []const Value,
