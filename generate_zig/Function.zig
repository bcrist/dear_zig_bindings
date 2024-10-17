cimgui_name: []const u8,
name: []const u8,
params: []const Parameter,
return_type: []const u8,
return_type_from_c: Metadata.To_C_Style,
comments: ?Metadata.Comments,
is_internal: bool,
options_struct_name: []const u8,
source_location: ?Metadata.Source_Location,

pub fn init(arena: std.mem.Allocator, meta: Metadata.Function, is_internal: bool) !Function {
    var params = std.ArrayList(Parameter).init(arena);

    const name = try naming.get_fn_name(arena, meta.name, meta.original_fully_qualified_name, .{
        .is_unformatted_helper = meta.is_unformatted_helper,
    });

    var options_count: usize = 0;
    var has_options_flags = false;

    var arg_lookup = std.StringHashMap(u32).init(arena);
    defer arg_lookup.deinit();

    for (meta.arguments) |p| {
        if (p.is_varargs) {
            return error.SkipFunction;
        } else {
            if (std.mem.eql(u8, p.type.?.declaration, "va_list")) return error.SkipFunction;

            const desc = p.type.?.description.?;

            try arg_lookup.put(p.name, @intCast(params.items.len));

            if (std.mem.endsWith(u8, p.name, "_size") and desc.is_int()) {
                const base_name = p.name[0 .. p.name.len - "_size".len];
                if (arg_lookup.get(base_name)) |base_index| {
                    params.items[base_index].to_c_style = .slice_ptr;
                    params.items[base_index].type = try params.items[base_index].type_desc.to_zig_type(arena, .{ .is_slice = true });

                    try params.append(.{
                        .cimgui_name = p.name,
                        .name = "",
                        .type = try desc.to_zig_type(arena, .{}),
                        .type_desc = desc.*,
                        .default_value = null,
                        .to_c_style = .slice_len,
                        .related_param_index = base_index,
                    });
                    continue;
                }
            } else if (std.mem.endsWith(u8, p.name, "_count") and desc.is_int()) {
                const base_name = p.name[0 .. p.name.len - "_count".len];
                if (arg_lookup.get(base_name)) |base_index| {
                    params.items[base_index].to_c_style = .slice_ptr;
                    params.items[base_index].type = try params.items[base_index].type_desc.to_zig_type(arena, .{ .is_slice = true });

                    try params.append(.{
                        .cimgui_name = p.name,
                        .name = "",
                        .type = try desc.to_zig_type(arena, .{}),
                        .type_desc = desc.*,
                        .default_value = null,
                        .to_c_style = .slice_len,
                        .related_param_index = base_index,
                    });
                    continue;
                }
            } else if (std.mem.eql(u8, p.name, "sz") and desc.is_int()) {
                if (arg_lookup.get("data")) |base_index| {
                    params.items[base_index].to_c_style = .slice_ptr;
                    params.items[base_index].type = try params.items[base_index].type_desc.to_zig_type(arena, .{ .is_slice = true });

                    try params.append(.{
                        .cimgui_name = p.name,
                        .name = "",
                        .type = try desc.to_zig_type(arena, .{}),
                        .type_desc = desc.*,
                        .default_value = null,
                        .to_c_style = .slice_len,
                        .related_param_index = base_index,
                    });
                    continue;
                }
            } else if (std.mem.endsWith(u8, p.name, "_end")) {
                var buf: [128]u8 = undefined;
                const base_name = p.name[0 .. p.name.len - "_end".len];
                const begin_name = try std.fmt.bufPrint(&buf, "{s}_begin", .{ base_name });
                if (arg_lookup.get(base_name) orelse arg_lookup.get(begin_name)) |base_index| {
                    params.items[base_index].name = try naming.get_param_name(arena, base_name);
                    params.items[base_index].to_c_style = .slice_ptr;
                    params.items[base_index].type = try params.items[base_index].type_desc.to_zig_type(arena, .{ .is_slice = true });

                    try params.append(.{
                        .cimgui_name = p.name,
                        .name = "",
                        .type = try desc.to_zig_type(arena, .{}),
                        .type_desc = desc.*,
                        .default_value = null,
                        .to_c_style = .slice_end,
                        .related_param_index = base_index,
                    });
                    continue;
                }
            }

            var default_value = p.default_value;
            if (default_value) |default| {
                options_count += 1;
                if (std.mem.endsWith(u8, p.type.?.declaration, "Flags")) {
                    has_options_flags = true;
                    if (std.mem.eql(u8, default, "0")) {
                        default_value = ".none";
                    }
                } else if (std.mem.eql(u8, default, "0")) {
                    if (std.mem.eql(u8, p.type.?.declaration, "ImGuiCond")) {
                        default_value = ".none";
                    }
                } else if (std.mem.endsWith(u8, default, "_None")) {
                    default_value = ".none";
                } else if (std.mem.eql(u8, default, "ImVec2(0, 0)") or std.mem.eql(u8, default, "ImVec2(0.0f, 0.0f)") or std.mem.eql(u8, default, "ImVec4(0, 0, 0, 0)")) {
                    default_value = ".zeroes";
                } else if (std.mem.eql(u8, default, "ImVec2(1, 1)") or std.mem.eql(u8, default, "ImVec4(1, 1, 1, 1)")) {
                    default_value = ".ones";
                } else if (std.mem.eql(u8, default, "ImVec2(1, 0)")) {
                    default_value = ".init(1, 0)";
                } else if (std.mem.eql(u8, default, "ImVec2(0, 1)")) {
                    default_value = ".init(0, 1)";
                } else if (std.mem.eql(u8, default, "ImVec2(-FLT_MIN, 0)")) {
                    default_value = ".init(-std.math.floatMin(f32), 0)";
                } else if (std.mem.eql(u8, default, "FLT_MAX")) {
                    default_value = "std.math.floatMax(f32)";
                } else if (std.mem.eql(u8, default, "sizeof(float)")) {
                    default_value = "@sizeOf(f32)";
                } else if (std.mem.eql(u8, default, "IM_COL32(255, 0, 0, 255)")) {
                    default_value = naming.misc.Color_Packed ++ ".red." ++ naming.misc.to_c ++ "()";
                } else if (std.mem.eql(u8, default, "IM_COL32_WHITE")) {
                    default_value = naming.misc.Color_Packed ++ ".white." ++ naming.misc.to_c ++ "()";
                } else {
                    if (std.mem.endsWith(u8, default, "f")) {
                        if (std.fmt.parseFloat(f32, default[0 .. default.len - 1]) catch null) |val| {
                            default_value = try std.fmt.allocPrint(arena, "{d}", .{ val });
                        }
                    }
                }
            }

            try params.append(.{
                .cimgui_name = p.name,
                .name = try naming.get_param_name(arena, p.name),
                .type = try desc.to_zig_type(arena, .{}),
                .type_desc = desc.*,
                .default_value = default_value,
                .to_c_style = desc.to_c_style(),
                .related_param_index = 0,
            });
        }
    }

    var return_type = try meta.return_type.description.?.to_zig_type(arena, .{});
    const return_type_from_c = meta.return_type.description.?.to_c_style();

    // TODO figure out a better way to deal with dear_bindings not giving enough info about pointers
    // to accurately determine the proper zig type
    if (std.meta.stringToEnum(Optional_Return_Type, meta.name) != null and !std.mem.startsWith(u8, return_type, "?")) {
        return_type = try std.mem.concat(arena, u8, &.{ "?", return_type });
    } else if (std.meta.stringToEnum(Optional_First_Parameter_Type, meta.name) != null and !std.mem.startsWith(u8, params.items[0].type, "?")) {
        params.items[0].type = try std.mem.concat(arena, u8, &.{ "?", params.items[0].type });
    } else if (std.meta.stringToEnum(Optional_Second_Parameter_Type, meta.name) != null and !std.mem.startsWith(u8, params.items[1].type, "?")) {
        params.items[1].type = try std.mem.concat(arena, u8, &.{ "?", params.items[1].type });
    } else if (std.meta.stringToEnum(Optional_Third_Parameter_Type, meta.name) != null and !std.mem.startsWith(u8, params.items[2].type, "?")) {
        params.items[2].type = try std.mem.concat(arena, u8, &.{ "?", params.items[2].type });
    }

    if (options_count == 1 and has_options_flags) {
        // if there's only one default values param, and it's a flags type, then it's easier to use
        // if it's not wrapped in an options struct:
        options_count = 0;
        for (params.items) |*param| {
            param.default_value = null;
        }
    }

    const options_struct_name = if (options_count > 0) try naming.get_options_struct_name(arena, name) else "";

    return .{
        .cimgui_name = meta.name,
        .name = name,
        .params = params.items,
        .return_type = return_type,
        .return_type_from_c = return_type_from_c,
        .comments = meta.comments,
        .is_internal = is_internal,
        .options_struct_name = options_struct_name,
        .source_location = meta.source_location,
    };
}

