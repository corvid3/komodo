pub const KIBIBYTE = 1024;
pub const MIBIBYTE = 1024 * KIBIBYTE;
pub const GIBIBYTE = 1024 * MIBIBYTE;

pub const KILOBYTE = 1000;
pub const MEGABYTE = 1000 * KILOBYTE;
pub const GIGABYTE = 1000 * MEGABYTE;

pub const Bytes = enum(u8) {
    NOP = 0x00,

    /// load a register with a value from the const pool
    LOADREG_CONST = 0x10,

    // integer operations
    ADDI = 0x20,
    SUBI = 0x21,
    MULI = 0x22,
    DIVI = 0x23,

    // floating point operations
    ADDF = 0x30,
    SUBF = 0x31,
    MULF = 0x32,
    DIVF = 0x33,

    /// create a new object
    /// u16 | index to a class specifier into the const pool
    NEW = 0xA0,

    pub fn to_string(self: @This()) []const u8 {
        switch (self) {
            .NOP => "nop",
            .LOADREG_CONST => "loadreg_const",

            .ADDI => "addi",
            .SUBI => "subi",
            .MULI => "muli",
            .DIVI => "divi",

            .ADDF => "addf",
            .SUBF => "subf",
            .MULF => "mulf",
            .DIVF => "divf",

            .NEW => "new",
        }
    }
};
