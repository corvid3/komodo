// temporary dump file
// moving around directories and renaming stuff,
// this is the contents of the old "src/vm.zig" file

const std = @import("std");

const GC = struct {
    const Self = @This();
    const PtrAllocPair = struct {
        at: *anyopaque,
    };

    alloc: std.mem.Allocator,
    list: std.ArrayListUnmanaged(u64) = .{},

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
        };
    }
};

const Bytes = enum(u8) {
    add_i,
    sub_i,
    mul_i,

    add_f,
    sub_f,
    mul_f,
    div_f,

    /// takes a register and the hash of structure def
    create_structure,

    create_structure_by_name,

    /// takes a register, offset, and size in bytes
    get_field,

    /// takes a register, a type-name, and a hashed name of the field wanted
    get_field_by_name,

    /// see get_field, but takes an additional value
    set_field,

    /// see get_field_by_name, but takes an additional value
    set_field_by_name,

    call_function,
};

const Symbol = struct {
    const Self = @This();
    name: ?[]const u8,
    hash: u64,

    pub fn init(name: []const u8) Self {
        Self{
            .name = name,
            .hash = std.hash.CityHash64.hash(name),
        };
    }
};

const StructureDefinition = struct {
    const Field = struct {
        name: ?[]const u8,
        hash: u64,
        offset: usize,
    };

    name: Symbol,
    fields: []const Field,
};

/// variably sized object stored in heap memory
const Structure = struct {
    typename: Symbol,
    end: void,
};

const Value = union {
    Integer: i64,
    Floating: i64,

    Structure: *anyopaque,
};

const Function = struct {
    const Data = union {
        InternalUncompiled: struct {
            data: []const Bytes,
        },

        InternalCompiled: struct {
            /// we use a special ABI for JIT native functions,
            /// so we have to use a helper function to call these
            where: *anyopaque,
        },

        External: struct {
            func: fn (*Context, params: []const Value) void,
        },
    };

    const Kind = enum {
        /// function compiled to bytecode, not JIT
        InternalUncompiled,

        /// function which has been JIT compiled to native machinecode
        InternalCompiled,

        /// an external function, already native, that fits the ABI
        External,
    };

    name: []const u8,
    kind: Kind,
};

const ExecutionFrame = struct {
    // maximum of 64 local variables within a single
    // function scope. if you have more than 64 local variables
    // that's kind of on you man
    vars: [64]Value,

    /// ExecutionFrames are only created for Data.InternalUncompiled
    /// type functions, so immediately deref data to InternalUncompiled
    function: *Function,
    ip: usize,
};

/// stores all of the information needed by the different interpreters
const Context = struct {
    const Self = @This();

    gc: GC,

    pub fn init(alloc: std.mem.Allocator) Self {
        Self{
            .gc = GC.init(alloc),
        };
    }
};

/// walks the bytecode of a function and recompiles
/// into native assembly
const JitCompiler = struct {};

/// special virtual machine, allows external processes to interrupt
/// the virtual machine loop and take a look inside while running
const Server = struct {
    const Self = @This();

    context: *const Context,
    mode: enum { Release, Debug } = .Release,
    funcs: std.ArrayListUnmanaged(Function) = .{},

    /// if started with introspection turned on,
    /// and the supplied binary contains debug information,
    /// we can allow external debug clients to probe information
    /// on a running liszt system
    /// communication with external debug clients occurs
    /// through posix sockets
    introspect_sock: ?std.os.socket_t,

    // TODO: optionally tack on the AST so we can recompile on the fly
    // source:

    /// new input/output signal handler
    /// halts the execution of the current function,
    /// and listens to a connected client
    fn new_io(self: *Self) void {
        _ = self;
    }

    pub fn init(context: *const Context) Self {
        return Self{
            .context = context,
        };
    }
};
