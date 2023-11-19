// loader.zig
// manages detar/decomp'ng executable .tegu files,
// and returns the executable data to be used within the VM

// TODO: make this secure
// perhaps have tegu run as a daemon, and programs are
// passed to tegu, then tegu depacks as its own user and executes,
// passing stdin/stdout forwarding handles to the process

const std = @import("std");
const Exe = @import("Exe.zig");

/// ensures that the directory /tmp/tegu exists
fn ensure_tmp_tegu_dir() void {
    std.fs.accessAbsolute("/tmp/tegu", .{}) catch
        std.fs.makeDirAbsolute("/tmp/tegu/") catch
        std.debug.panic("unable to create /tmp/tegu path\n", .{});
}

/// creates a temporary directory under /tmp/tegu/,
/// and returning a handle to it
fn generate_tmp_dir(alloc: std.mem.Allocator) !std.fs.Dir {
    ensure_tmp_tegu_dir();

    var str = std.ArrayList(u8).init(alloc);
    defer str.deinit();
    try str.appendSlice("/tmp/tegu/");

    var rand = std.rand.DefaultPrng.init(@bitCast(std.time.milliTimestamp()));

    for (0..16) |_| {
        var c: u8 = @truncate(rand.next() % 26);
        try str.append(c + 'a');
    }

    try std.fs.makeDirAbsolute(str.items);
    return try std.fs.openDirAbsolute(str.items, .{});
}

/// unpacks a .tar.gz into a temporary directory,
/// then returns the handle
fn depack(alloc: std.mem.Allocator, path: []const u8) !std.fs.Dir {
    const cwd = std.fs.cwd();

    var file = try cwd.openFile(path, .{});
    defer file.close();

    var decompressor = try std.compress.gzip.decompress(alloc, file.reader());
    defer decompressor.deinit();

    var tmp_dir = try generate_tmp_dir(alloc);

    try std.tar.pipeToFileSystem(tmp_dir, decompressor.reader(), .{});

    return tmp_dir;
}

/// opens the exe.tar.gz at a given path, then returns
/// the executable transformed into the internal representation
pub fn open(alloc: std.mem.Allocator, path: []const u8) !Exe {
    var tmp_dir = try depack(alloc, path);
    // i'm scared of writing code that deletes directories,
    // so i'm just going to close it for now and let the OS delete upon restart
    defer tmp_dir.close();
}

test "/tmp/tegu/ dir" {
    ensure_tmp_tegu_dir();
    try std.fs.accessAbsolute("/tmp/tegu/", .{});
}

test "create tmp dir in /tmp/tegu/" {
    var tmp = try generate_tmp_dir(std.testing.allocator);

    var tmp_dir = try tmp.realpathAlloc(std.testing.allocator, "./");
    defer std.testing.allocator.free(tmp_dir);

    tmp.close();

    _ = try std.fs.deleteDirAbsolute(tmp_dir);

    std.debug.print("{s}\n", .{tmp_dir});
    std.fs.accessAbsolute(tmp_dir, .{}) catch return;

    return error.DirStillExists;
}