pub fn write(self: Function, writer: anytype, indent: []const u8, imgui_path: []const u8) !void {
    if (self.options_struct_name.len > 0) {
        try writer.print(
            \\
            \\{s}const {} = struct {{
            \\
            , .{ indent, std.zig.fmtId(self.options_struct_name) });

        for (self.params) |p| {
            if (p.default_value) |default_value| {
                var type_prefix: []const u8 = "";
                var final_default_value = default_value;
                if (std.mem.eql(u8, final_default_value, "NULL")) {
                    if (!std.mem.startsWith(u8, p.type, "?")) {
                        type_prefix = "?";
                    }
                    final_default_value = "null";
                }

                try writer.print("{s}    {}: {s}{s} = {s},\n", .{
                    indent,
                    std.zig.fmtId(p.name),
                    type_prefix,
                    p.type,
                    final_default_value,
                });
            }
        }

        try writer.print("{s}}};\n", .{ indent });
    }

    try Metadata.write_all_comments(self.comments, writer, .{ .newline = true, .line_prefix = indent });

    try writer.print("{s}pub inline fn {}(", .{ indent, std.zig.fmtId(self.name) });

    var first = true;
    for (self.params) |p| {
        if (p.default_value != null) continue;
        if (p.to_c_style == .slice_end or p.to_c_style == .slice_len) continue;
        if (first) {
            first = false;
        } else try writer.writeAll(", ");
        if (p.type.len == 0) {
            try writer.writeAll(p.name);
        } else {
            try writer.print("{}: {s}", .{ std.zig.fmtId(p.name), p.type });
        }
    }

    if (self.options_struct_name.len > 0) {
        if (first) {
            first = false;
        } else try writer.writeAll(", ");
        try writer.print("options: {s}{}", .{
            if (indent.len > 0) "@This()." else "",
            std.zig.fmtId(self.options_struct_name),
        });
    }

    try writer.print(") {s} {{\n", .{ self.return_type });

    if (self.source_location) |loc| {
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        try writer.print("{s}    // see {s}:{}\n", .{
            indent,
            try std.fs.path.resolve(fba.allocator(), &.{ imgui_path, loc.filename }),
            loc.line,
        });
    }

    try writer.print("{s}    {s}", .{ indent, if (std.mem.eql(u8, self.return_type, "void")) "" else "return " });

    switch (self.return_type_from_c) {
        .none, .address, .slice_ptr, .slice_len, .slice_end => {},
        .ptrcast => try writer.writeAll("@ptrCast("),
        .bitcast => try writer.writeAll("@bitCast("),
        .intfromenum => try writer.writeAll("@enumFromInt("),
        .to_c => try writer.print(".{s}(", .{ naming.misc.from_c }),
    }

    try writer.print("c.{}(", .{ std.zig.fmtId(self.cimgui_name) });

    first = true;
    for (self.params) |p| {
        if (first) {
            first = false;
        } else try writer.writeAll(", ");
        if (p.type.len == 0) {
            try writer.writeAll(p.name);
        } else {
            const prefix = if (p.default_value == null) "" else "options.";
            switch (p.to_c_style) {
                .none => try writer.print("{s}{}", .{ prefix, std.zig.fmtId(p.name) }),
                .ptrcast => try writer.print("@ptrCast({s}{})", .{ prefix, std.zig.fmtId(p.name) }),
                .bitcast => try writer.print("@bitCast({s}{})", .{ prefix, std.zig.fmtId(p.name) }),
                .address => try writer.print("&{s}{}", .{ prefix, std.zig.fmtId(p.name) }),
                .intfromenum => try writer.print("@intFromEnum({s}{})", .{ prefix, std.zig.fmtId(p.name) }),
                .to_c => try writer.print("{s}{}.{s}()", .{ prefix, std.zig.fmtId(p.name), naming.misc.to_c }),
                .slice_ptr => try writer.print("@ptrCast({}.ptr)", .{ std.zig.fmtId(p.name) }),
                .slice_len => try writer.print("@intCast({}.len)", .{ std.zig.fmtId(self.params[p.related_param_index].name) }),
                .slice_end => try writer.print("@ptrCast({}.ptr + {0}.len)", .{ std.zig.fmtId(self.params[p.related_param_index].name) }),
            }
        }
    }

    try writer.writeByte(')');

    switch (self.return_type_from_c) {
        .none, .address, .slice_ptr, .slice_len, .slice_end => {},
        .ptrcast, .bitcast, .intfromenum, .to_c => try writer.writeByte(')'),
    }

    try writer.print(";\n{s}}}\n", .{ indent });
}

const Optional_Return_Type = enum {
    ImGui_GetDrawData,
    ImGui_TableGetSortSpecs,
    ImGui_AcceptDragDropPayload,
    ImGui_GetDragDropPayload,
    ImGui_FindViewportByID,
    ImGui_FindViewportByPlatformHandle,
    ImGuiStorage_GetVoidPtr,
    ImFont_FindGlyphNoFallback,
};

const Optional_First_Parameter_Type = enum {
    ImGui_PushFont,
    ImGui_PushIDPtr,
    ImGui_GetIDPtr,
    ImGui_TreeNodePtrUnformatted,
    ImGui_TreeNodeExPtrUnformatted,
    ImGui_TreePushPtr,
};

const Optional_Second_Parameter_Type = enum {
};

const Optional_Third_Parameter_Type = enum {
    ImGuiStorage_SetVoidPtr,
};

pub const Parameter = struct {
    cimgui_name: []const u8,
    name: []const u8,
    type: []const u8,
    type_desc: Metadata.Type.Description,
    default_value: ?[]const u8,
    to_c_style: Metadata.To_C_Style,
    related_param_index: u32,
};

const Function = @This();

const util = @import("util");
const Metadata = @import("Metadata.zig");
const naming = @import("naming");
const std = @import("std");
