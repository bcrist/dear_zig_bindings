defines: []Define,
enums: []Enum,
typedefs: []Typedef,
structs: []Struct,
functions: []Function,

pub const Define = struct {
    name: []const u8,
    content: []const u8 = "",
    is_internal: bool = false,
    comments: ?Comments = null,
    source_location: ?Source_Location = null,
    conditionals: ?[]Conditional = null,
};

pub const Enum = struct {
    name: []const u8,
    original_fully_qualified_name: []const u8,
    storage_type: ?*Type = null,
    is_flags_enum: bool = false,
    elements: []Element,
    is_internal: bool = false,
    comments: ?Comments = null,
    source_location: ?Source_Location = null,
    conditionals: ?[]Conditional = null,

    pub const Element = struct {
        name: []const u8,
        value_expression: ?[]const u8 = null,
        value: i64,
        is_count: bool = false,
        is_internal: bool = false,
        comments: ?Comments = null,
        source_location: ?Source_Location = null,
        conditionals: ?[]Conditional = null,
    };
};

pub const Typedef = struct {
    name: []const u8,
    type: Type,
    is_internal: bool = false,
    comments: ?Comments = null,
    source_location: ?Source_Location = null,
    conditionals: ?[]Conditional = null,
};

pub const Struct_Or_Union = enum {
    @"struct",
    @"union",
};

pub const Struct = struct {
    name: []const u8,
    original_fully_qualified_name: []const u8,
    kind: Struct_Or_Union,
    by_value: bool,
    forward_declaration: bool,
    is_anonymous: bool,
    fields: []Field,
    is_internal: bool = false,
    comments: ?Comments = null,
    source_location: ?Source_Location = null,
    conditionals: ?[]Conditional = null,

    pub const Field = struct {
        name: []const u8,
        is_array: bool,
        array_bounds: ?[]const u8 = null,
        width: ?usize = null,
        is_anonymous: bool = false,
        @"type": Type,
        default_value: ?[]const u8 = null,
        is_internal: bool = false,
        comments: ?Comments = null,
        source_location: ?Source_Location = null,
        conditionals: ?[]Conditional = null,
    };
};

pub const Function = struct {
    name: []const u8,
    original_fully_qualified_name: []const u8,
    return_type: Type,
    arguments: []Argument,
    is_default_argument_helper: bool,
    is_manual_helper: bool,
    is_imstr_helper: bool,
    has_imstr_helper: bool,
    is_unformatted_helper: bool,
    is_static: bool,
    original_class: ?[]const u8 = null,
    is_internal: bool = false,
    comments: ?Comments = null,
    source_location: ?Source_Location = null,
    conditionals: ?[]Conditional = null,

    pub const Argument = struct {
        name: []const u8 = "",
        type: ?*Type = null,
        is_array: bool,
        array_bounds: ?[]const u8 = null,
        is_varargs: bool,
        is_instance_pointer: bool,
        default_value: ?[]const u8 = null,
    };
};

