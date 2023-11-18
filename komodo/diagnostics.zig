const std = @import("std");
const Source = @import("Source.zig");
const Token = @import("Token.zig");

pub const Diagnostics = struct {
    diagnostics: std.MultiArrayList(Diagnostic) = .{},

    pub fn push_diagnostic(
        self: *@This(),
        alloc: std.mem.Allocator,
        kind: Diagnostic.Kind,
        where: Token.Index,
        comptime fmt: []const u8,
        datas: anytype,
    ) void {
        var what = std.ArrayListUnmanaged(u8){};
        std.fmt.format(what.writer(alloc), fmt, datas) catch
            std.debug.panic("what_writer memory error\n", .{});

        const diagnostic = Diagnostic{
            .kind = kind,
            .what = what.toOwnedSlice(alloc) catch std.debug.panic("failed to go to owned slice\n", .{}),
            .where = where,
        };

        self.diagnostics.append(alloc, diagnostic) catch
            std.debug.panic("failed to allocate memory for diagnostics\n", .{});
    }

    pub fn print_all(
        self: *@This(),
        source: *const Source,
        writer: anytype,
    ) void {
        var src_lines = std.mem.split(u8, source.source, "\n");

        const whats = self.diagnostics.items(.what);
        const kinds = self.diagnostics.items(.kind);
        const wheres = self.diagnostics.items(.where);
        const lines = source.tok_lines;
        const cols = source.tok_cols;

        for (0..self.diagnostics.len) |i| {
            const what = whats[i];
            const kind = kinds[i];
            const where_tok = wheres[i];
            const line = lines[where_tok];
            const col = cols[where_tok];

            for (0..line) |_| _ = src_lines.next();

            const where_line = src_lines.next().?;

            const kind_str = switch (kind) {
                .Note => "NOTE",
                .Warning => "WARNING",
                .Error => "ERROR",
            };

            writer.print(
                "{s} @ {d}:{d} [{s}]\n{s}\n",
                .{
                    kind_str,
                    line + 1,
                    col,
                    what,
                    where_line,
                },
            ) catch
                std.debug.panic("debug mem err\n", .{});

            src_lines.reset();
        }
    }

    pub fn has_error(self: *@This()) bool {
        for (self.diagnostics.items) |diag|
            if (diag.kind == .Error) return true;
        return false;
    }
};

// do not build diagnostics by hand,
// use the helper function Diagnostics.push_diagnostic(...)
pub const Diagnostic = struct {
    kind: Kind,

    what: []const u8,

    // token index
    where: usize,

    pub const Kind = enum(u8) {
        Note,
        Warning,
        Error,
    };
};
