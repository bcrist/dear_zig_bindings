cimgui_name: []const u8,
name: []const u8,
kind: Metadata.Struct_Or_Union,
fields: []const Field,
comments: ?Metadata.Comments,
is_internal: bool,
is_opaque: bool,
is_anonymous: bool,
source_location: ?Metadata.Source_Location,
functions: std.StringArrayHashMap(Function),

pub fn init(arena: std.mem.Allocator, gpa: std.mem.Allocator, meta: Metadata.Struct, is_internal: bool) !Enum_Type {
    var fields = std.ArrayList(Field).init(arena);

    const name = try naming.get_type_name(arena, meta.name);

    for (meta.fields) |f| {
        if (!Metadata.check_conditions(f.conditionals)) continue;

        if (f.width) |width| {
            try fields.append(.{
                .cimgui_name = f.name,
                .name = try naming.get_field_name(arena, meta.name, f.name),
                .type = try f.@"type".description.?.to_zig_type(arena, .{}),
                .comments = f.comments,
                .desired_bits = @intCast(width),
                .actual_bits = f.@"type".description.?.bit_size(),
            });
            
        } else {
            try fields.append(.{
                .cimgui_name = f.name,
                .name = try naming.get_field_name(arena, meta.name, f.name),
                .type = try f.@"type".description.?.to_zig_type(arena, .{ .assume_c_ptr = true }),
                .comments = f.comments,
                .desired_bits = null,
                .actual_bits = 0,
            });
        }
    }

    return .{
        .cimgui_name = meta.name,
        .name = name,
        .kind = meta.kind,
        .fields = fields.items,
        .comments = meta.comments,
        .is_internal = is_internal,
        .is_opaque = meta.forward_declaration,
        .is_anonymous = meta.is_anonymous,
        .source_location = meta.source_location,
        .functions = .init(gpa),
    };
}

pub fn write_alias(self: Enum_Type, writer: anytype) !void {
    try writer.print("\npub const {} = ig.{};\n", .{ std.zig.fmtId(self.name), std.zig.fmtId(self.name) });
}

pub fn write_opaque(self: Enum_Type, writer: anytype) !void {
    try writer.print(
        \\
        \\pub const {} = opaque{{}};
        \\
        , .{ std.zig.fmtId(self.name) });
}

