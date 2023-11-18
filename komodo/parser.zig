const std = @import("std");

const Token = @import("Token.zig");
const Node = @import("ast/Node.zig");
const Ast = @import("ast/Ast.zig");

const Source = @import("Source.zig");
const diagnostics = @import("diagnostics.zig");

const lexer = @import("lexer.zig");

const Self = @This();

source: *Source,
nodes: std.MultiArrayList(Node) = .{},
extra_data: std.ArrayListUnmanaged(Node.ExtraData) = .{},

// we store the indent size of the current procedure parse
// so if any children are of a procedure declaration,
// we can check if the programmer put in an invalid
// (e.g. less-than-current) indentation size
indent_stack: std.ArrayListUnmanaged(usize) = .{},
tokidx: Token.Index = 0,

/// helper struct for managing ast-node listexpr's
/// building list expressions requires keeping both the head and tail
/// this simplifies the process
const ListContainer = struct {
    head: ?Token.Index = null,
    tail: ?Token.Index = null,
};

pub const Error = error{
    // irrecoverable parse error
    // stores error information in diagnostics
    IrrecoverableSyntaxError,
};

pub fn parse(
    source: *Source,
) Error!Ast {
    var self = Self{
        .source = source,
    };

    self.indent_stack.append(self.source.alloc, 0) catch std.debug.panic("", .{});

    const tln = try self.inner_parse();

    return Ast{
        .nodes = self.nodes,
        .extra_data = self.extra_data,
        .top_level_nodes = tln,
    };
}

// we have to do some weird goofery here
// the return value is non-return because we only return an error,
// not an actual return value
inline fn err_unexpected_eof(self: *Self) !noreturn {
    self.source.diagnostics.push_diagnostic(
        self.source.alloc,
        .Error,
        self.tokidx - 1,
        "unexpected end of file",
        .{},
    );
    return error.IrrecoverableSyntaxError;
}

// TODO: figure out how to make this less horrible for the programmer
// if prev_body == null, then start a new list
fn append_list(self: *Self, prev_body: ?Node.Index, data: Node.Index) Node.Index {
    const body = Node{
        .tag = .list_expr,

        // we will most likely never use the list-exprs as
        // debug information, so just set this to 0
        .assoc_tok = 0,
        .data = .{
            .list_expr = .{
                .next = null,
                .data = data,
            },
        },
    };

    const node = self.push_node(body);

    if (prev_body != null) {
        self.nodes.items(.data)[prev_body.?].list_expr.next = node;
    }

    return node;
}

fn append_list_container(self: *Self, lcp: *ListContainer, data: Node.Index) void {
    if (lcp.head != null) {
        lcp.tail = self.append_list(lcp.tail, data);
    } else {
        const new = self.append_list(null, data);
        lcp.head = new;
        lcp.tail = new;
    }
}

inline fn advance_tok(self: *Self) ?Node.Index {
    const c = self.tokidx;
    self.tokidx += 1;
    return c;
}

inline fn peek_tok(self: *Self) ?Node.Index {
    return if (self.tokidx >= self.source.tags.len)
        null
    else
        self.tokidx;
}

inline fn push_node(
    self: *Self,
    node: Node,
) Node.Index {
    self.nodes.append(self.source.alloc, node) catch {
        std.log.err(
            "failed to allocate memory for the nodes MAL",
            .{},
        );

        std.process.exit(1);
    };

    return @intCast(self.nodes.len - 1);
}

