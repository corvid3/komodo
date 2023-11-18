const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const Token = @import("Token.zig");
const Diagnostics = @import("diagnostics.zig").Diagnostics;
const Ast = @import("ast/Ast.zig");
const consts = @import("consts.zig");

const Self = @This();

// each source is given its own arena allocator,
// so we can selectively destroy entire source files
// if they are detected as being unused by dead code elimination.
// this allows for some memory savings
alloc: std.mem.Allocator,
arena: std.heap.ArenaAllocator,

path: []const u8,
source: []const u8,

diagnostics: Diagnostics = .{},

// destructuring of a MultiArrayList(.Token),
// as it would be much slower to constantly call .slice(.tag)
// when the token list will never-ever be updated post initialization
tags: []const std.meta.FieldType(Token, .tag),
slices: []const std.meta.FieldType(Token, .slice),

// token debug information
tok_lines: []const std.meta.FieldType(Token, .line),
tok_cols: []const std.meta.FieldType(Token, .col),

ast: ?Ast = undefined,

/// allow for up to 16 mibibytes of source data per file
/// if your source code file is >64megs, what are you doing?
const MAX_FILEDATA_SIZE: usize = consts.MIBIBYTE * 64;

/// creates and opens a source file from a specified relative path
/// then lexes and parses the file contents
/// can fail and return an error if there is a lexical error
pub fn init(path: []const u8) !Self {
    var parent_alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(parent_alloc);
    const alloc = arena.allocator();

    errdefer arena.deinit();

    var file = std.fs.cwd().openFile(path, .{}) catch {
        std.log.err("failed to open source by path of {s}\n", .{path});
        std.process.exit(1);
    };

    defer file.close();

    var source = file.readToEndAlloc(alloc, 1024 * 1024 * 64) catch {
        std.log.err("failed to read text from source file {s}\n", .{path});
        std.process.exit(1);
    };

    const toks = lexer.lex(alloc, source);

    // for each source we use an arena allocator,
    // so we can throw away toks safely
    // this also prevents undesired mutation of the tokens array
    var self = Self{
        .arena = arena,
        .alloc = alloc,
        .path = path,
        .source = source,
        .tags = toks.items(.tag),
        .slices = toks.items(.slice),
        .tok_lines = toks.items(.line),
        .tok_cols = toks.items(.col),
    };

    const ast = parser.parse(&self) catch {
        std.log.err("ERROR: syntax error detected in file {s}\n", .{path});
        self.diagnostics.print_all(&self, std.io.getStdOut().writer());
        return error.IrrecoverableSyntaxError;
    };

    self.ast = ast;
    return self;
}

pub fn get_ast(self: *Self) *Ast {
    if (self.ast) |x| return x;

    self.ast = try parser.parse(self);
    return self.ast.?;
}

fn print_toks(self: *const Self) void {
    for (0..self.tags.len) |i|
        std.debug.print("{s}\n", .{@tagName(self.tags[i])});
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}
