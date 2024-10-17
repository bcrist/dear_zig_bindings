cimgui_name: []const u8,
name: []const u8,
zig_type: []const u8,
comments: ?Metadata.Comments,
is_internal: bool,

pub fn init(arena: std.mem.Allocator, meta: Metadata.Typedef, is_internal: bool) !Typedef {
    const name = try naming.get_type_name(arena, meta.name);
    var zig_type = try meta.type.description.?.to_zig_type(arena, .{});

    if (std.mem.eql(u8, meta.name, "ImDrawCallback") and !std.mem.startsWith(u8, zig_type, "?")) {
        zig_type = try std.mem.concat(arena, u8, &.{ "?", zig_type });
    }

    if (std.mem.eql(u8, meta.name, "ImTextureID")) {
        zig_type = "*allowzero anyopaque";
    }

    return .{
        .cimgui_name = meta.name,
        .name = name,
        .zig_type = zig_type,
        .comments = meta.comments,
        .is_internal = is_internal,
    };
}

pub fn write_alias(self: Typedef, writer: anytype) !void {
    try writer.print("const {} = ig.{};\n", .{ std.zig.fmtId(self.name), std.zig.fmtId(self.name) });
}

pub fn write(self: Typedef, writer: anytype) !void {
    try Metadata.write_pre_comments(self.comments, writer, .{ .newline = true });
    try writer.print("pub const {} = {s};", .{ std.zig.fmtId(self.name), self.zig_type });
    try Metadata.write_post_comments(self.comments, writer, .{});
}

const Typedef = @This();

const util = @import("util");
const Metadata = @import("Metadata.zig");
const naming = @import("naming");
const std = @import("std");