fn push_node_with_extra_data(
    self: *Self,
    comptime tag: Node.Tag,
    data: Node.Data,
    assoc_tok: Node.Index,
    extra_data: Node.ExtraData,
) Node.Index {
    @setCold(false);

    self.extra_data.append(self.source.alloc, extra_data) catch
        std.debug.panic("failed to allocate memory for extra data", .{});

    const edata_index: u32 = @intCast(self.extra_data.items.len - 1);

    // make a copy so we can alter the value before pushing
    var _data = data;
    switch (tag) {
        .procedure => _data.procedure.extra_data = edata_index,
        .let => _data.let.extra_data = edata_index,
        .while_loop => _data.while_loop.extra_data = edata_index,
        .complex_if => _data.complex_if.extra_data = edata_index,
        else => @compileError("invalid node type in push_node_with_extra_data: {s}"),
    }

    const node = Node{
        .tag = tag,
        .data = _data,
        .assoc_tok = assoc_tok,
    };

    self.nodes.append(self.source.alloc, node) catch
        std.debug.panic("failed to allocate memory for extra data node", .{});

    return @intCast(self.nodes.len - 1);
}

inline fn get_current_indent(self: *Self) usize {
    const current_indent = self.indent_stack.getLastOrNull() orelse
        std.debug.panic(
        "attempted to assert indentation while not contained within a block\n",
        .{},
    );
    return current_indent;
}

/// do block whitespace checking
/// this is separated from the `parse_block` procedure,
/// as some constructs need to check if we're still in the block
/// see: if ... else ...
/// returns true if still in block
/// returns if false if we have fallen out of block, or hit EOF
fn assert_whitespace_still_in_block(self: *Self) Error!bool {
    const current_indent = self.get_current_indent();

    // std.debug.print("BLOCK_LOOP    bl: {d} | nl: {d}", .{ bl_size, n_size });
    // we peek the indentation instead of immediately eating the token
    // why: if we are parsing this block that is below another block,
    //      and we fall out of _this_ current block, the block above
    //      would not have an indentation to parse
    const n_indent = self.peek_tok() orelse return false;
    const n_tag = self.source.tags[n_indent];
    const n_size: Node.Index = self.source.slices[n_indent].len;

    if (n_tag != .whitespace) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            n_indent,
            "expected whitespace while parsing a block, found \"{s}\"",
            .{self.source.slices[n_indent]},
        );

        return error.IrrecoverableSyntaxError;
    }

    if (n_size < current_indent) return false;

    // TODO: this can potentially be recoverable?
    // if compiling in interactive mode, ask the user if they want the line
    // to be automatically fixed and aligned
    if (n_size > current_indent) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            n_indent,
            "inconsistent indentation size while parsing block",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    // if we are still in _this_ block, eat the indentation
    self.tokidx += 1;

    return true;
}

