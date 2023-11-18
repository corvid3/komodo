const std = @import("std");
const TypeServer = @import("TypeServer.zig");
const Instruction = @import("Instruction.zig");

// the graphical IR, used for optimization passes

pub const Block = struct {
    instructions: std.ArrayListUnmanaged(Instruction),
};

pub const Function = struct {
    blocks: std.ArrayListUnmanaged(Block),
};

pub const Manifest = struct {
    type_server: TypeServer,
    functions: std.StringHashMap(Function),
};
