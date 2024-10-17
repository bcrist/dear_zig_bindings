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
            return "Opaque_Vector(Dock_Request)";
        } else if (std.mem.eql(u8, name, "ImVector_ImGuiDockNodeSettings")) {
            return "Opaque_Vector(Dock_Node_Settings)";
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
            return std.fmt.allocPrint(arena, "Chunk_Stream(*{s})", .{ inner });
        } else {
            const inner = try get_type_name(arena, payload_name);
            return std.fmt.allocPrint(arena, "Chunk_Stream({s})", .{ inner });
        }
    }

    if (std.mem.eql(u8, name, "ImStb_STB_TexteditState")) {
        return "STB_Textedit_State";
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
    return try pascal_or_camel_to_upper_snake(arena, final_name);
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
    final_name = try pascal_or_camel_to_lower_snake(arena, final_name);
    if (options.is_unformatted_helper) {
        final_name = try std.mem.concat(arena, u8, &.{ final_name, "_unformatted" });
    }
    return final_name;
}

const special_case_fns = std.StaticStringMap([]const u8).initComptime(.{
    .{ "ImGui_IsRectVisibleBySize", "is_rect_from_cursor_visible" },
    .{ "ImGui_OpenPopupID", "open_popup_id" },
    .{ "ImGui_IsPopupOpenID", "is_popup_open_id" },
    .{ "ImGui_PlotHistogramCallbackEx", "plot_histogram_callback" },
    .{ "ImGui_PlotLinesCallbackEx", "plot_lines_callback" },
    .{ "ImGui_ListBoxCallbackEx", "list_box_callback" },
    .{ "ImGui_SelectableBoolPtrEx", "selectable_stateful" },
    .{ "ImGui_CollapsingHeaderBoolPtr", "collapsing_header_stateful" },
    .{ "ImGui_TreePushPtr", "tree_push_ptr_id" },
    .{ "ImGui_TreeNodePtrUnformatted", "tree_node_ptr_id_unformatted" },
    .{ "ImGui_TreeNodeExPtrUnformatted", "tree_node_ex_ptr_id_unformatted" },
    .{ "ImGui_GetIDInt", "get_id_int" },
    .{ "ImGui_GetIDPtr", "get_id_ptr" },
    .{ "ImGui_GetIDStr", "get_id" },
    .{ "ImGui_PushIDStr", "push_id" },
    .{ "ImGui_PushIDPtr", "push_id_ptr" },
    .{ "ImGui_PushIDInt", "push_id_int" },
    .{ "ImGui_PushStyleVarImVec2", "push_style_var_vec2" },
    .{ "ImGui_BeginChildID", "begin_child_id" },
    .{ "ImDrawList_AddTextImFontPtrEx", "add_text_font" },
    .{ "ImRect_ExpandImVec2", "expand_vec2" },
    .{ "ImRect_AddImRect", "add_rect" },
    .{ "ImRect_ContainsImRect", "contains_rect" },
    .{ "ImGui_TableGcCompactTransientBuffersImGuiTableTempDataPtr", "table_gc_compact_transient_buffers_temp_data" },
    .{ "ImGui_GetKeyDataImGuiContextPtr", "get_key_data_ctx" },
    .{ "ImGui_GetIDWithSeed", "get_id_with_seed_int" },
    .{ "ImGui_GetIDWithSeedStr", "get_id_with_seed_str" },
    .{ "ImGui_ItemSizeImRectEx", "item_size_rect" },
    .{ "ImGuiWindow_GetID", "get_id_ptr" },
    .{ "ImGuiWindow_GetIDInt", "get_id_int" },
    .{ "ImGui_ColorConvertRGBtoHSV", "color_convert_rgb_to_hsv" },
    .{ "ImGui_ColorConvertHSVtoRGB", "color_convert_hsv_to_rgb" },
    .{ "ImGui_MarkIniSettingsDirty", "mark_ini_settings_dirty_current_window_ptr" },
    .{ "ImGui_TabItemCalcSize", "tab_item_calc_size_window_ptr" },
    .{ "ImGui_GetForegroundDrawListImGuiWindowPtr", "get_foreground_draw_list_window_ptr" },
    .{ "ImGui_SetWindowPosImGuiWindowPtr", "set_window_pos_window_ptr" },
    .{ "ImGui_SetWindowCollapsedImGuiWindowPtr", "set_window_collapsed_window_ptr" },
    .{ "ImGui_SetWindowSizeImGuiWindowPtr", "set_window_size_window_ptr" },
    .{ "ImGui_SetScrollXImGuiWindowPtr", "set_scroll_x_window_ptr" },
    .{ "ImGui_SetScrollYImGuiWindowPtr", "set_scroll_y_window_ptr" },
    .{ "ImGui_SetScrollFromPosXImGuiWindowPtr", "set_scroll_from_pos_x_window_ptr" },
    .{ "ImGui_SetScrollFromPosYImGuiWindowPtr", "set_scroll_from_pos_y_window_ptr" },
    .{ "ImGui_TableGetColumnNameImGuiTablePtr", "table_get_column_name_table" },
    .{ "ImGui_IsKeyDownID", "is_key_down_ex" },
    .{ "ImGui_IsKeyReleasedID", "is_key_released_ex" },
    .{ "ImGui_ShortcutID", "shortcut_ex" },
    .{ "ImGui_IsKeyPressedImGuiInputFlagsEx", "is_key_pressed_ex" },
    .{ "ImGui_IsKeyChordPressedImGuiInputFlagsEx", "is_key_chord_pressed_ex" },
    .{ "ImGui_SetItemKeyOwnerImGuiInputFlags", "set_item_key_owner_ex" },
    .{ "ImGui_IsMouseClickedImGuiInputFlagsEx", "is_mouse_clicked_ex" },
    .{ "ImGui_IsMouseDownID", "is_mouse_down_ex" },
    .{ "ImGui_IsMouseReleasedID", "is_mouse_released_ex" },
    .{ "ImGui_IsMouseDoubleClickedID", "is_mouse_double_clicked_ex" },
    .{ "ImGui_TreeNodeStrUnformatted", "tree_node_str_id_unformatted" },
    .{ "ImGui_TreeNodeExStrUnformatted", "tree_node_ex_str_id_unformatted" },
});