fn parse_procedure(self: *Self) Error!Node.Index {
    const proc_tok = self.advance_tok() orelse unreachable;

    // the 'proc' token is already parsed going into this...
    const name_tok = self.advance_tok() orelse try self.err_unexpected_eof();

    const name_tag = self.source.tags[name_tok];
    if (name_tag != .identifier) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            name_tok,
            "expected an identifier after a procedure declaration",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    const lp_tokidx = self.advance_tok() orelse try self.err_unexpected_eof();
    const lp_tag = self.source.tags[lp_tokidx];
    if (lp_tag != .left_paran) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            lp_tokidx,
            "expected a left paranthesis after a procedure declaration",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    var par_list_head: ?Node.Index = null;
    var par_list_body: ?Node.Index = null;

    while (true) {
        const peek_tokidx = self.peek_tok() orelse try self.err_unexpected_eof();
        const peek_tag = self.source.tags[peek_tokidx];
        if (peek_tag == .right_paran) break;

        const pname_tok = self.advance_tok() orelse try self.err_unexpected_eof();
        const pname_tag = self.source.tags[pname_tok];
        if (pname_tag != .identifier) {
            const pname_slice = self.source.slices[pname_tok];
            self.source.diagnostics.push_diagnostic(
                self.source.alloc,
                .Error,
                name_tok,
                "expected a parameter name while parsing procedure declaration, found {s}",
                .{pname_slice},
            );

            return error.IrrecoverableSyntaxError;
        }

        const pcol_tok = self.advance_tok() orelse try self.err_unexpected_eof();
        const pcol_tag = self.source.tags[pcol_tok];
        if (pcol_tag != .colon) {
            const pcol_slice = self.source.slices[pcol_tok];
            self.source.diagnostics.push_diagnostic(
                self.source.alloc,
                .Error,
                name_tok,
                "expected a colon while parsing procedure declaration, found {s}",
                .{pcol_slice},
            );
        }

        const ptype_expr = try self.parse_highest_expr() orelse try self.err_unexpected_eof();
        const ndata = self.push_node(Node{
            .tag = .param_decl,
            .assoc_tok = peek_tokidx,
            .data = .{
                .param_decl = .{
                    .name = pname_tok,
                    .type = ptype_expr,
                },
            },
        });
        par_list_body = self.append_list(
            par_list_body,
            ndata,
        );
        if (par_list_head == null) par_list_head = par_list_body;
    }

    const rp_tokidx = self.advance_tok() orelse try self.err_unexpected_eof();
    const rp_tag = self.source.tags[rp_tokidx];
    if (rp_tag != .right_paran) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            rp_tokidx,
            "expected rightparanthesis after proc decl",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    const rtype_tok: ?Token.Index = if (self.peek_tok()) |rtype_tokidx| rtok_blk: {
        const tag = self.source.tags[rtype_tokidx];
        if (tag != .right_arrow)
            break :rtok_blk null;
        _ = self.advance_tok() orelse unreachable;

        const rtype_tok = self.advance_tok() orelse try self.err_unexpected_eof();
        const rtype_tag = self.source.tags[rtype_tok];
        if (rtype_tag != .identifier) {
            const rtype_slice = self.source.slices[rtype_tok];
            self.source.diagnostics.push_diagnostic(
                self.source.alloc,
                .Error,
                rtype_tok,
                "expected an identifier declaring the return type after a proc decl, found {s}\n",
                .{rtype_slice},
            );

            // TODO: recover, then fail?
            return error.IrrecoverableSyntaxError;
        }

        break :rtok_blk rtype_tok;
    } else null;

    const colon_tokidx = self.advance_tok() orelse try self.err_unexpected_eof();
    const colon_tag = self.source.tags[colon_tokidx];
    if (colon_tag != .colon) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            colon_tokidx,
            "expected a colon to start a block after a procedure declaration",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    const block = try self.parse_block();

    return self.push_node_with_extra_data(
        .procedure,
        .{
            .procedure = .{
                .extra_data = undefined,
                .start_of_list = block,
            },
        },
        proc_tok,
        .{
            .procedure_declaration = .{
                .name_tok = name_tok,
                .type_parameters = null,
                .parameters = par_list_head,
                .return_type_tok = rtype_tok,
            },
        },
    );
}

// expects a "begin" whitespace at the very front
// returns a pointer to the head of a list
// TODO: mark block as empty if the new indentation
//     is equal to the previous indentation, but only if
//     there is a linebreak in between the lines
fn parse_block(self: *Self) Error!?Node.Index {
    const current_indent = self.get_current_indent();

    const bl_indent = self.advance_tok() orelse try self.err_unexpected_eof();
    const bl_tag = self.source.tags[bl_indent];
    const bl_size: Node.Index = self.source.slices[bl_indent].len;

    if (bl_tag != .whitespace) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            bl_indent,
            "expected an indentation/whitespace to begin a new block",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    if (bl_size <= current_indent) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            bl_indent,
            "the base-level indentation of a block should be greater than the current indentation level",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    // push new indentation level
    self.indent_stack.append(self.source.alloc, bl_size) catch
        std.debug.panic("mem err while pushing to indent stack", .{});

    var list = ListContainer{};

    while (true) {
        const expr = try self.parse_expr_or_statement() orelse break;
        self.append_list_container(&list, expr);
        const still_in_block =
            try self.assert_whitespace_still_in_block();
        if (!still_in_block) break;
    }

    // pop the stack
    _ = self.indent_stack.pop();

    return list.head;
}

