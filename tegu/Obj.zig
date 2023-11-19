const std = @import("std");

/// points to a structure definition within the const pool
const Tag = usize;

tag: Tag,
end: void,
