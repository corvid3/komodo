/// SourceManager.zig
/// contains a hash map of all sources
/// allows for easy access between files when processing
/// the ast/tst
/// graphIr flattens everything down into one giant manifest
const std = @import("std");
const Source = @import("Source.zig");
const toml = @import("toml");

const Scale = @This();

arena: std.heap.ArenaAllocator,
alloc: std.mem.Allocator,

/// list of all source files local to this scale
sources: std.StringHashMapUnmanaged(*const Source) = .{},

/// list of all scales within this scale
subscales: std.ArrayListUnmanaged(Scale) = .{},

pub fn init() Scale {
    // each scale gets its own arena allocator, so that we can
    // selectively throw away entire scales if they're detected as not
    // being used by dead code analysis,
    // this allows for some memory savings after AST gen
    // but before IR/codegen

    var alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);

    return Scale{
        .arena = arena,
        .alloc = arena.allocator(),
    };
}

pub fn deinit(self: *@This()) void {
    self.arena.deinit();
}

pub fn import(self: *@This(), path: []const u8) !*const Source {
    const opt_get = self.sources.getPtr(path);

    if (opt_get) return opt_get.?;

    return self.sources.getPtr(path) orelse blk: {
        self.sources.put(self.alloc, path, try Source.init(path)) catch
            std.debug.panic("mem failt get_source\n", .{});
        break :blk self.sources.getPtr(path) orelse unreachable;
    };
}
