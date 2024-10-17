cimgui_name: []const u8,
name: []const u8,
storage_type: []const u8,
count: ?i32,
constants: []const Constant,
comments: ?Metadata.Comments,
is_internal: bool,
source_location: ?Metadata.Source_Location,

pub fn init(arena: std.mem.Allocator, meta: Metadata.Enum, is_internal: bool) !Enum_Type {
    var constants = std.ArrayList(Constant).init(arena);

    const name = try naming.get_type_name(arena, meta.name);

    var count: ?i32 = null;

    for (meta.elements) |*el| {
        if (el.is_internal) continue;
        if (!Metadata.check_conditions(el.conditionals)) continue;

        if (el.is_count) {
            count = @intCast(el.value);
        } else {
            try constants.append(.{
                .cimgui_name = el.name,
                .name = try naming.get_field_name(arena, meta.name, el.name),
                .value = @intCast(el.value),
                .comments = el.comments,
            });
        }
    }

    var maybe_comments = meta.comments;
    if (maybe_comments) |*comments| {
        if (comments.attached) |comment| {
            if (std.mem.startsWith(u8, comment, "// Forward declared enum type ")) {
                comments.attached = null;
            }
        }
    }

    return .{
        .cimgui_name = meta.name,
        .name = name,
        .storage_type = Metadata.parse_enum_storage_type(meta),
        .count = count,
        .constants = constants.items,
        .comments = maybe_comments,
        .is_internal = is_internal,
        .source_location = meta.source_location,
    };
}

pub fn write_alias(self: Enum_Type, writer: anytype) !void {
    try writer.print("\nconst {} = ig.{};\n", .{ std.zig.fmtId(self.name), std.zig.fmtId(self.name) });
}

pub fn write(self: Enum_Type, writer: anytype, maybe_base_type: ?*Enum_Type, imgui_path: []const u8) !void {
    try writer.writeByte('\n');
    try Metadata.write_pre_comments(self.comments, writer, .{});

    try writer.print(
        \\pub const {} = enum ({s}) {{
        \\
        , .{ std.zig.fmtId(self.name), self.storage_type });

    if (self.source_location) |loc| {
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        try writer.print("    // see {s}:{}\n\n", .{
            try std.fs.path.resolve(fba.allocator(), &.{ imgui_path, loc.filename }),
            loc.line,
        });
    }

    const is_key_enum = std.mem.eql(u8, self.cimgui_name, "ImGuiKey");

    var keydata_size: ?i32 = null;
    var keydata_offset: ?i32 = null;

    if (maybe_base_type) |base| {
        for (base.constants) |constant| {
            try Metadata.write_pre_comments(constant.comments, writer, .{ .newline = true, .line_prefix = "    " });
            try writer.print("    {} = {},", .{ std.zig.fmtId(constant.name), constant.value });
            try Metadata.write_post_comments(constant.comments, writer, .{});
        }
    }

    for (self.constants) |constant| {
        if (is_key_enum) {
            if (std.mem.startsWith(u8, constant.cimgui_name, "ImGuiMod_")) continue;

            if (std.mem.eql(u8, constant.cimgui_name, "ImGuiKey_KeysData_SIZE")) {
                keydata_size = constant.value;
                continue;
            }
            if (std.mem.eql(u8, constant.cimgui_name, "ImGuiKey_KeysData_OFFSET")) {
                keydata_offset = constant.value;
                continue;
            }
        }

        try Metadata.write_pre_comments(constant.comments, writer, .{ .newline = true, .line_prefix = "    " });
        try writer.print("    {} = {},", .{ std.zig.fmtId(constant.name), constant.value });
        try Metadata.write_post_comments(constant.comments, writer, .{});
    }
    try writer.writeAll("    _,\n");

    if (is_key_enum) {
        try writer.writeAll(
            \\
            \\    pub fn without_mods(self: Key) Key {
            \\        return @enumFromInt(@intFromEnum(self) & ~0xF000);
            \\    }
            \\
            \\    pub fn with_ctrl(self: Key) Key {
            \\        return @enumFromInt(@intFromEnum(self) | (1 << 12));
            \\    }
            \\    pub fn with_shift(self: Key) Key {
            \\        return @enumFromInt(@intFromEnum(self) | (1 << 13));
            \\    }
            \\    pub fn with_alt(self: Key) Key {
            \\        return @enumFromInt(@intFromEnum(self) | (1 << 14));
            \\    }
            \\    pub fn with_super(self: Key) Key {
            \\        return @enumFromInt(@intFromEnum(self) | (1 << 15));
            \\    }
            \\
            \\    pub fn has_ctrl(self: Key) bool {
            \\        return (@intFromEnum(self) & (1 << 12)) != 0;
            \\    }
            \\    pub fn has_shift(self: Key) bool {
            \\        return (@intFromEnum(self) & (1 << 13)) != 0;
            \\    }
            \\    pub fn has_alt(self: Key) bool {
            \\        return (@intFromEnum(self) & (1 << 14)) != 0;
            \\    }
            \\    pub fn has_super(self: Key) bool {
            \\        return (@intFromEnum(self) & (1 << 15)) != 0;
            \\    }
            \\
        );

        try writer.print(
            \\
            \\    pub const named_key_region = struct {{
            \\        pub const begin_index = {};
            \\        pub const end_index = {};
            \\        pub const len = end_index - begin_index;
            \\    }};
            \\
            , .{ keydata_offset.?, keydata_offset.? + keydata_size.? });

    }

    if (self.count) |count| {
        try writer.print("\n    pub const count = {};\n", .{ count });
    }

    if (maybe_base_type) |base| {
        try writer.print("\n    pub const Base = ig.{};\n", .{ std.zig.fmtId(base.name) });
    }

    try writer.writeAll("\n    const mixin = " ++ naming.misc.Enum_Mixin ++ "(@This());\n");

    const Enum_Mixin = @field(util, naming.misc.Enum_Mixin);
    for (@typeInfo(Enum_Mixin(Dummy)).@"struct".decls) |decl| {
        try writer.print("    pub const {} = mixin.{};\n", .{
            std.zig.fmtId(decl.name),
            std.zig.fmtId(decl.name),
        });
    }

    try writer.writeAll("};");
    try Metadata.write_post_comments(self.comments, writer, .{});
}

pub const Constant = struct {
    cimgui_name: []const u8,
    name: []const u8,
    value: i32,
    comments: ?Metadata.Comments,
};

const Dummy = enum (u32) {
    x,
};

const Enum_Type = @This();

const util = @import("util");
const Metadata = @import("Metadata.zig");
const naming = @import("naming");
const std = @import("std");
