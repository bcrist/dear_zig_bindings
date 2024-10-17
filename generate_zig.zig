pub fn main() !void {
    var gpallocator: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer std.debug.assert(gpallocator.deinit() == .ok);
    const gpa = gpallocator.allocator();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var iter = try std.process.argsWithAllocator(a);
    _ = iter.next(); // ignore executable name/path
    const imgui_path = iter.next() orelse return error.ExpectedImguiPath;
    const cimgui_json_path = iter.next() orelse return error.ExpectedJsonPath;
    const internal_json_path = iter.next() orelse return error.ExpectedJsonPath;
    const output_path = iter.next() orelse return error.ExpectedOutputPath;
    const last = iter.next() orelse "";
    const validate_packed = std.mem.eql(u8, last, "validate-packed");

    try std.fs.cwd().makePath(output_path);

    const meta = try parse_json(a, cimgui_json_path);
    const internal_meta = try parse_json(a, internal_json_path);

    var lookup = Lookup.init(gpa);
    defer lookup.deinit();

    try process_meta(a, gpa, &meta, false, &lookup);
    try process_meta(a, gpa, &internal_meta, true, &lookup);

    const ig_zig_path = try std.fs.path.resolve(a, &.{ output_path, "ig.zig" });
    var f = try std.fs.cwd().createFile(ig_zig_path, .{ .lock = .exclusive });
    defer f.close();
    const w = f.writer();

    try lookup.write(false, validate_packed, imgui_path, w);

    try w.writeAll(
        \\
        \\pub const c = @import("cimgui");
        \\pub const internal = @import("internal.zig");
        \\
        \\
    );

    for (@typeInfo(util).@"struct".decls) |decl| {
        if (std.mem.eql(u8, decl.name, "internal")) continue;
        if (std.mem.eql(u8, decl.name, "structs")) continue;
        try w.print("pub const {} = util.{};\n", .{
            std.zig.fmtId(decl.name),
            std.zig.fmtId(decl.name),
        });
    }

    try w.writeAll(
        \\
        \\const util = @import("util");
        \\const std = @import("std");
        \\
    );

    const internal_zig_path = try std.fs.path.resolve(a, &.{ output_path, "internal.zig" });
    var internal_f = try std.fs.cwd().createFile(internal_zig_path, .{ .lock = .exclusive });
    defer internal_f.close();
    const iw = internal_f.writer();

    try lookup.write(true, validate_packed, imgui_path, iw);

    try iw.writeAll(
        \\
        \\const ig = @import("ig.zig");
        \\pub const c = @import("cimgui_internal");
        \\
    );

    for (@typeInfo(util).@"struct".decls) |decl| {
        if (std.mem.eql(u8, decl.name, "internal")) continue;
        if (std.mem.eql(u8, decl.name, "structs")) continue;
        try iw.print("pub const {} = util.{};\n", .{
            std.zig.fmtId(decl.name),
            std.zig.fmtId(decl.name),
        });
    }
    if (@hasDecl(util, "internal")) for (@typeInfo(util.internal).@"struct".decls) |decl| {
        try iw.print("pub const {} = util.internal.{};\n", .{
            std.zig.fmtId(decl.name),
            std.zig.fmtId(decl.name),
        });
    };

    try iw.writeAll(
        \\
        \\const util = @import("util");
        \\const std = @import("std");
        \\
    );
}