fn parse_factor(self: *Self) Error!?Node.Index {
    const tokidx = self.advance_tok() orelse return null;
    const tag = self.source.tags[tokidx];
    const slice = self.source.slices[tokidx];

    switch (tag) {
        .integer => {
            const parsed = std.fmt.parseInt(i64, slice, 10) catch {
                self.source.diagnostics.push_diagnostic(
                    self.source.alloc,
                    .Error,
                    tokidx,
                    "malformed integer in source file: {s}",
                    .{slice},
                );

                return error.IrrecoverableSyntaxError;
            };

            return self.push_node(
                Node{
                    .tag = .integer,
                    .data = .{ .integer = parsed },
                    .assoc_tok = tokidx,
                },
            );
        },

        .floating => {
            const parsed = std.fmt.parseFloat(f64, slice) catch {
                self.source.diagnostics.push_diagnostic(
                    self.source.alloc,
                    .Error,
                    tokidx,
                    "malformed floating point in source file: {s}",
                    .{slice},
                );

                return error.IrrecoverableSyntaxError;
            };

            return self.push_node(
                Node{
                    .tag = .floating,
                    .data = .{ .floating = parsed },
                    .assoc_tok = tokidx,
                },
            );
        },

        .identifier => {
            return self.push_node(
                Node{
                    .tag = .identifier,
                    .data = .{ .identifier = tokidx },
                    .assoc_tok = tokidx,
                },
            );
        },

        .left_paran => {
            const expr = self.parse_highest_expr();

            const rp_tokidx = self.advance_tok() orelse {
                self.source.diagnostics.push_diagnostic(
                    self.source.alloc,
                    .Error,
                    tokidx,
                    "expected right paranthesis, found end of file instead",
                    .{},
                );

                return error.IrrecoverableSyntaxError;
            };

            const rp_tag = self.source.tags[rp_tokidx];

            if (rp_tag != .right_paran) {
                self.source.diagnostics.push_diagnostic(
                    self.source.alloc,
                    .Error,
                    tokidx,
                    "expected a right paranthesis",
                    .{},
                );

                return error.IrrecoverableSyntaxError;
            }

            return expr;
        },

        else => {
            self.source.diagnostics.push_diagnostic(
                self.source.alloc,
                .Error,
                tokidx,
                "invalid symbols while attempting to parse a factor, found: {s}",
                .{@tagName(tag)},
            );

            return error.IrrecoverableSyntaxError;
        },
    }
}

fn parse_term(self: *Self) Error!?Node.Index {
    var left = (try self.parse_factor()) orelse return null;

    while (self.peek_tok()) |peek| {
        var peek_tag = self.source.tags[peek];

        switch (peek_tag) {
            .asterisk => {
                self.tokidx += 1;
                var right = (try self.parse_factor()) orelse try self.err_unexpected_eof();

                left = self.push_node(
                    Node{
                        .tag = .multiplication,
                        .data = .{
                            .binary = .{ .left = left, .right = right },
                        },
                        .assoc_tok = peek,
                    },
                );
            },

            .solidus => {
                self.tokidx += 1;
                var right = (try self.parse_factor()) orelse try self.err_unexpected_eof();
                left = self.push_node(
                    Node{
                        .tag = .division,
                        .data = .{
                            .binary = .{ .left = left, .right = right },
                        },
                        .assoc_tok = peek,
                    },
                );
            },

            else => return left,
        }
    }

    return left;
}

fn parse_expression(self: *Self) Error!?Node.Index {
    var left = (try self.parse_term()) orelse return null;

    while (self.peek_tok()) |peek| {
        var peek_tag = self.source.tags[peek];

        switch (peek_tag) {
            .plus => {
                self.tokidx += 1;
                var right = (try self.parse_term()) orelse try self.err_unexpected_eof();

                left = self.push_node(
                    Node{
                        .tag = .addition,
                        .data = .{
                            .binary = .{ .left = left, .right = right },
                        },
                        .assoc_tok = peek,
                    },
                );
            },

            .minus => {
                self.tokidx += 1;
                var right = (try self.parse_term()) orelse try self.err_unexpected_eof();
                left = self.push_node(
                    Node{
                        .tag = .subtraction,
                        .data = .{
                            .binary = .{ .left = left, .right = right },
                        },
                        .assoc_tok = peek,
                    },
                );
            },

            else => return left,
        }
    }

    return left;
}

