tag: Tag,
slice: []const u8,
line: usize,
col: usize,

pub const Index = usize;

pub const Tag = enum(u8) {
    identifier,
    string,
    whitespace,

    integer,
    floating,

    right_arrow,

    equals,

    plus,
    minus,
    asterisk,
    solidus,

    eql,
    not_eql,
    ls_than,
    gr_than,
    lse_than,
    gre_than,

    left_paran,
    right_paran,

    period,
    comma,
    colon,

    import,
    static,

    // protection levels
    @"pub",
    prot,
    internal,

    in,
    inout,
    out,
    self,

    @"if",
    elif,
    @"else",

    @"while",
    @"for",
    loop,
    do,

    let,
    set,
    procedure,

    @"struct",
    @"enum",

    // special keywords
    using,
    cast,
    context,

    pub fn is_keyword(self: @This()) bool {
        return switch (self) {
            .self,
            .in,
            .out,
            .inout,
            .let,
            .set,
            .procedure,
            .@"if",
            .elif,
            .@"else",
            .@"while",
            .@"for",
            .loop,
            .do,
            => true,

            else => false,
        };
    }
};