pub fn write(self: Enum_Type, writer: anytype, validate_packed: bool, imgui_path: []const u8) !void {
    if (self.is_opaque) {
        try self.write_opaque(writer);
        return;
    }

    try writer.writeByte('\n');
    try Metadata.write_pre_comments(self.comments, writer, .{});

    try writer.print(
        \\pub const {} = extern {s} {{
        \\
        , .{ std.zig.fmtId(self.name), @tagName(self.kind) });

    if (self.source_location) |loc| {
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        try writer.print("    // see {s}:{}\n\n", .{
            try std.fs.path.resolve(fba.allocator(), &.{ imgui_path, loc.filename }),
            loc.line,
        });
    }

    // The bit packing rules here don't match the real algorithm clang uses, but it's
    // close enough for the current bitfields used in Dear ImGui structs, on little-endian platforms.
    var packed_count: usize = 0;
    var packed_offset: ?usize = null;
    var packed_bits_min_size: ?usize = null;
    for (self.fields) |field| {
        if (field.desired_bits) |desired_bits| {
            if (packed_offset == null) {
                try writer.print(
                    \\
                    \\    // N.B. Do not use packed fields from zig on big-endian platforms!
                    \\    packed_{}: packed struct {{
                    \\
                    , .{ packed_count });
                packed_offset = 0;
                packed_bits_min_size = 0;
                packed_count += 1;
            }
            try Metadata.write_pre_comments(field.comments, writer, .{ .newline = true, .line_prefix = "        " });
            if (desired_bits < field.actual_bits) {
                try writer.print("        {}: u{},", .{ std.zig.fmtId(field.name), desired_bits });
            } else {
                try writer.print("        {}: {s},", .{ std.zig.fmtId(field.name), field.type });
            }
            try Metadata.write_post_comments(field.comments, writer, .{});

            if (desired_bits > field.actual_bits) {
                try writer.print("        __reserved_{}: u{} = 0,\n", .{ packed_offset.?, desired_bits - field.actual_bits });
            }
            packed_offset = packed_offset.? + desired_bits;
            packed_bits_min_size = @max(packed_bits_min_size.?, field.actual_bits);

        } else {
            if (packed_offset) |offset| {
                var min_size = packed_bits_min_size.?;
                if (offset > min_size) {
                    if (offset <= 16) {
                        min_size = 16;
                    } else if (offset <= 32) {
                        min_size = 32;
                    } else if (offset <= 64) {
                        min_size = 64;
                    }
                }
                if (offset < min_size) {
                    try writer.print("        __reserved_{}: u{} = 0,\n", .{ offset, min_size - offset });
                }
                try writer.writeAll("    },\n");
                packed_offset = null;
            }
            try Metadata.write_pre_comments(field.comments, writer, .{ .newline = true, .line_prefix = "    " });
            try writer.print("    {}: {s},", .{ std.zig.fmtId(field.name), field.type });
            try Metadata.write_post_comments(field.comments, writer, .{});
        }
    }
    if (packed_offset) |offset| {
        var min_size = packed_bits_min_size.?;
        if (offset > min_size) {
            if (offset <= 16) {
                min_size = 16;
            } else if (offset <= 32) {
                min_size = 32;
            } else if (offset <= 64) {
                min_size = 64;
            }
        }
        if (offset < min_size) {
            try writer.print("        __reserved_{}: u{} = 0,\n", .{ offset, min_size - offset });
        }
        try writer.writeAll("    },\n");
        packed_offset = null;
    }

    if (!self.is_anonymous) {
        try writer.print(
            \\
            \\    pub const {} = c.{};
            \\
            , .{ std.zig.fmtId(naming.misc.C_Type), std.zig.fmtId(self.cimgui_name) });

        if (packed_count == 0 or validate_packed) {
            try writer.print(
                \\    comptime {{
                \\        if (@sizeOf(@This()) != @sizeOf(c.{0})) {{
                \\            @compileError(std.fmt.comptimePrint("{0} size mismatch: @sizeOf({1}) == {{}}, @sizeOf(c.{0}) == {{}}", .{{ @sizeOf(@This()), @sizeOf(c.{0}) }}));
                \\        }}
                \\    }}
                \\
                , .{
                    std.zig.fmtId(self.cimgui_name),
                    std.zig.fmtId(self.name),
                });
        }

        try writer.writeAll("\n    const mixin = " ++ naming.misc.Struct_Union_Mixin ++ "(@This());\n");

        const Struct_Union_Mixin = @field(util, naming.misc.Struct_Union_Mixin);
        for (@typeInfo(Struct_Union_Mixin(struct { const C_Type = u32; const CType = u32; })).@"struct".decls) |decl| {
            const has_override = o: {
                if (@hasDecl(util, "structs")) {
                    inline for (@typeInfo(util.structs).@"struct".decls) |struct_decl| {
                        if (std.mem.eql(u8, self.cimgui_name, struct_decl.name)) {
                            for (@typeInfo(@field(util.structs, struct_decl.name)).@"struct".decls) |override_decl| {
                                if (std.mem.eql(u8, decl.name, override_decl.name)) break :o true;
                            }
                        }
                    }
                }
                break :o false;
            };
            if (!has_override) {
                try writer.print("    pub const {} = mixin.{};\n", .{
                    std.zig.fmtId(decl.name),
                    std.zig.fmtId(decl.name),
                });
            }
        }

        try writer.writeByte('\n');

        for (self.functions.values()) |f| {
            try f.write(writer, "    ", imgui_path);
        }

        if (@hasDecl(util, "structs")) {
            inline for (@typeInfo(util.structs).@"struct".decls) |struct_decl| {
                if (std.mem.eql(u8, self.cimgui_name, struct_decl.name)) {
                    try writer.writeByte('\n');
                    for (@typeInfo(@field(util.structs, struct_decl.name)).@"struct".decls) |decl| {
                        try writer.print("    pub const {} = util.structs.{}.{};\n", .{
                            std.zig.fmtId(decl.name),
                            std.zig.fmtId(struct_decl.name),
                            std.zig.fmtId(decl.name),
                        });
                    }
                }
            }
        }
    }

    try writer.writeAll("};");
    try Metadata.write_post_comments(self.comments, writer, .{});
}

pub const Field = struct {
    cimgui_name: []const u8,
    name: []const u8,
    type: []const u8,
    comments: ?Metadata.Comments,
    desired_bits: ?u16,
    actual_bits: u16,
};

const Enum_Type = @This();

const Function = @import("Function.zig");
const Metadata = @import("Metadata.zig");
const naming = @import("naming");
const util = @import("util");
const std = @import("std");
