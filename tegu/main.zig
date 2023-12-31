const std = @import("std");
const vm = @import("vm.zig");
const clap = @import("clap");
const loader = @import("loader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    _ = alloc;

    const stdout = std.io.getStdOut().writer();

    const params = comptime clap.parseParamsComptime(
        \\ -h, --help          Display help and exit.
        \\ -i, --input <str>   Which executable to execute.
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

test {
    _ = loader;
}
