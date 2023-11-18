const std = @import("std");
const AstNode = @import("../ast/Node.zig");
const Token = @import("../Token.zig");

const Index = usize;

tag: Tag,
data: Data,

// the associated node in the AST, used for debugging
assoc_node: AstNode.Index = 0,

const Tag = enum(u8) {
    Identifier,

    IntegerConstant,
    FloatingConstant,

    Addition,
    Subtraction,
    Multiplication,
    Division,

    SimpleIf,
    ComplexIf,

    InfiniteLoop,
    Break,

    LetBinding,
    Set,

    ListExpr,
};

const Data = union {
    integer: i64,
    floating: f64,

    binary: struct {
        left: Index,
        right: Index,
    },

    simple_if: struct {
        condition: Index,
        then: Index,
    },

    complex_if: struct {
        extra_data: Index,
    },

    // index into extra data
    let: Index,

    set: struct {
        name: Token.Index,
        to: Index,
    },

    // index into extra data
    loop: Index,

    // index into extra data
    procedure: Index,

    list_expr: struct {
        next: ?Index,
        data: Index,
    },
};

const ExtraData = union {
    loop: struct {
        label: ?Token.Index,
        // points to a ListExpr head
        list: Index,
    },

    procedure: struct {
        name_tok: Token.Index,

        // points to a list of parameter declarations
        // parameters: Index,

        return_type_tok: ?Token.Index,
    },

    complex_if: struct {
        condition: Index,
        then: ?Index,
        // either points to an elif (s_if/c_if) or a block (nullable)
        @"else": ?Index,
    },
};