pub const Type = struct {
    declaration: []const u8,
    type_details: ?Details = null,
    description: ?*Description = null,

    pub const Details = struct {
        flavour: enum { function_pointer },
        return_type: ?*Type,
        arguments: []Function.Argument,
    };

    pub const Description = struct {
        kind: enum {
            Type,
            Function,
            Array,
            Pointer,
            Builtin,
            User,
        },
        name: []const u8 = "",
        inner_type: ?*Description = null,
        storage_classes: []enum {
            @"const",
            @"volatile",
            @"mutable",
        } = &.{},
        return_type: ?*Description = null, // only for kind == .Function
        parameters: []Description = &.{}, // only for kind == .Function
        bounds: ?[]const u8 = null, // only for kind == .Array
        is_nullable: ?bool = null, // only for kind == .Pointer
        builtin_type: ?enum {
            @"void",
            char,
            unsigned_char,
            short,
            unsigned_short,
            int,
            unsigned_int,
            long,
            unsigned_long,
            long_long,
            unsigned_long_long,
            float,
            double,
            long_double,
            @"bool",
        } = null,

        const To_Zig_Type_Options = struct {
            is_param: bool = false,
            is_slice: bool = false,
            parent_is_ptr: bool = false,
            assume_c_ptr: bool = false,
            char_is_u8: bool = false,
        };

        pub fn to_zig_type(self: Description, arena: std.mem.Allocator, options: To_Zig_Type_Options) ![]const u8 {
            if (options.is_param) {
                if (std.mem.eql(u8, self.name, "...")) {
                    return self.name;
                }
                const t = try self.to_zig_type(arena, .{});
                const param_name = try naming.get_param_name(arena, self.name);
                var temp = try std.ArrayList(u8).initCapacity(arena, t.len + param_name.len + 3);
                if (param_name.len == 0) temp.appendAssumeCapacity('_');
                temp.appendSliceAssumeCapacity(param_name);
                temp.appendSliceAssumeCapacity(": ");
                temp.appendSliceAssumeCapacity(t);
                return temp.items;
            }

            if (self.storage_classes.len > 0 and options.parent_is_ptr) {
                const without_storage_classes: Description = .{
                    .kind = self.kind,
                    .name = self.name,
                    .inner_type = self.inner_type,
                    .storage_classes = &.{},
                    .return_type = self.return_type,
                    .parameters = self.parameters,
                    .bounds = self.bounds,
                    .is_nullable = self.is_nullable,
                    .builtin_type = self.builtin_type,
                };
                const inner = try without_storage_classes.to_zig_type(arena, options);
                var temp = try std.ArrayList(u8).initCapacity(arena, inner.len + 16);
                for (self.storage_classes) |sc| {
                    const prefix = switch (sc) {
                        .@"const" => "const ",
                        .@"volatile" => "volatile ",
                        .@"mutable" => "",
                    };
                    try temp.appendSlice(prefix);
                }
                try temp.appendSlice(inner);
                return temp.items;
            }

            return switch (self.kind) {
                .Builtin => switch (self.builtin_type.?) {
                    .@"void" => @typeName(void),
                    .char => if (options.char_is_u8) @typeName(u8) else @typeName(i8),
                    .unsigned_char => @typeName(u8),
                    .short => @typeName(i16),
                    .unsigned_short => @typeName(u16),
                    .int => @typeName(i32),
                    .unsigned_int => @typeName(u32),
                    .long => @typeName(c_long),
                    .unsigned_long => @typeName(c_ulong),
                    .long_long => @typeName(i64),
                    .unsigned_long_long => @typeName(u64),
                    .float => @typeName(f32),
                    .double => @typeName(f64),
                    .long_double => @typeName(c_longdouble),
                    .@"bool" => @typeName(bool),
                },
                .Pointer => {
                    // By default we're assuming all function parameters and return pointers are
                    // non-null, single item pointers.  When that's not appropriate, we add special logic elsewhere.
                    // For struct fields, we assume all pointers are optional.
                    const is_nullable = self.is_nullable orelse false;
                    const inner = try self.inner_type.?.to_zig_type(arena, .{
                        .parent_is_ptr = true,
                        .char_is_u8 = true,
                    });
                    if (options.assume_c_ptr) {
                         if (std.mem.eql(u8, inner, "void")) {
                            return "?*anyopaque";
                        } else if (std.mem.eql(u8, inner, "const void")) {
                            return "?*const anyopaque";
                        } else if (self.inner_type.?.kind == .User) {
                            return std.mem.concat(arena, u8, &.{ "?*", inner });
                        } else {
                            return std.mem.concat(arena, u8, &.{ "[*c]", inner });
                        }
                    } else if (options.is_slice) {
                        if (std.mem.eql(u8, inner, "void") or std.mem.eql(u8, inner, "u8")) {
                            return std.mem.concat(arena, u8, &.{ if (is_nullable) "?" else "", "[]u8" });
                        } else if (std.mem.eql(u8, inner, "const void") or std.mem.eql(u8, inner, "const u8")) {
                            return std.mem.concat(arena, u8, &.{ if (is_nullable) "?" else "", "[]const u8" });
                        } else {
                            return std.mem.concat(arena, u8, &.{ if (is_nullable) "?" else "", "[]", inner });
                        }
                    } else if (std.mem.eql(u8, inner, "const u8")) {
                        return if (is_nullable) "?[*:0]const u8" else "[*:0]const u8";
                    } else if (std.mem.eql(u8, inner, "const Wchar")) {
                        return if (is_nullable) "?[*:0]const Wchar" else "[*:0]const Wchar";
                    }

                    var temp = try std.ArrayList(u8).initCapacity(arena, inner.len + 7);
                    if (is_nullable) temp.appendAssumeCapacity('?');
                    temp.appendAssumeCapacity('*');
                    if (std.mem.eql(u8, inner, "void")) {
                        temp.appendSliceAssumeCapacity("anyopaque");
                    } else if (std.mem.eql(u8, inner, "const void")) {
                        temp.appendSliceAssumeCapacity("const anyopaque");
                    } else {
                        temp.appendSliceAssumeCapacity(inner);
                    }
                    return temp.items;
                },
                .Type => try self.inner_type.?.to_zig_type(arena, .{}),
                .Function => {
                    var temp = try std.ArrayList(u8).initCapacity(arena, 256);
                    // These are always used as function pointers, but they're never marked const, so we'll just add that here.
                    temp.appendSliceAssumeCapacity("const fn(");
                    for (0.., self.parameters) |i, param| {
                        if (i > 0) try temp.appendSlice(", ");
                        try temp.appendSlice(try param.to_zig_type(arena, .{ .is_param = true }));
                    }
                    try temp.appendSlice(") callconv(.C) ");
                    try temp.appendSlice(try self.return_type.?.to_zig_type(arena, .{}));
                    return temp.items;
                },
                .Array => {
                    const inner = try self.inner_type.?.to_zig_type(arena, .{});
                    var temp = try std.ArrayList(u8).initCapacity(arena, inner.len + 32);
                    temp.appendAssumeCapacity('[');
                    const bounds_str = self.bounds orelse "";
                    const maybe_bound: ?usize = std.fmt.parseInt(usize, bounds_str, 0) catch b: {
                        if (std.mem.eql(u8, bounds_str, "IM_DRAWLIST_TEX_LINES_WIDTH_MAX+1")) {
                            try temp.appendSlice("c.IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 1");
                            break :b null;
                        } else if (std.mem.eql(u8, bounds_str, "IM_DRAWLIST_ARCFAST_TABLE_SIZE")) {
                            try temp.appendSlice("c.IM_DRAWLIST_ARCFAST_TABLE_SIZE");
                            break :b null;
                        } else if (std.mem.eql(u8, bounds_str, "ImGuiKey_KeysData_SIZE") or std.mem.eql(u8, bounds_str, "ImGuiKey_NamedKey_COUNT")) {
                            try temp.appendSlice("Key.named_key_region.len");
                            break :b null;
                        } else if (std.mem.eql(u8, bounds_str, "(IM_UNICODE_CODEPOINT_MAX +1)/4096/8")) {
                            try temp.appendSlice("(c.IM_UNICODE_CODEPOINT_MAX + 1)/4096/8");
                            break :b null;
                        } else if (std.mem.eql(u8, bounds_str, "32+1")) {
                            break :b 33;
                        } else if (std.mem.endsWith(u8, bounds_str, "_COUNT")) {
                            try temp.appendSlice(try naming.get_type_name(arena, bounds_str[0 .. bounds_str.len - "_COUNT".len]));
                            try temp.appendSlice(".count");
                            break :b null;
                        } else if (bounds_str.len == 0) {
                            break :b null;
                        }

                        log.warn("Unrecognized bounds expression: {s}", .{ bounds_str });
                        break :b null;
                    };
                    if (maybe_bound) |bound| {
                        try temp.writer().print("{}", .{ bound });
                    }
                    try temp.append(']');
                    try temp.appendSlice(inner);
                    return temp.items;
                },
                .User => if (std.meta.stringToEnum(Builtin_Names, self.name)) |b|
                    switch (b) {
                        .ImU8 => @typeName(u8),
                        .ImS8 => @typeName(i8),
                        .ImU16 => @typeName(u16),
                        .ImS16 => @typeName(i16),
                        .ImU32 => @typeName(u32),
                        .ImS32 => @typeName(i32),
                        .ImU64 => @typeName(u64),
                        .ImS64 => @typeName(i64),
                        .ImVec2 => naming.misc.Vec2,
                        .ImVec4 => naming.misc.Vec4,
                        .ImColor => naming.misc.Color,
                        .ImGuiID => try naming.get_type_name(arena, self.name),
                        .size_t => @typeName(usize),
                    } else try naming.get_type_name(arena, self.name),
            };
        }

        pub fn is_int(self: Description) bool {
            return switch (self.kind) {
                .Builtin => switch (self.builtin_type.?) {
                    .@"void" => false,
                    .@"bool" => false,
                    .char, .unsigned_char => true,
                    .short, .unsigned_short => true,
                    .int, .unsigned_int => true,
                    .long_long, .unsigned_long_long => true,
                    .long, .unsigned_long => true,
                    .float, .double, .long_double => false,
                },
                .Pointer => false,
                .Type => self.inner_type.?.is_int(),
                .Function => false,
                .Array => false,
                .User => if (std.meta.stringToEnum(Builtin_Names, self.name)) |b|
                    switch (b) {
                        .ImU8, .ImS8 => true,
                        .ImU16, .ImS16 => true,
                        .ImU32, .ImS32 => true,
                        .ImU64, .ImS64 => true,
                        .ImVec2 => false,
                        .ImVec4 => false,
                        .ImColor => false,
                        .ImGuiID => true,
                        .size_t => true,
                    } else std.mem.startsWith(u8, self.name, "ImWchar"),
            };
        }

         pub fn bit_size(self: Description) u16 {
            return switch (self.kind) {
                .Builtin => switch (self.builtin_type.?) {
                    .@"void" => 0,
                    .@"bool" => 8,
                    .char, .unsigned_char => 8,
                    .short, .unsigned_short => 16,
                    .int, .unsigned_int, .float => 32,
                    .long_long, .unsigned_long_long, .double => 64,
                    .long, .unsigned_long => @bitSizeOf(c_long),
                    .long_double => @bitSizeOf(c_longdouble),
                },
                .Pointer => @bitSizeOf(*anyopaque),
                .Type => self.inner_type.?.bit_size(),
                .Function => std.math.maxInt(u16),
                .Array => {
                    const bounds_str = self.bounds orelse "";
                    return std.fmt.parseInt(u16, bounds_str, 0) catch {
                        log.warn("Unrecognized bounds expression: {s}", .{ bounds_str });
                        return std.math.maxInt(u16);
                    };
                },
                .User => if (std.meta.stringToEnum(Builtin_Names, self.name)) |b|
                    switch (b) {
                        .ImU8, .ImS8 => 8,
                        .ImU16, .ImS16 => 16,
                        .ImU32, .ImS32 => 32,
                        .ImU64, .ImS64 => 64,
                        .ImVec2 => @bitSizeOf(util.Vec2),
                        .ImVec4 => @bitSizeOf(util.Vec4),
                        .ImColor => @bitSizeOf(util.Color),
                        .ImGuiID => 32,
                        .size_t => @bitSizeOf(usize),
                    } else 32, // just a guess :(
            };
        }

        pub fn to_c_style(self: Description) To_C_Style {
            return switch (self.kind) {
                .Builtin => .none,
                .Pointer => .ptrcast,
                .Type => self.inner_type.?.to_c_style(),
                .Function => .none,
                .Array => .address,
                .User => if (std.meta.stringToEnum(Builtin_Names, self.name)) |b|
                    switch (b) {
                        .ImU8, .ImS8 => .none,
                        .ImU16, .ImS16 => .none,
                        .ImU32, .ImS32 => .none,
                        .ImU64, .ImS64 => .none,
                        .ImVec2 => .to_c,
                        .ImVec4 => .to_c,
                        .ImColor => .to_c,
                        .ImGuiID => .none,
                        .size_t => .none,
                    } else .to_c,
            };
        }
    };
};

