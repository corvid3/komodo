const std = @import("std");

const Token = @import("../Token.zig");
const Node = @import("Node.zig");
const Source = @import("../Source.zig");

const Ast = @This();

/// the abstract syntax tree implementation
/// each Ast instance encodes information about one file
nodes: std.MultiArrayList(Node),
extra_data: std.ArrayListUnmanaged(Node.ExtraData),

/// points to file-kind struct decls
top_level_nodes: std.ArrayListUnmanaged(Node.Index),

const PrettyPrinter = struct {
    stdout: std.fs.File.Writer,
    source: *const Source,
    ntags: []Node.Tag,
    ndatas: []Node.Data,
    nextra: []Node.ExtraData,

    fn prettyPrint(ast: *const Ast, source: *const Source) void {
        var stdout = std.io.getStdOut().writer();
        var self = @This(){
            .stdout = stdout,
            .source = source,
            .ntags = ast.nodes.items(.tag),
            .ndatas = ast.nodes.items(.data),
            .nextra = ast.extra_data.items,
        };

        for (ast.top_level_nodes.items) |nidx| {
            self.inner(0, nidx);
        }
    }

    inline fn print_indent(self: *@This(), indent: usize) void {
        self.stdout.writeByteNTimes(' ', indent * 2) catch std.debug.panic("aorstnei", .{});
    }

    inline fn print(
        self: *@This(),
        comptime fmt: []const u8,
        what: anytype,
    ) void {
        self.stdout.print(fmt, what) catch
            std.debug.panic("pretty print mem err\n", .{});
    }

    fn inner(self: *@This(), indent: usize, nidx: usize) void {
        const ntag = self.ntags[nidx];
        const ndata = self.ndatas[nidx];
        // std.debug.print("INDENT: {d} TAG: {s} | ", .{ indent, @tagName(ntag) });

        // we don't actually print new data when PP'ng a list,
        //    so we avoid printing new indent when we're at a list
        if (ntag != .list_expr)
            self.print_indent(indent);

        switch (ntag) {
            .integer => self.print("{d}\n", .{ndata.integer}),
            .floating => self.print("{d}\n", .{ndata.floating}),
            .identifier => self.print("[{s}]\n", .{self.source.slices[ndata.identifier]}),

            .param_decl => {
                self.print(
                    "PAR {s}:\n",
                    .{
                        self.source.slices[ndata.param_decl.name],
                    },
                );

                self.inner(indent + 1, ndata.param_decl.type);
            },

            .addition,
            .subtraction,
            .multiplication,
            .division,
            .eql,
            .not_eql,
            .ls_than,
            .gr_than,
            .lse_than,
            .gre_than,
            => {
                switch (ntag) {
                    .addition => self.print("+\n", .{}),
                    .subtraction => self.print("-\n", .{}),
                    .multiplication => self.print("*\n", .{}),
                    .division => self.print("/\n", .{}),

                    .eql => self.print("==\n", .{}),
                    .not_eql => self.print("!=\n", .{}),
                    .ls_than => self.print("<\n", .{}),
                    .gr_than => self.print(">\n", .{}),
                    .lse_than => self.print("<=\n", .{}),
                    .gre_than => self.print(">=\n", .{}),

                    else => unreachable,
                }
                self.inner(indent + 1, ndata.binary.left);
                self.inner(indent + 1, ndata.binary.right);
            },

            .while_loop => {
                const edata = self.nextra[ndata.while_loop.extra_data];

                self.print("WHILE\n", .{});
                self.inner(indent + 1, edata.while_loop.condition);
                self.print_indent(indent);
                self.print("DO\n", .{});
                if (edata.while_loop.block) |block|
                    self.inner(indent + 1, block);
            },

            .for_loop,
            .inf_loop,
            .do_while_loop,
            .@"break",
            => self.print("loops unsupported in prettyprint\n", .{}),

            .let => {
                const edata = self.nextra[ndata.let.extra_data];
                self.print(
                    "LET {s} = \n",
                    .{
                        self.source.slices[edata.let.name],
                    },
                );
                self.inner(indent + 1, edata.let.expr);
            },

            .set => {
                self.print("SET\n", .{});
                self.inner(indent + 1, ndata.set.set);
                self.print_indent(indent);
                self.print("=\n", .{});
                self.inner(indent + 1, ndata.set.to);
            },

            .simple_if => {
                self.print("IF\n", .{});
                self.inner(indent + 1, ndata.simple_if.condition);
                self.print_indent(indent);
                self.print("THEN\n", .{});
                if (ndata.simple_if.then) |block|
                    self.inner(indent + 1, block);
            },

            .complex_if => {
                const edata = self.nextra[ndata.complex_if.extra_data];
                self.print("C-IF\n", .{});
                self.inner(indent + 1, edata.complex_if.condition);
                self.print_indent(indent);
                self.print("THEN\n", .{});
                if (edata.complex_if.then) |block|
                    self.inner(indent + 1, block);
                self.print_indent(indent);
                self.print("ELSE:\n", .{});
                if (edata.complex_if.@"else") |block|
                    self.inner(indent + 1, block);
            },

            .struct_decl => {
                const edata = self.nextra[ndata.@"struct".extra_data];
                self.print("STRUCT DECL\n", .{});
                self.print_indent(indent + 1);
                self.print("INSTANCES:\n", .{});
                if (edata.structure_declaration.instances) |ins|
                    self.inner(indent + 2, ins);
                self.print_indent(indent + 1);
                self.print("PROCEDURES:\n", .{});
                if (edata.structure_declaration.procedures) |procs|
                    self.inner(indent + 2, procs);
                self.print_indent(indent + 1);
                self.print("CONST STATICS:\n", .{});
                if (edata.structure_declaration.const_statics) |cs|
                    self.inner(indent + 2, cs);
            },

            .struct_field_decl => {
                self.print(
                    "FIELD DECL: {s}\n",
                    .{
                        self.source.slices[ndata.struct_field_decl.name],
                    },
                );

                self.print_indent(indent);
                self.print("OF TYPE: \n", .{});
                self.inner(indent + 1, ndata.struct_field_decl.ty);
            },

            .struct_static_decl => {
                const edata = self.nextra[ndata.struct_static_decl.extra_data];
                self.print(
                    "STATIC DECL: {s}\n",
                    .{
                        self.source.slices[edata.structure_static_declaration.name],
                    },
                );
                self.print_indent(indent);
                self.print("OF TYPE: \n", .{});
                self.inner(indent + 1, edata.structure_static_declaration.ty);
                self.print_indent(indent);
                self.print("WITH INIT OF:\n", .{});
                self.inner(indent + 1, edata.structure_static_declaration.init_value);
            },

            .procedure => {
                const edata = self.nextra[ndata.procedure.extra_data];
                const start = ndata.procedure.start_of_list;

                if (edata.procedure_declaration.parameters) |pars| {
                    self.print(
                        "PROCEDURE [{s}] ( \n",
                        .{
                            self.source.slices[edata.procedure_declaration.name_tok],
                        },
                    );

                    self.inner(indent + 1, pars);

                    self.print(
                        " ) -> {s}: \n",
                        .{
                            if (edata.procedure_declaration.return_type_tok) |t|
                                self.source.slices[t]
                            else
                                "void",
                        },
                    );
                } else {
                    self.print(
                        "PROCEDURE [{s}] () -> {s}: \n",
                        .{
                            self.source.slices[edata.procedure_declaration.name_tok],
                            if (edata.procedure_declaration.return_type_tok) |t|
                                self.source.slices[t]
                            else
                                "void",
                        },
                    );
                }

                if (start) |block|
                    self.inner(indent + 1, block);
            },

            .interface, .implement => self.print(
                "interfaces and implementations not yet implemented\n",
                .{},
            ),

            .import => {
                var ldata = ndata.import;
                self.print("IMPORT {s}", .{self.source.slices[ldata.name]});
            },

            .ref => {
                self.print("REF:\n", .{});
                var data = ndata.indirect;
                self.inner(indent + 1, data);
            },

            .prot_level => {
                self.print(
                    "PROTECTION [{s}]:\n",
                    .{
                        switch (ndata.protection.level) {
                            .private => "private",
                            .protected => "protected",
                            .internal => "internal",
                            .sheet => "sheet",
                            .public => "public",
                        },
                    },
                );

                self.inner(indent + 1, ndata.protection.data);
            },

            .list_expr => {
                var ldata = ndata.list_expr;
                while (true) {
                    self.inner(indent, ldata.data);
                    if (ldata.next == null) break;
                    ldata = self.ndatas[ldata.next.?].list_expr;
                }
            },
        }
    }
};

pub fn prettyPrint(self: *const @This(), source: *const Source) void {
    PrettyPrinter.prettyPrint(self, source);
}
