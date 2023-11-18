const std = @import("std");
const Token = @import("Token.zig");

src: []const u8,
idx: usize,

// 0 indexed, please increment by one when performing debug related prints
col: usize = 0,

// 0 indexed, please increment by one when performing debug related prints
line: usize = 0,

const Self = @This();

const Keywords: []const struct {
    []const u8,
    Token.Tag,
} = &.{
    .{ "import", .import },
    .{ "static", .static },
    .{ "pub", .@"pub" },

    .{ "struct", .@"struct" },
    .{ "enum", .@"enum" },

    .{ "using", .using },
    .{ "cast", .cast },
    .{ "context", .context },

    .{ "self", .self },
    .{ "in", .in },
    .{ "out", .out },
    .{ "inout", .inout },

    .{ "let", .let },
    .{ "set", .set },
    .{ "proc", .procedure },
    .{ "if", .@"if" },
    .{ "elif", .elif },
    .{ "else", .@"else" },
    .{ "while", .@"while" },
    .{ "for", .@"for" },
    .{ "loop", .loop },
    .{ "do", .do },
};

inline fn next_char(self: *Self) ?u8 {
    if (self.idx >= self.src.len) return null;

    const c = self.src[self.idx];

    self.idx += 1;
    self.col += 1;

    return c;
}

inline fn peek_char(self: *Self) ?u8 {
    if (self.idx >= self.src.len) return null;

    const c = self.src[self.idx];
    // self.col += 1;

    return c;
}

inline fn skip_whitespace(self: *Self) void {
    while (true) {
        const c = self.peek_char() orelse return;
        if (c != ' ' or c == '\n') break;
        _ = self.next_char();
    }
}

inline fn construct_single(self: *Self, tag: Token.Tag) Token {
    return Token{
        .tag = tag,
        .slice = self.src[self.idx - 1 .. self.idx],
        .col = self.col,
        .line = self.line,
    };
}

fn _inner_lex(self: *Self) ?Token {
    self.skip_whitespace();
    switch (self.next_char() orelse return null) {
        '\t' => {
            std.log.err(
                "tabs are not supported by the future compiler\n",
                .{},
            );

            std.process.exit(1);
        },

        '\n' => {
            self.col = 0;
            self.line += 1;
            var start = self.idx;
            while (true) {
                const c = self.peek_char() orelse return null;

                if (c == '\n') {
                    start = self.idx;
                    self.col = 0;
                } else if (c != ' ')
                    break;

                _ = self.next_char();
            }

            return Token{
                .tag = .whitespace,
                .slice = self.src[start..self.idx],
                .line = self.line,
                .col = self.col,
            };
        },

        '(' => return self.construct_single(.left_paran),
        ')' => return self.construct_single(.right_paran),

        '+' => return self.construct_single(.plus),
        '-' => return self.construct_single(.minus),
        '*' => return self.construct_single(.asterisk),
        '/' => return self.construct_single(.solidus),

        '=' => {
            if (self.peek_char() == '=') {
                _ = self.next_char();
                return self.construct_single(.eql);
            }

            return self.construct_single(.equals);
        },
        '<' => return self.construct_single(.ls_than),
        '>' => return self.construct_single(.gr_than),

        '.' => return self.construct_single(.period),
        ',' => return self.construct_single(.comma),
        ':' => return self.construct_single(.colon),

        '"' => {
            const col = self.col;
            const line = self.line;
            const start = self.idx;
            while (self.next_char()) |c| {
                if (c == '"') break;
            }
            return Token{
                .tag = .string,
                .slice = self.src[start..self.idx],
                .line = line,
                .col = col,
            };
        },

        else => |b| {
            const col = self.col;
            const line = self.line;
            if (std.ascii.isAlphabetic(b)) {
                const start = self.idx - 1;

                while (self.peek_char()) |c| {
                    if (!std.ascii.isAlphanumeric(c) and c != '_') break;
                    _ = self.next_char();
                }

                const slice = self.src[start..self.idx];

                for (Keywords) |keyword|
                    if (std.mem.eql(u8, slice, keyword.@"0"))
                        return Token{
                            .tag = keyword.@"1",
                            .slice = slice,
                            .col = col,
                            .line = line,
                        };

                return Token{
                    .tag = .identifier,
                    .slice = slice,
                    .col = col,
                    .line = line,
                };
            } else if (std.ascii.isDigit(b)) {
                const start = self.idx - 1;

                var is_floating: bool = false;

                while (self.peek_char()) |c| {
                    if (!std.ascii.isDigit(c) and c != '.') break;
                    if (c == '.') is_floating = true;
                    _ = self.next_char();
                }

                return Token{
                    .tag = if (is_floating) .floating else .integer,
                    .slice = self.src[start..self.idx],
                    .col = col,
                    .line = line,
                };
            }

            std.log.err(
                "unknown symbol in lexer\n",
                .{},
            );

            std.process.exit(1);
        },
    }
}

fn inner_lex(self: *Self, alloc: std.mem.Allocator) std.MultiArrayList(Token) {
    var list = std.MultiArrayList(Token){};
    // we need to parse the beginning whitespace offset,
    // so we have some special entry code here to do that

    const ws_s = self.idx;
    self.skip_whitespace();
    const ws_e = self.idx;

    list.append(
        alloc,
        Token{
            .tag = .whitespace,
            .slice = self.src[ws_s..ws_e],
            .col = 0,
            .line = 0,
        },
    ) catch std.debug.panic("whitespace addition mem err\n", .{});

    while (self._inner_lex()) |tok| {
        list.append(alloc, tok) catch
            std.debug.panic("failed to append to inner_lext MAL\n", .{});
    }
    return list;
}

pub fn lex(alloc: std.mem.Allocator, input: []const u8) std.MultiArrayList(Token) {
    var self = Self{
        .src = input,
        .idx = 0,
    };

    return self.inner_lex(alloc);
}