pub const To_C_Style = enum {
    none,
    to_c,
    ptrcast,
    bitcast,
    address,
    intfromenum,
    slice_ptr,
    slice_len,
    slice_end,
};

pub const Builtin_Names = enum {
    ImU8,
    ImS8,
    ImU16,
    ImS16,
    ImU32,
    ImS32,
    ImU64,
    ImS64,
    size_t,
    ImVec2,
    ImVec4,
    ImColor,
    ImGuiID,
};

pub const Comments = struct {
    preceding: []const []const u8 = &.{},
    attached: ?[]const u8 = null,
};

pub const Conditional = struct {
    condition: enum { ifdef, ifndef, @"if", ifnot },
    expression: []const u8,

    pub fn eval(self: Conditional) bool {
        if (std.mem.eql(u8, self.expression, "IMGUI_DISABLE_OBSOLETE_KEYIO")
            or std.mem.eql(u8, self.expression, "IMGUI_DISABLE_OBSOLETE_FUNCTIONS")
            or std.mem.eql(u8, self.expression, "IMGUI_HAS_DOCK")
            or std.mem.eql(u8, self.expression, "IMGUI_DISABLE_FILE_FUNCTIONS")
            or std.mem.eql(u8, self.expression, "IMGUI_DISABLE_DEFAULT_FILE_FUNCTIONS")
            or std.mem.eql(u8, self.expression, "IMGUI_ENABLE_STB_TRUETYPE")
            or std.mem.eql(u8, self.expression, "IMGUI_ENABLE_SSE")
        ) {
            return switch (self.condition) {
                .ifdef, .@"if" => true,
                .ifndef, .ifnot => false,
            };
        } else if (std.mem.eql(u8, self.expression, "IMGUI_ENABLE_TEST_ENGINE")
            or std.mem.eql(u8, self.expression, "ImTextureID")
            or std.mem.eql(u8, self.expression, "ImDrawIdx")
            or std.mem.eql(u8, self.expression, "ImDrawCallback")
            or std.mem.eql(u8, self.expression, "IMGUI_USE_WCHAR32")
            or std.mem.eql(u8, self.expression, "IMGUI_OVERRIDE_DRAWVERT_STRUCT_LAYOUT")
            or std.mem.eql(u8, self.expression, "IMGUI_DISABLE_DEFAULT_MATH_FUNCTIONS")
            or std.mem.eql(u8, self.expression, "IMGUI_DISABLE_DEBUG_TOOLS")
            or std.mem.eql(u8, self.expression, "defined(IMGUI_HAS_IMSTR)")
        ) {
            return switch (self.condition) {
                .ifdef, .@"if" => false,
                .ifndef, .ifnot => true,
            };
        }

        log.warn("Unrecognized conditional: {s} {s}", .{ @tagName(self.condition), self.expression });
        return false;
    }
};