/// N.B. the name passed in here is what came out of get_fn_name
pub fn get_options_struct_name(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    const final_name = try pascal_or_camel_to_upper_snake(arena, name);
    return try std.fmt.allocPrint(arena, "{s}_Options", .{ final_name });
}

fn pascal_or_camel_to_upper_snake(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    if (name.len == 0) return name;

    var extra_length: usize = 0;
    if (name.len > 1) {
        for (name[1..]) |c| switch (c) {
            'A'...'Z' => extra_length += 1,
            else => {}
        };
    }

    if (extra_length == 0 and std.ascii.isUpper(name[0])) return name;

    var result = try std.ArrayList(u8).initCapacity(arena, name.len + extra_length);
    result.appendAssumeCapacity(std.ascii.toUpper(name[0]));
    for (1.., name[1..]) |i, c| switch (c) {
        'A'...'Z' => {
            if (!std.ascii.isUpper(name[i - 1])) {
                result.appendAssumeCapacity('_');
            }
            result.appendAssumeCapacity(c);
        },
        'a'...'z' => {
            if (name[i - 1] == '_') {
                result.appendAssumeCapacity(std.ascii.toUpper(c));
            } else {
                result.appendAssumeCapacity(c);
            }
        },
        else => result.appendAssumeCapacity(c),
    };

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
    pub const Color_Packed = "Color_Packed";
    pub const Color = "Color";
    pub const Vec2 = "Vec2";
    pub const Vec4 = "Vec4";
    pub const Vector = "Vector";

    pub const to_c = "to_c";
    pub const from_c = "from_c";

    pub const C_Type = "C_Type";
    pub const Flags_Mixin = "Flags_Mixin";
    pub const Enum_Mixin = "Enum_Mixin";
    pub const Struct_Union_Mixin = "Struct_Union_Mixin";
};

const util = @import("util");
const std = @import("std");
