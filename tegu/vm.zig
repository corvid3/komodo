const std = @import("std");
const Value = @import("Value.zig");
const Function = @import("Function.zig");
const GC = @import("GC.zig");
const consts = @import("consts.zig");

const Exe = @import("Exe.zig");

const Self = @This();

const Config = struct {
    /// if left null, the VM will use the GPA
    alloc: ?std.mem.Allocator,

    max_frames: usize = 2048,

    /// in bytes
    max_mem: usize = consts.GIBIBYTE,
};

const ExecutionFrame = struct {
    ip: usize,
    function: *const Function,
    registers: *[256]Value,

    pub fn init(alloc: std.mem.Allocator) @This() {
        return .{
            .registers = alloc.create([256]Value),
        };
    }

    pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
        alloc.destroy(self.registers);
    }
};

gpa: ?std.heap.GeneralPurposeAllocator(.{}) = null,
alloc: std.mem.Allocator,
gc: GC,

exe: ?Exe,

/// TODO: configurable amount of execution frames allowed
frames: []ExecutionFrame,

/// index into the frames array
frame_ptr: usize,

pub fn init(config: Config) Self {
    var self: Self = undefined;

    if (config.alloc) |alloc| {
        self.gpa = null;
        self.alloc = alloc;
    } else {
        self.gpa = .{};
        self.alloc = self.gpa.?.allocator();
    }

    self.gc = GC.init(self.alloc, config.max_mem);

    self.exe = null;

    self.frames = self.alloc.alloc(ExecutionFrame, config.max_frames);
    self.frame_ptr = 0;

    return self;
}

pub fn deinit(self: *Self) void {
    self.gc.deinit();

    self.alloc.free(self.frames);

    if (self.gpa) |gpa|
        _ = try gpa.deinit();
}

/// takes ownership of "exe"
pub fn load_exe(self: *Self, exe: Exe) void {
    if (self.exe) |x| x.deinit();
    self.exe = exe;
}
