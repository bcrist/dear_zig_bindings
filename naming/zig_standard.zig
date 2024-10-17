pub fn get_type_name(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, name, "ImVector_")) {
        if (std.mem.eql(u8, name, "ImVector_char")) {
            return "Vector(u8)";
        } else if (std.mem.eql(u8, name, "ImVector_unsigned_char")) {
            return "Vector(u8)";
        } else if (std.mem.eql(u8, name, "ImVector_ImU32")) {
            return "Vector(u32)";
        } else if (std.mem.eql(u8, name, "ImVector_int")) {
            return "Vector(i32)";
        } else if (std.mem.eql(u8, name, "ImVector_float")) {
            return "Vector(f32)";
        } else if (std.mem.eql(u8, name, "ImVector_const_charPtr")) {
            return "Vector([*:0]const u8)";
        } else if (std.mem.eql(u8, name, "ImVector_ImGuiDockRequest")) {
            return "OpaqueVector(DockRequest)";
        } else if (std.mem.eql(u8, name, "ImVector_ImGuiDockNodeSettings")) {
            return "OpaqueVector(DockNodeSettings)";
        }
        const payload_name = name["ImVector_".len..];

        if (std.mem.endsWith(u8, payload_name, "Ptr")) {
            const inner = try get_type_name(arena, payload_name[0 .. payload_name.len - "Ptr".len]);
            return std.fmt.allocPrint(arena, "Vector(*{s})", .{ inner });
        } else {
            const inner = try get_type_name(arena, payload_name);
            return std.fmt.allocPrint(arena, "Vector({s})", .{ inner });
        }
    } else if (std.mem.startsWith(u8, name, "ImPool_")) {
        const payload_name = name["ImPool_".len..];

        if (std.mem.endsWith(u8, payload_name, "Ptr")) {
            const inner = try get_type_name(arena, payload_name[0 .. payload_name.len - "Ptr".len]);
            return std.fmt.allocPrint(arena, "Pool(*{s})", .{ inner });
        } else {
            const inner = try get_type_name(arena, payload_name);
            return std.fmt.allocPrint(arena, "Pool({s})", .{ inner });
        }
    } else if (std.mem.startsWith(u8, name, "ImSpan_")) {
        const payload_name = name["ImSpan_".len..];

        if (std.mem.endsWith(u8, payload_name, "Ptr")) {
            const inner = try get_type_name(arena, payload_name[0 .. payload_name.len - "Ptr".len]);
            return std.fmt.allocPrint(arena, "Span(*{s})", .{ inner });
        } else {
            const inner = try get_type_name(arena, payload_name);
            return std.fmt.allocPrint(arena, "Span({s})", .{ inner });
        }
    } else if (std.mem.startsWith(u8, name, "ImChunkStream_")) {
        const payload_name = name["ImChunkStream_".len..];

        if (std.mem.endsWith(u8, payload_name, "Ptr")) {
            const inner = try get_type_name(arena, payload_name[0 .. payload_name.len - "Ptr".len]);
            return std.fmt.allocPrint(arena, "ChunkStream(*{s})", .{ inner });
        } else {
            const inner = try get_type_name(arena, payload_name);
            return std.fmt.allocPrint(arena, "ChunkStream({s})", .{ inner });
        }
    }

    if (std.mem.eql(u8, name, "ImStb_STB_TexteditState")) {
        return "StbTexteditState";
    }

    var final_name = name;
    if (std.mem.startsWith(u8, final_name, "ImGui_")) {
        final_name = final_name["ImGui_".len..];
    }
    if (std.mem.startsWith(u8, final_name, "ImGui")) {
        final_name = final_name["ImGui".len..];
    }
    if (final_name.len >= 3 and final_name[0] == 'I' and final_name[1] == 'm' and std.ascii.isUpper(final_name[2])) {
        final_name = final_name[2..];
    }
    if (std.mem.endsWith(u8, final_name, "_")) {
        final_name = final_name[0 .. final_name.len - 1];
    }
    if (std.mem.endsWith(u8, final_name, "Private")) {
        final_name = final_name[0 .. final_name.len - "Private".len];
    }
    return final_name;
}

pub fn get_field_name(arena: std.mem.Allocator, type_name: []const u8, name: []const u8) ![]const u8 {
    var final_type_name = type_name;
    if (std.mem.endsWith(u8, final_type_name, "_")) {
        final_type_name = final_type_name[0 .. final_type_name.len - 1];
    }
    if (std.mem.endsWith(u8, final_type_name, "Private")) {
        final_type_name = final_type_name[0 .. final_type_name.len - "Private".len];
    }
    var final_name = name;
    if (std.ascii.startsWithIgnoreCase(final_name, final_type_name)) {
        final_name = final_name[final_type_name.len..];
        if (std.mem.startsWith(u8, final_name, "_")) {
            final_name = final_name[1..];
        }
    }
    if (std.mem.startsWith(u8, final_name, "ImGui_")) {
        final_name = final_name["ImGui_".len..];
    }
    if (std.mem.startsWith(u8, final_name, "ImGui")) {
        final_name = final_name["ImGui".len..];
    }
    if (std.mem.endsWith(u8, final_name, "_")) {
        final_name = final_name[0 .. final_name.len - 1];
    }

    return try pascal_or_camel_to_lower_snake(arena, final_name);
}

