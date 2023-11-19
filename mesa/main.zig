const std = @import("std");
const clap = @import("clap");

/// initialize the cwd as a komodo project
fn init() !void {
    const cwd = std.fs.cwd();
    cwd.access("mesa.toml", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    _ = alloc;

    const stdout = std.io.getStdOut().writer();

    const params = comptime clap.parseParamsComptime(
        \\ -h, --help  Display help and exit.
        \\ --init      Initialize a project within the current directory.
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
    }
}
