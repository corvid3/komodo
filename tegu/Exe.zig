const std = @import("std");
const Function = @import("Function.zig");

/// function hash
/// the first function to be executed upon startup
start_point: u64,
functions: std.AutoHashMapUnmanaged(u64, Function),