pub fn get_param_name(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    var final_name = name;
    if (std.mem.startsWith(u8, final_name, "p_")) {
        final_name = final_name[2..];
    }
    final_name = try pascal_or_camel_to_lower_snake(arena, final_name);

    // rename some params that would otherwise cause duplicate symbols
    if (std.mem.eql(u8, final_name, "c")) {
        return "_c";
    } else if (std.mem.eql(u8, final_name, "button")) {
        return "btn";
    } else if (std.mem.eql(u8, final_name, "columns")) {
        return "cols";
    } else if (std.mem.eql(u8, final_name, "text")) {
        return "txt";
    } else if (std.mem.eql(u8, final_name, "shortcut")) {
        return "_shortcut";
    } else if (std.mem.eql(u8, final_name, "separator")) {
        return "_separator";
    } else if (std.mem.eql(u8, final_name, "spacing")) {
        return "_spacing";
    } else if (std.mem.eql(u8, final_name, "version_str")) {
        return "version";
    }
    return final_name;
}

const Get_Fn_Name_Options = struct {
    is_unformatted_helper: bool = false,
};

pub fn get_fn_name(arena: std.mem.Allocator, cimgui_name: []const u8, cpp_name: []const u8, options: Get_Fn_Name_Options) ![]const u8 {
    if (special_case_fns.get(cimgui_name)) |special_name| return special_name;

    var final_name = cpp_name;
    if (std.mem.indexOf(u8, final_name, "::")) |i| {
        final_name = final_name[i + 2 ..];
    }
    if (std.mem.indexOf(u8, final_name, "IDFrom")) |i| {
        const copy = try arena.dupe(u8, final_name);
        copy[i + 1] = 'd'; // ensure _ before from
        final_name = copy;
    }
    final_name = try pascal_or_camel_to_camel(arena, final_name);
    if (options.is_unformatted_helper) {
        final_name = try std.mem.concat(arena, u8, &.{ final_name, "Unformatted" });
    }
    return final_name;
}

const special_case_fns = std.StaticStringMap([]const u8).initComptime(.{
    .{ "ImGui_IsRectVisibleBySize", "isRectFromCursorVisible" },
    .{ "ImGui_OpenPopupID", "openPopupId" },
    .{ "ImGui_IsPopupOpenID", "isPopupOpenId" },
    .{ "ImGui_PlotHistogramCallbackEx", "plotHistogramCallback" },
    .{ "ImGui_PlotLinesCallbackEx", "plotLinesCallback" },
    .{ "ImGui_ListBoxCallbackEx", "listBoxCallback" },
    .{ "ImGui_SelectableBoolPtrEx", "selectableStateful" },
    .{ "ImGui_CollapsingHeaderBoolPtr", "collapsingHeaderStateful" },
    .{ "ImGui_TreePushPtr", "treePushPtrId" },
    .{ "ImGui_TreeNodePtrUnformatted", "treeNodePtrIdUnformatted" },
    .{ "ImGui_TreeNodeExPtrUnformatted", "treeNodeExPtrIdUnformatted" },
    .{ "ImGui_GetIDInt", "getIdInt" },
    .{ "ImGui_GetIDPtr", "getIdPtr" },
    .{ "ImGui_GetIDStr", "getId" },
    .{ "ImGui_PushIDStr", "pushId" },
    .{ "ImGui_PushIDPtr", "pushIdPtr" },
    .{ "ImGui_PushIDInt", "pushIdInt" },
    .{ "ImGui_PushStyleVarImVec2", "pushStyleVarVec2" },
    .{ "ImGui_BeginChildID", "beginChildId" },
    .{ "ImDrawList_AddTextImFontPtrEx", "addTextFont" },
    .{ "ImRect_ExpandImVec2", "expandVec2" },
    .{ "ImRect_AddImRect", "addRect" },
    .{ "ImRect_ContainsImRect", "containsRect" },
    .{ "ImGui_TableGcCompactTransientBuffersImGuiTableTempDataPtr", "tableGcCompactTransientBuffersTempData" },
    .{ "ImGui_GetKeyDataImGuiContextPtr", "getKeyDataCtx" },
    .{ "ImGui_GetIDWithSeed", "getIdWithSeedInt" },
    .{ "ImGui_GetIDWithSeedStr", "getIdWithSeedStr" },
    .{ "ImGui_ItemSizeImRectEx", "itemSizeRect" },
    .{ "ImGuiWindow_GetID", "getIdPtr" },
    .{ "ImGuiWindow_GetIDInt", "getIdInt" },
    .{ "ImGui_ColorConvertRGBtoHSV", "colorConvertRgbToHsv" },
    .{ "ImGui_ColorConvertHSVtoRGB", "colorConvertHsvToRgb" },
    .{ "ImGui_MarkIniSettingsDirty", "markIniSettingsDirtyCurrentWindowPtr" },
    .{ "ImGui_TabItemCalcSize", "tabItemCalcSizeWindowPtr" },
    .{ "ImGui_GetForegroundDrawListImGuiWindowPtr", "getForegroundDrawListWindowPtr" },
    .{ "ImGui_SetWindowPosImGuiWindowPtr", "setWindowPosWindowPtr" },
    .{ "ImGui_SetWindowCollapsedImGuiWindowPtr", "setWindowCollapsedWindowPtr" },
    .{ "ImGui_SetWindowSizeImGuiWindowPtr", "setWindowSizeWindowPtr" },
    .{ "ImGui_SetScrollXImGuiWindowPtr", "setScrollXWindowPtr" },
    .{ "ImGui_SetScrollYImGuiWindowPtr", "setScrollYWindowPtr" },
    .{ "ImGui_SetScrollFromPosXImGuiWindowPtr", "setScrollFromPosXWindowPtr" },
    .{ "ImGui_SetScrollFromPosYImGuiWindowPtr", "setScrollFromPosYWindowPtr" },
    .{ "ImGui_TableGetColumnNameImGuiTablePtr", "tableGetColumnNameTable" },
    .{ "ImGui_IsKeyDownID", "isKeyDownEx" },
    .{ "ImGui_IsKeyReleasedID", "isKeyReleasedEx" },
    .{ "ImGui_ShortcutID", "shortcutEx" },
    .{ "ImGui_IsKeyPressedImGuiInputFlagsEx", "isKeyPressedEx" },
    .{ "ImGui_IsKeyChordPressedImGuiInputFlagsEx", "isKeyChordPressedEx" },
    .{ "ImGui_SetItemKeyOwnerImGuiInputFlags", "setItemKeyOwnerEx" },
    .{ "ImGui_IsMouseClickedImGuiInputFlagsEx", "isMouseClickedEx" },
    .{ "ImGui_IsMouseDownID", "isMouseDownEx" },
    .{ "ImGui_IsMouseReleasedID", "isMouseReleasedEx" },
    .{ "ImGui_IsMouseDoubleClickedID", "isMouseDoubleClickedEx" },
    .{ "ImGui_TreeNodeStrUnformatted", "treeNodeStrIdUnformatted" },
    .{ "ImGui_TreeNodeExStrUnformatted", "treeNodeExStrIdUnformatted" },
});