pub const Source_Location = struct {
    filename: []const u8,
    line: usize = 0,
};

pub fn check_conditions(maybe_conditions: ?[]Conditional) bool {
    if (maybe_conditions) |conditions| {
        for (conditions) |condition| {
            if (!condition.eval()) return false;
        }
    }
    return true;
}

const Comment_Options = struct {
    newline: bool = false,
    line_prefix: []const u8 = "",
};
pub fn write_all_comments(maybe_comments: ?Comments, writer: anytype, options: Comment_Options) !void {
    if (maybe_comments) |comments| {
        if (comments.preceding.len == 0 and comments.attached == null) return;

        if (options.newline) try writer.writeByte('\n');

        for (comments.preceding) |comment| {
            try writer.print("{s}/{s}\n", .{ options.line_prefix, comment });
        }
        if (comments.attached) |comment| {
            try writer.print("{s}/{s}\n", .{ options.line_prefix, comment });
        }
    }
}

pub fn write_pre_comments(maybe_comments: ?Comments, writer: anytype, options: Comment_Options) !void {
    if (maybe_comments) |comments| {
        if (comments.preceding.len == 0) return;

        if (options.newline) try writer.writeByte('\n');

        for (comments.preceding) |comment| {
            try writer.print("{s}/{s}\n", .{ options.line_prefix, comment });
        }
    }
}