const Lookup = struct {
    version: []const u8,
    typedefs: std.StringArrayHashMap(Typedef),
    enums: std.StringArrayHashMap(Enum_Type),
    flags: std.StringArrayHashMap(Flags_Type),
    structs: std.StringArrayHashMap(Struct_Type),
    free_functions: std.StringArrayHashMap(Function),

    pub fn init(gpa: std.mem.Allocator) Lookup {
        return .{
            .version = "",
            .typedefs = .init(gpa),
            .enums = .init(gpa),
            .flags = .init(gpa),
            .structs = .init(gpa),
            .free_functions = .init(gpa),
        };
    }

    pub fn deinit(self: *Lookup) void {
        for (self.structs.values()) |*t| {
            t.functions.deinit();
        }
        self.typedefs.deinit();
        self.enums.deinit();
        self.flags.deinit();
        self.structs.deinit();
        self.free_functions.deinit();
    }

    pub fn write(self: *Lookup, internal: bool, validate_packed: bool, imgui_path: []const u8, writer: anytype) !void {
        try writer.print("pub const version_str = {s};\n", .{ self.version });

        for (self.free_functions.values()) |t| {
            if (internal or !t.is_internal) {
                try t.write(writer, "", imgui_path);
            }
        }

        for (self.structs.keys(), self.structs.values()) |k, t| {
            if (k.len != t.cimgui_name.len) continue;
            if (std.meta.stringToEnum(Metadata.Builtin_Names, t.cimgui_name) != null) continue;

            if (t.is_internal == internal) {
                try t.write(writer, validate_packed, imgui_path);
            } else if (internal) {
                try t.write_alias(writer);
            } else {
                try t.write_opaque(writer);
            }
        }

        for (self.flags.keys(), self.flags.values()) |k, t| {
            if (k.len != t.cimgui_name.len) continue;
            if (t.is_internal == internal) {
                if (std.mem.endsWith(u8, t.cimgui_name, "Private_")) {
                    const base_name = t.cimgui_name[0 .. t.cimgui_name.len - "Private_".len];
                    if (self.flags.getPtr(base_name)) |base| {
                        try t.write(writer, base, imgui_path);
                        continue;
                    }
                }
                try t.write(writer, null, imgui_path);
            } else if (internal) {
                var buf: [256]u8 = undefined;
                var base_name = t.cimgui_name;
                if (std.mem.endsWith(u8, base_name, "_")) base_name = base_name[0 .. base_name.len - 1];
                const private_name = try std.fmt.bufPrint(&buf, "{s}Private_", .{ base_name });
                if (self.flags.get(private_name) == null) {
                    try t.write_alias(writer);
                }
            }
        }

        for (self.enums.keys(), self.enums.values()) |k, t| {
            if (k.len != t.cimgui_name.len) continue;
            if (t.is_internal == internal) {
                if (std.mem.endsWith(u8, t.cimgui_name, "Private_")) {
                    const base_name = t.cimgui_name[0 .. t.cimgui_name.len - "Private_".len];
                    if (self.enums.getPtr(base_name)) |base| {
                        try t.write(writer, base, imgui_path);
                        continue;
                    }
                }
                try t.write(writer, null, imgui_path);
            } else if (internal) {
                var buf: [256]u8 = undefined;
                var base_name = t.cimgui_name;
                if (std.mem.endsWith(u8, base_name, "_")) base_name = base_name[0 .. base_name.len - 1];
                const private_name = try std.fmt.bufPrint(&buf, "{s}Private_", .{ base_name });
                if (self.enums.get(private_name) == null) {
                    try t.write_alias(writer);
                }
            }
        }

        for (self.typedefs.values()) |t| {
            if (self.enums.get(t.cimgui_name) != null) continue;
            if (self.flags.get(t.cimgui_name) != null) continue;
            if (self.structs.get(t.cimgui_name) != null) continue;
            if (std.meta.stringToEnum(Metadata.Builtin_Names, t.cimgui_name) != null) continue;

            if (t.is_internal == internal) {
                try t.write(writer);
            } else if (internal) {
                try t.write_alias(writer);
            }
        }
    }
};