/// N.B. the name passed in here is what came out of get_fn_name
pub fn get_options_struct_name(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    const final_name = try pascal_or_camel_to_pascal(arena, name);
    return try std.fmt.allocPrint(arena, "{s}Options", .{ final_name });
}

fn pascal_or_camel_to_camel(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    if (name.len == 0) return name;
    if (std.ascii.isLower(name[0])) return name;

    var result = try std.ArrayList(u8).initCapacity(arena, name.len);
    result.appendAssumeCapacity(std.ascii.toLower(name[0]));
    result.appendSliceAssumeCapacity(name[1..]);
    return result.items;
}

fn pascal_or_camel_to_pascal(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    if (name.len == 0) return name;
    if (std.ascii.isUpper(name[0])) return name;

    var result = try std.ArrayList(u8).initCapacity(arena, name.len);
    result.appendAssumeCapacity(std.ascii.toUpper(name[0]));
    result.appendSliceAssumeCapacity(name[1..]);
    return result.items;
}

fn pascal_or_camel_to_lower_snake(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    if (name.len == 0) return name;

    var extra_length: usize = 0;
    if (name.len > 1) {
        for (name[1..]) |c| switch (c) {
            'A'...'Z' => extra_length += 1,
            else => {}
        };
    }

    if (extra_length == 0 and std.ascii.isLower(name[0])) return name;

    var result = try std.ArrayList(u8).initCapacity(arena, name.len + extra_length);
    result.appendAssumeCapacity(std.ascii.toLower(name[0]));
    for (1.., name[1..]) |i, c| switch (c) {
        'A'...'Z' => {
            if (!std.ascii.isUpper(name[i - 1])) {
                result.appendAssumeCapacity('_');
            }
            result.appendAssumeCapacity(std.ascii.toLower(c));
        },
        else => result.appendAssumeCapacity(c),
    };

    return result.items;
}

pub const misc = struct {
    pub const Color_Packed = "ColorPacked";
    pub const Color = "Color";
    pub const Vec2 = "Vec2";
    pub const Vec4 = "Vec4";
    pub const Vector = "Vector";

    pub const to_c = "toC";
    pub const from_c = "fromC";

    pub const C_Type = "CType";
    pub const Flags_Mixin = "FlagsMixin";
    pub const Enum_Mixin = "EnumMixin";
    pub const Struct_Union_Mixin = "StructUnionMixin";
};

const util = @import("util");
const std = @import("std");