pub fn write_post_comments(maybe_comments: ?Comments, writer: anytype, options: Comment_Options) !void {
    if (maybe_comments) |comments| {
        if (comments.attached) |comment| {
            try writer.writeByte(if (options.newline) '\n' else ' ');
            try writer.print("{s}{s}\n", .{ options.line_prefix, comment });
            return;
        }
    }
    try writer.writeByte('\n');
}

pub fn parse_enum_storage_type(e: Enum) []const u8 {
    if (e.storage_type) |storage_type| {
        if (std.mem.eql(u8, storage_type.declaration, "int")) {
            return "i32";
        } else if (std.mem.eql(u8, storage_type.declaration, "ImU8")) {
            return "u8";
        } else {
            log.warn("Unrecognized storage type: {s} for enum type {s}", .{ storage_type.declaration, e.name });
        }
    }
    return "i32";
}

pub fn parse_flags_width(e: Enum) u8 {
    if (e.storage_type) |storage_type| {
        if (std.mem.eql(u8, storage_type.declaration, "int")) {
            return 32;
        } else if (std.mem.eql(u8, storage_type.declaration, "ImU8")) {
            return 8;
        } else {
            log.warn("Unrecognized storage type: {s} for flags type {s}", .{ storage_type.declaration, e.name });
        }
    }
    return 32;
}

const log = std.log.scoped(.Metadata);

const naming = @import("naming");
const util = @import("util");
const std = @import("std");