fn parse_comparison_ops(self: *Self) !?Node.Index {
    var left = (try self.parse_expression()) orelse return null;

    while (self.peek_tok()) |peek| {
        var peek_tag = self.source.tags[peek];

        switch (peek_tag) {
            .eql => {
                self.tokidx += 1;
                var right = (try self.parse_expression()) orelse try self.err_unexpected_eof();

                left = self.push_node(
                    Node{
                        .tag = .eql,
                        .data = .{
                            .binary = .{ .left = left, .right = right },
                        },
                        .assoc_tok = peek,
                    },
                );
            },

            .ls_than => {
                self.tokidx += 1;
                var right = (try self.parse_expression()) orelse try self.err_unexpected_eof();

                left = self.push_node(
                    Node{
                        .tag = .ls_than,
                        .data = .{
                            .binary = .{ .left = left, .right = right },
                        },
                        .assoc_tok = peek,
                    },
                );
            },

            else => return left,
        }
    }

    return left;
}

fn parse_import(self: *Self) !Node.Index {
    const import_tok = self.advance_tok() orelse unreachable;
    const str_tok = self.advance_tok() orelse try self.err_unexpected_eof();
    const str_tag = self.source.tags[str_tok];
    if (str_tag != .string) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            str_tok,
            "expected a string after import statement, found {s}",
            .{self.source.slices[str_tok]},
        );

        return error.IrrecoverableSyntaxError;
    }

    return self.push_node(.{
        .tag = .import,
        .data = .{
            .import = .{
                .name = str_tok,
            },
        },
        .assoc_tok = import_tok,
    });
}

fn parse_expr_binops_or_other(self: *Self) !?Node.Index {
    const next_tok = self.peek_tok() orelse return null;
    const next_tag = self.source.tags[next_tok];
    return switch (next_tag) {
        .import => @as(?Node.Index, try self.parse_import()),
        else => try self.parse_comparison_ops(),
    };
}

inline fn parse_highest_expr(self: *Self) !?Node.Index {
    return self.parse_expr_binops_or_other();
}

fn parse_let(self: *Self) !Node.Index {
    const let_tokidx = self.advance_tok().?;

    const name_tokidx = self.advance_tok() orelse try self.err_unexpected_eof();
    const name_tag: Token.Tag = self.source.tags[name_tokidx];
    if (name_tag != .identifier) {
        const name_slice = self.source.slices[name_tokidx];

        if (name_tag.is_keyword()) {
            self.source.diagnostics.push_diagnostic(
                self.source.alloc,
                .Error,
                self.tokidx,
                "{s} is a reserved keyword, try another name",
                .{name_slice},
            );
        } else {
            self.source.diagnostics.push_diagnostic(
                self.source.alloc,
                .Error,
                self.tokidx,
                "expected an identifier/name after a let statement, found {s}",
                .{name_slice},
            );
        }

        return error.IrrecoverableSyntaxError;
    }

    // TODO: implement typing
    const ty: ?Node.Index = null;

    const eql_tokidx = self.advance_tok() orelse try self.err_unexpected_eof();
    const eql_tag = self.source.tags[eql_tokidx];
    if (eql_tag != .equals) {
        const eql_slice = self.source.slices[eql_tokidx];

        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            eql_tokidx,
            "expected an equal after a variable declaration, found {s}",
            .{eql_slice},
        );

        return error.IrrecoverableSyntaxError;
    }

    const expr = (try self.parse_highest_expr()) orelse {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            eql_tokidx,
            "expected an expression after an equals sign during let parsing",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    };

    return self.push_node_with_extra_data(
        .let,
        .{
            .let = .{
                .extra_data = undefined,
            },
        },
        let_tokidx,
        .{
            .let = .{
                .name = name_tokidx,
                .expr = expr,
                .type = ty,
            },
        },
    );
}

