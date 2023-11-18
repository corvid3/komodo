const std = @import("std");
const Tile = @import("Tile.zig");
const Scale = @import("Scale.zig");
const Source = @import("Source.zig");
const Diagnostics = @import("diagnostics.zig").Diagnostics;

const test_program =
    \\proc main( xyz : usize ):
    \\    let x = 1
    \\    if x == 0:
    \\        set x = 3
    \\    elif x == 1:
    \\        set x = 4
;

const Arguments = struct {
    arguments: std.process.ArgIterator,
    root_filename: []const u8,

    pub fn init(alloc: std.mem.Allocator) Arguments {
        var args = std.process.argsWithAllocator(alloc) catch
            std.debug.panic("mem err arguments\n", .{});

        var root_filename: ?[]const u8 = null;

        while (args.next()) |opt| {
            if (std.mem.eql(u8, opt, "-file")) {
                const filename = args.next() orelse {
                    std.log.err(
                        "expected filename after -file opt\n",
                        .{},
                    );
                    std.process.exit(1);
                };

                root_filename = filename;
            }
        }

        if (root_filename == null) {
            std.log.err(
                "expected a filename to be given\n",
                .{},
            );

            std.process.exit(1);
        }

        return @This(){
            .arguments = args,
            .root_filename = root_filename.?,
        };
    }

    pub fn deinit(self: *Arguments) void {
        self.arguments.deinit();
    }
};

// const UnitContext = struct {
//     source: []const u8,
//     tokens: std.MultiArrayList(Token),
// };

pub fn main() !void {
    var alloc = std.heap.page_allocator;

    var args = Arguments.init(alloc);
    defer args.deinit();

    var manager = Scale.init();
    _ = manager;
}
