const Obj = @import("Obj.zig");

// do some usingnamespace shenanegains, so that
// we can mark this file a packed struct
usingnamespace packed struct {
    /// this goes unused for now
    obj: Obj,

    /// how many dimensions this array is made of
    /// e.g. [2,3,2] would be a 3 dimensional array
    /// the lenghts of the array would be encoded in the slices inbetween
    dimensionality: usize,

    /// type of objects that we're storing
    store: u64,

    slice: []*anyopaque,
};
