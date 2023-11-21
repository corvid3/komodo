const Obj = @import("Obj.zig");
const Value = @import("Value.zig");

// do some usingnamespace shenanegains, so that
// we can mark this file a packed struct
usingnamespace packed struct {
    /// this goes unused for now
    obj: Obj,

    /// how many dimensions this array is made of
    /// e.g. [2,3,2] would be a 3 dimensional array
    /// the lenghts of the array would be encoded in the slices inbetween
    dimensionality: usize,

    /// the type of value we're storing
    ty: Value.Tag,

    /// IDEA: we might be able to get some data savings here by not storing
    /// the type of value, though this may have some consequences
    slice: []Value,
};
