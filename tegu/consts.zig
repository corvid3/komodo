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

    ADDF = 0x30,
    SUBF = 0x31,
    MULF = 0x32,
    DIVF = 0x33,

    /// immediately suspend the virtual machine
    HALT = 0xFF,
};
