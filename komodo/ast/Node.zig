const std = @import("std");
const Token = @import("../Token.zig");

tag: Tag,
data: Data = undefined,

// the associated token with this node, used for
// debugging purposes and error reporting
assoc_tok: Token.Index,

pub const Index = usize;

pub const ProtLevel = enum {
    private,
    protected,

    /// can be accessed by structs/procs declared within file
    /// (e.g. file-scope)
    internal,

    /// can be accessed by any struct/proc declared within
    /// the sheet (analogous to rusts' crates)
    sheet,

    public,
};

pub const Tag = enum(u8) {
    integer,
    floating,

    identifier,

    addition,
    subtraction,
    multiplication,
    division,

    eql,
    not_eql,
    ls_than,
    gr_than,
    lse_than,
    gre_than,

    simple_if,
    complex_if,

    /// declares a type-expression to be a pointer val
    ref,

    import,

    // loops can take an optional label
    for_loop,
    while_loop,
    inf_loop,
    do_while_loop,

    // takes an optional label
    @"break",

    // different field/static/proc privacy levels
    prot_level,

    let,
    set,

    param_decl,
    procedure,

    struct_decl,
    struct_field_decl,
    struct_static_decl,

    interface,
    implement,

    list_expr,
};

pub const Data = union {
    integer: i64,
    floating: f64,
    identifier: Token.Index,

    indirect: Index,

    protection: struct {
        data: Index,
        level: ProtLevel,
    },

    binary: struct {
        left: Index,
        right: Index,
    },

    import: struct {
        /// points to a string in the token slice
        name: Token.Index,

        /// optional renaming parameter
        /// e.g. import "some/dir/bar.lzt" as Barrie
        as: ?Token.Index,
    },

    set: struct {
        set: Index,
        to: Index,
    },

    let: struct {
        extra_data: Index,
    },

    // if(a) then: b
    simple_if: struct {
        condition: Index,
        then: ?Index,
    },

    // if(a) then: b ... else: c
    complex_if: struct {
        extra_data: Index,
    },

    while_loop: struct {
        extra_data: Index,
    },

    inf_loop: struct {
        label: ?Token.Index,
        block: Index,
    },

    param_decl: struct {
        name: Token.Index,
        type: Index,
    },

    type_param_decl: struct {
        type_expr: Index,

        // points to a list of potential type restraints
        // e.g. SomeType: Into<Int>
        list_of_reqd_interfaces: ?Index,
    },

    // returns a type (e.g. Fn<Int>) which may be used
    // as a type declaration or used as a value
    type_param_application: struct {
        // the expression to apply type parameters against
        to: Index,

        // a list of type expressions
        of: Index,
    },

    @"struct": struct {
        extra_data: Index,
    },

    struct_field_decl: struct {
        name: Index,
        ty: Index,
    },

    struct_static_decl: struct {
        extra_data: Index,
    },

    procedure: struct {
        extra_data: Index,
        start_of_list: ?Index,
    },

    interface: struct {
        extra_data: Index,
    },

    list_expr: struct {
        next: ?Index,
        data: Index,
    },
};

pub const ExtraData = union {
    structure_declaration: StructureDeclaration,
    structure_static_declaration: StructureStaticDeclaration,
    procedure_declaration: ProcedureDeclaration,
    interface_declaration: InterfaceDeclaration,
    let: Let,
    complex_if: ComplexIf,
    while_loop: WhileLoop,

    pub const ProcedureDeclaration = struct {
        name_tok: Token.Index,
        // points to a list of type parameter declarations
        type_parameters: ?Index,
        // points to a list of parameter declarations
        parameters: ?Index,
        return_type_tok: ?Index,
    };

    pub const StructureDeclaration = struct {
        /// points to a nullable list of const-static decls
        const_statics: ?Index,

        /// points to a nullable list of instance-var decls
        instances: ?Index,

        /// points to a nullable list of procedure decls
        procedures: ?Index,
    };

    pub const StructureStaticDeclaration = struct {
        name: Token.Index,

        /// static declarations require a type
        ty: Index,

        init_value: Index,
    };

    pub const InterfaceDeclaration = struct {};

    pub const Let = struct {
        name: Token.Index,
        expr: Index,
        type: ?Index,
    };

    pub const ComplexIf = struct {
        condition: Index,
        then: ?Index,
        // either points to an elif (s_if/c_if) or a block (nullable)
        @"else": ?Index,
    };

    pub const WhileLoop = struct {
        label: ?Index,
        condition: Index,
        block: ?Index,
    };
};