fn process_meta(arena: std.mem.Allocator, gpa: std.mem.Allocator, meta: *const Metadata, is_internal: bool, lookup: *Lookup) !void {
    for (meta.defines) |m| {
        if (std.mem.eql(u8, m.name, "IMGUI_VERSION")) {
            lookup.version = m.content;
            break;
        }
    }

    for (meta.typedefs) |m| {
        if (!Metadata.check_conditions(m.conditionals)) continue;
        if (m.type.description == null) continue;

        const t = try Typedef.init(arena, m, is_internal);

        const result = try lookup.typedefs.getOrPut(t.name);
        if (!result.found_existing) {
            result.key_ptr.* = t.name;
            result.value_ptr.* = t;
        }
    }

    for (meta.enums) |m| {
        if (!Metadata.check_conditions(m.conditionals)) continue;

        if (m.is_flags_enum or std.mem.endsWith(u8, m.name, "FlagsPrivate_")) {
            const t = try Flags_Type.init(arena, m, is_internal);

            const result = try lookup.flags.getOrPut(m.name);
            if (!result.found_existing) {
                result.key_ptr.* = m.name;
                result.value_ptr.* = t;
            }

            if (std.mem.endsWith(u8, m.name, "_")) {
                const base_name = m.name[0 .. m.name.len - 1];
                const result2 = try lookup.flags.getOrPut(base_name);
                if (!result2.found_existing) {
                    result2.key_ptr.* = base_name;
                    result2.value_ptr.* = t;
                }
            }
        } else {
            const t = try Enum_Type.init(arena, m, is_internal);

            const result = try lookup.enums.getOrPut(m.name);
            if (!result.found_existing) {
                result.key_ptr.* = m.name;
                result.value_ptr.* = t;
            }

            if (std.mem.endsWith(u8, m.name, "_")) {
                const base_name = m.name[0 .. m.name.len - 1];
                const result2 = try lookup.enums.getOrPut(base_name);
                if (!result2.found_existing) {
                    result2.key_ptr.* = base_name;
                    result2.value_ptr.* = t;
                }
            }
        }
    }

    for (meta.structs) |m| {
        if (!Metadata.check_conditions(m.conditionals)) continue;
        if (std.mem.startsWith(u8, m.name, "ImVector_")) continue;
        if (std.mem.startsWith(u8, m.name, "ImPool_")) continue;
        if (std.mem.startsWith(u8, m.name, "ImSpan_")) continue;
        if (std.mem.startsWith(u8, m.name, "ImChunkStream_")) continue;

        var t = try Struct_Type.init(arena, gpa, m, is_internal);

        const result = try lookup.structs.getOrPut(m.name);
        if (!result.found_existing or result.value_ptr.is_opaque and !t.is_opaque) {
            result.key_ptr.* = m.name;
            result.value_ptr.* = t;
        } else {
            t.functions.deinit();
        }
    }

    for (meta.functions) |m| {
        if (m.is_default_argument_helper) continue;
        if (!Metadata.check_conditions(m.conditionals)) continue;
        if (std.mem.startsWith(u8, m.name, "ImVector_")) continue;
        if (std.mem.startsWith(u8, m.name, "ImPool_")) continue;
        if (std.mem.startsWith(u8, m.name, "ImSpan_")) continue;
        if (std.mem.startsWith(u8, m.name, "ImChunkStream_")) continue;
        if (std.meta.stringToEnum(Ignored_Functions, m.name) != null) continue;

        const t = Function.init(arena, m, is_internal) catch |err| switch (err) {
            error.SkipFunction => continue,
            else => return err,
        };

        if (std.mem.indexOfScalar(u8, m.name, '_')) |i| {
            const class = m.name[0..i];
            if (lookup.structs.getPtr(class)) |s| {
                const result = try s.functions.getOrPut(m.name);
                if (!result.found_existing) {
                    result.key_ptr.* = m.name;
                    result.value_ptr.* = t;
                } else if (result.value_ptr.is_internal == is_internal) {
                    log.warn("Ignoring duplicate method name: {s}.{s}", .{ s.name, m.name });
                }
            } else {
                const result = try lookup.free_functions.getOrPut(m.name);
                if (!result.found_existing) {
                    result.key_ptr.* = m.name;
                    result.value_ptr.* = t;
                } else if (result.value_ptr.is_internal == is_internal) {
                    log.warn("Ignoring duplicate free function name: {s}", .{ m.name });
                }
            }
        }
    }
}

fn parse_json(arena: std.mem.Allocator, path: []const u8) !Metadata {
    const stat = try std.fs.cwd().statFile(path);
    const contents = try std.fs.cwd().readFileAllocOptions(arena, path, 1_000_000_000, stat.size, 1, null);
    return try std.json.parseFromSliceLeaky(Metadata, arena, contents, .{});
}

const Ignored_Functions = enum {
    // redefined in util:
    ImGui_ComboEx,
    ImGui_ComboCharEx,
    ImGui_ComboCallbackEx,
    ImGui_RadioButtonIntPtr,
    ImGui_Checkbox,
    ImGui_CheckboxFlagsIntPtr,
    ImGui_CheckboxFlagsUintPtr,
    ImGui_CheckboxFlagsImS64Ptr,
    ImGui_CheckboxFlagsImU64Ptr,
    ImGui_GetColorU32Ex,
    ImGui_GetColorU32ImVec4,
    ImGui_GetColorU32ImU32Ex,
    ImGui_GetStyleColorVec4,
    ImGui_PushStyleColor,
    ImGui_PushStyleColorImVec4,
    ImGui_MenuItemBoolPtr,
    ImGui_TextColoredUnformatted,
    ImGui_TextDisabledUnformatted,
    ImGui_TextWrappedUnformatted,
    ImGui_LabelTextUnformatted,
    ImGui_BulletTextUnformatted,
    ImGui_SeparatorText,
    ImGui_ListBox,
    ImGui_ListBoxCallbackEx,
    ImFontAtlas_AddFontFromMemoryTTF,
    ImFontAtlas_GetTexDataAsRGBA32,
    ImFontAtlas_GetTexDataAsAlpha8,
    ImGui_BeginCombo,

    ImGui_SetWindowPos, // Not recommended
    ImGui_SetWindowCollapsed, // not recommended
    ImGui_SetWindowFocus, // not recommended
    ImGui_SetWindowSize, // not recommended
    ImGui_SetWindowFontScale, // obsolete
    ImGui_GetID, // GetIDStr works fine
    ImGui_PushID, // PushIDStr works fine
};

const log = std.log.scoped(.generate_zig);

const Function = @import("generate_zig/Function.zig");
const Typedef = @import("generate_zig/Typedef.zig");
const Struct_Type = @import("generate_zig/Struct_Type.zig");
const Enum_Type = @import("generate_zig/Enum_Type.zig");
const Flags_Type = @import("generate_zig/Flags_Type.zig");
const Metadata = @import("generate_zig/Metadata.zig");
const naming = @import("naming");
const util = @import("util");
const std = @import("std");