fn parse_set(self: *Self) !Node.Index {
    // we have already peeked in a previous function
    const set_tokidx = self.advance_tok() orelse unreachable;

    // this should go down to a reference
    const lhs = try self.parse_highest_expr() orelse try self.err_unexpected_eof();

    const equal_tokidx = self.advance_tok() orelse try self.err_unexpected_eof();
    const equal_tag = self.source.tags[equal_tokidx];
    if (equal_tag != .equals) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            equal_tokidx,
            "expected equals sign after set expression left-hand-side, found {s}",
            .{self.source.slices[equal_tokidx]},
        );

        return error.IrrecoverableSyntaxError;
    }

    const rhs = try self.parse_highest_expr() orelse try self.err_unexpected_eof();

    return self.push_node(.{
        .tag = .set,
        .assoc_tok = set_tokidx,
        .data = .{
            .set = .{
                .set = lhs,
                .to = rhs,
            },
        },
    });
}

// TODO: refactor this abhorrent garbage
fn parse_if(self: *Self) !Node.Index {
    // we have already peeked in a previous function
    const if_tokidx = self.advance_tok() orelse unreachable;

    const condition = try self.parse_highest_expr() orelse {
        self.source.diagnostics.push_diagnostic(self.source.alloc, .Error, if_tokidx, "expected an expression after an if for a condition", .{});

        return error.IrrecoverableSyntaxError;
    };

    const colon_tokidx = self.advance_tok() orelse try self.err_unexpected_eof();
    const colon_tag = self.source.tags[colon_tokidx];
    if (colon_tag != .colon) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            colon_tokidx,
            "expected a colon after the conditional of an if statement",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    const block = try self.parse_block();

    var else_elif_tok: Token.Index = undefined;
    const else_elif: ?Node.Index = if (try self.assert_whitespace_still_in_block()) else_elif: {
        const else_elif_peek = self.peek_tok() orelse break :else_elif null;
        const else_elif_tag = self.source.tags[else_elif_peek];

        switch (else_elif_tag) {
            .elif => {
                else_elif_tok = else_elif_peek;
                const elif = try self.parse_if();
                break :else_elif elif;
            },
            .@"else" => {
                else_elif_tok = else_elif_peek;
                _ = self.advance_tok();
                const else_colon_tok = self.advance_tok() orelse try self.err_unexpected_eof();
                const else_colon_tag = self.source.tags[else_colon_tok];
                if (else_colon_tag != .colon) {
                    self.source.diagnostics.push_diagnostic(
                        self.source.alloc,
                        .Error,
                        else_colon_tok,
                        "expected a colon after an `else`",
                        .{},
                    );

                    return error.IrrecoverableSyntaxError;
                }

                // `parse_block` can return null, which means
                // that the else-block has nothing in it
                // thus we can treat the complex if as a simple if
                const else_block = try self.parse_block();
                break :else_elif else_block;
            },
            else => break :else_elif null,
        }
    } else null;

    return if (else_elif) |else_node|
        self.push_node_with_extra_data(
            .complex_if,
            .{
                .complex_if = .{ .extra_data = undefined },
            },
            else_elif_tok,
            .{
                .complex_if = .{
                    .condition = condition,
                    .then = block,
                    .@"else" = else_node,
                },
            },
        )
    else
        self.push_node(
            Node{
                .tag = .simple_if,
                .assoc_tok = if_tokidx,
                .data = .{
                    .simple_if = .{
                        .condition = condition,
                        .then = block,
                    },
                },
            },
        );
}

