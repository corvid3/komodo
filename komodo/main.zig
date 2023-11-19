const std = @import("std");
const Scale = @import("Scale.zig");
const Source = @import("Source.zig");
const Diagnostics = @import("diagnostics.zig").Diagnostics;
const clap = @import("clap");

const test_program =
    \\proc main( xyz : usize ):
    \\    let x = 1
    \\    if x == 0:
    \\        set x = 3
    \\    elif x == 1:
    \\        set x = 4
;

// const UnitContext = struct {
//     source: []const u8,
//     tokens: std.MultiArrayList(Token),
// };

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const params = comptime clap.parseParamsComptime(
        \\ -h, --help          Display help and exit.
        \\ -r, --root <str>    Path to which tile root to compile.
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch
            std.debug.panic("", .{});
        return err;
    };

    defer res.deinit();

    if (res.args.help != 0) {
        try clap.usage(stdout, clap.Help, &params);
        try stdout.writeAll("\n");
        try clap.help(stdout, clap.Help, &params, .{});
        return;
    }

    if (res.args.root == null) {
        try std.io.getStdErr().writer().print(
            "ERROR: expected a root tile directory to be provided\n",
            .{},
        );

        return;
    }

    const root_dir = res.args.root.?;
    std.debug.print("root_dir: {s}\n", .{root_dir});
}