fn parse_while(self: *Self) Error!Node.Index {
    // we have already parsed while tok in a previous function
    const while_tokidx = self.advance_tok() orelse unreachable;
    const condition = try self.parse_highest_expr() orelse try self.err_unexpected_eof();

    // potentially have a do syntax, like zigs while(...) : (...) {}
    // var do: ?Node.Index = null;
    // const do_tokidx = self.peek_tok() orelse try self.err_unexpected_eof();
    // if(do_tag == .Do) {
    //     do = self.parse_highest_expr()?;
    // }

    const colon_tokidx = self.advance_tok() orelse try self.err_unexpected_eof();
    const colon_tag = self.source.tags[colon_tokidx];
    if (colon_tag != .colon) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            colon_tokidx,
            "expected a colon after the conditional of a while statement",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    const block = try self.parse_block();

    return self.push_node_with_extra_data(
        .while_loop,
        .{
            .while_loop = .{ .extra_data = undefined },
        },
        while_tokidx,
        .{
            .while_loop = .{
                .label = null,
                .condition = condition,
                .block = block,
            },
        },
    );
}

fn parse_expr_or_statement(self: *Self) !?Node.Index {
    const peek_tokidx = self.tokidx;
    const peek_tag = self.source.tags[peek_tokidx];
    return switch (peek_tag) {
        .let => try self.parse_let(),
        .set => try self.parse_set(),
        .@"if" => try self.parse_if(),
        .@"while" => try self.parse_while(),
        else => try self.parse_highest_expr(),
    };
}

fn parse_structure_field(self: *Self) !Node.Index {
    const name_tok = self.advance_tok() orelse try self.err_unexpected_eof();
    const name_tag = self.source.tags[name_tok];
    if (name_tag != .identifier) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            name_tok,
            "expected an identifier when parsing a structure field decl, found {s}",
            .{self.source.slices[name_tok]},
        );

        return error.IrrecoverableSyntaxError;
    }

    const col_tok = self.peek_tok() orelse try self.err_unexpected_eof();
    const col_tag = self.source.tags[col_tok];
    var ty_expr: Node.Index = 0;
    if (col_tag == .colon) {
        _ = self.advance_tok() orelse unreachable;
        // ty_expr = self.parse_type_expression();
    }

    return self.push_node(
        .{
            .tag = .struct_field_decl,
            .data = .{
                .struct_field_decl = .{ .name = name_tok, .ty = ty_expr },
            },
        },
    );
}

fn parse_structure_static(self: *Self) !Node.Index {
    const static_tok = self.advance_tok() orelse try self.err_unexpected_eof();
    const static_tag = self.source.tags[static_tok];
    if (static_tag != .static) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            static_tok,
            "expected static keyword when parsing struct static, found {s}",
            .{self.source.slices[static_tok]},
        );

        return error.IrrecoverableSyntaxError;
    }

    const name_tok = self.advance_tok() orelse try self.err_unexpected_eof();
    const name_tag = self.source.tags[name_tok];
    if (name_tag != .identifier) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            name_tok,
            "expected an identifier when parsing a structure static decl, found {s}",
            .{self.source.slices[name_tok]},
        );

        return error.IrrecoverableSyntaxError;
    }

    const col_tok = self.advance_tok() orelse try self.err_unexpected_eof();
    const col_tag = self.source.tags[col_tok];
    if (col_tag != .colon) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            col_tok,
            "expected a colon when parsing a structure static decl, found {s}",
            .{self.source.slices[col_tok]},
        );

        return error.IrrecoverableSyntaxError;
    }

    // TODO: implement type expressions
    const type_expr: Node.Index = 0;

    const equal_tok = self.advance_tok() orelse try self.err_unexpected_eof();
    const equal_tag = self.source.tags[equal_tok];
    if (equal_tag != .equals) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            equal_tok,
            "expected a equal when parsing a structure static decl, found {s}",
            .{self.source.slices[equal_tok]},
        );

        return error.IrrecoverableSyntaxError;
    }

    const init_expr = self.parse_highest_expr();

    return self.push_node_with_extra_data(
        .struct_static_decl,
        .{ .struct_static_decl = .{ .extra_data = undefined } },
        static_tok,
        .{
            .structure_static_declaration = .{
                .name = name_tok,
                .ty = type_expr,
                .init_value = init_expr,
            },
        },
    );
}

inline fn wrap_prot_level(
    self: *Self,
    expr: Node.Index,
    level: Node.ProtLevel,
    assoc_tok: Token.Index,
) Node.Index {
    return self.push_node(
        .{
            .tag = .prot_level,
            .assoc_tok = assoc_tok,
            .data = .{
                .protection = .{
                    .level = level,
                    .data = expr,
                },
            },
        },
    );
}

/// used by parse_structure when parsing an in-file declared structure,
/// and used by the top-level parsing functions for file-kinded structure decls
fn parse_structure_inner(self: *Self) !Node.ExtraData.StructureDeclaration {
    var fields = ListContainer{};
    var statics = ListContainer{};
    var procedures = ListContainer{};

    while (true) whl: {
        const peek = self.peek_tok() orelse break;
        const peek_tag = self.source.tags[peek];

        var parsed_prot = true;
        var prot_level: Node.ProtLevel = undefined;

        switch (peek_tag) {
            .@"pub" => prot_level = .Public,
            .prot => prot_level = .Protected,
            .internal => prot_level = .Internal,
            else => {
                prot_level = .Private;
                parsed_prot = false;
            },
        }

        const member_tok = if (parsed_prot) (self.peek_tok() orelse break) else peek;
        const member_tag = self.source.tags[member_tok];

        switch (member_tag) {
            // declaring an instance member field
            .identifier => {
                var expr = try self.parse_structure_field();
                expr = self.wrap_prot_level(expr, prot_level, peek_tag);
                self.append_list_container(&fields, expr);
            },

            else => break :whl,
        }
    }

    return Node.ExtraData.StructureDeclaration{
        .instances = fields,
        .const_statics = statics,
        .procedures = procedures,
    };
}

fn parse_structure(self: *Self) Error!Node.Index {
    const struct_tok = self.advance_tok() orelse try self.err_unexpected_eof();
    const struct_tag = self.source.tags[struct_tok];
    if (struct_tag != .@"struct") {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            struct_tok,
            "expected struct token, found {s}",
            .{self.source.slices[struct_tok]},
        );

        return error.IrrecoverableSyntaxError;
    }
}

fn parse_toplevel(self: *Self) Error!?usize {
    const what_tok = self.peek_tok() orelse return null;
    const what_tag = self.source.tags[what_tok];
    switch (what_tag) {
        // .import => {
        //     return self.parse_import();
        // },

        // .@"struct" => {
        //     return self.parse_structure();
        // },

        .procedure => {
            return try self.parse_procedure();
        },

        else => {
            self.source.diagnostics.push_diagnostic(
                self.source.alloc,
                .Error,
                what_tok,
                "unknown toplevel token found while parsing <{s}>",
                .{self.source.slices[what_tok]},
            );

            return error.IrrecoverableSyntaxError;
        },
    }
}

// returns a list of the top level nodes
fn inner_parse(self: *Self) Error!std.ArrayListUnmanaged(Node.Index) {
    var top_level_nodes = std.ArrayListUnmanaged(Node.Index){};

    // we need to expect some whitespace
    const whitespace: usize = self.advance_tok() orelse unreachable;
    const whitespace_tag = self.source.tags[whitespace];
    const whitespace_slice = self.source.slices[whitespace];

    if (whitespace_tag != .whitespace) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            whitespace,
            "expected a whitespace before parsing a toplevel statement",
            .{},
        );

        return error.IrrecoverableSyntaxError;
    }

    if (whitespace_slice.len != 0) {
        self.source.diagnostics.push_diagnostic(
            self.source.alloc,
            .Error,
            whitespace,
            "toplevel statements must not be indented",
            .{},
        );

        // TODO: recover
        return error.IrrecoverableSyntaxError;
    }

    while (self.tokidx < self.source.tags.len) {
        top_level_nodes.append(
            self.source.alloc,
            (try self.parse_toplevel()) orelse break,
        ) catch
            std.debug.panic("mem err\n", .{});
    }

    return top_level_nodes;
}
