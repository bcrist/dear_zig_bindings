cimgui_name: []const u8,
name: []const u8,
width: u8,
bits: [32]?Bit,
combos: []const Combo,
comments: ?Metadata.Comments,
is_internal: bool,
source_location: ?Metadata.Source_Location,

pub fn init(arena: std.mem.Allocator, meta: Metadata.Enum, is_internal: bool) !Flags_Type {
    var bits: [32]?Bit = .{ null } ** 32;
    var combos = std.ArrayList(Combo).init(arena);

    const name = try naming.get_type_name(arena, meta.name);

    for (meta.elements) |*el| {
        if (el.is_count) continue;
        if (el.is_internal) continue;
        if (!Metadata.check_conditions(el.conditionals)) continue;

        var maybe_comments = el.comments;
        if (maybe_comments) |*comments| {
            if (comments.preceding.len > 0 and (
                std.mem.startsWith(u8, comments.preceding[0], "//ImGuiDockNodeFlags_NoCentralNode              = ")
                or std.mem.startsWith(u8, comments.preceding[0], "//ImGuiTreeNodeFlags_NoScrollOnOpen     = ")
                or std.mem.startsWith(u8, comments.preceding[0], "//ImGuiPopupFlags_NoReopenAlwaysNavInit = ")
                or std.mem.startsWith(u8, comments.preceding[0], "//ImGuiHoveredFlags_AllowWhenBlockedByModal     = ")
                or std.mem.startsWith(u8, comments.preceding[0], "//ImGuiMultiSelectFlags_RangeSelect2d       = ")
            )) {
                comments.preceding = comments.preceding[1..];
            }
        }

        if (@popCount(el.value) == 1) {
            const index = @ctz(el.value);
            if (bits[index] == null) {
                bits[index] = .{
                    .name = try naming.get_field_name(arena, meta.name, el.name),
                    .comments = maybe_comments,
                };
                continue;
            }
        }

        try combos.append(.{
            .name = try naming.get_field_name(arena, meta.name, el.name),
            .value = @intCast(el.value),
            .comments = maybe_comments,
        });
    }

    return .{
        .cimgui_name = meta.name,
        .name = name,
        .width = Metadata.parse_flags_width(meta),
        .bits = bits,
        .combos = combos.items,
        .comments = meta.comments,
        .is_internal = is_internal,
        .source_location = meta.source_location,
    };
}

pub fn write_alias(self: Flags_Type, writer: anytype) !void {
    try writer.print("\nconst {} = ig.{};\n", .{ std.zig.fmtId(self.name), std.zig.fmtId(self.name) });
}

pub fn write(self: Flags_Type, writer: anytype, maybe_base_type: ?*Flags_Type, imgui_path: []const u8) !void {
    try writer.writeByte('\n');
    try Metadata.write_pre_comments(self.comments, writer, .{});

    try writer.print(
        \\pub const {} = packed struct (i{}) {{
        \\
        , .{ std.zig.fmtId(self.name), self.width });

    if (self.source_location) |loc| {
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        try writer.print("    // see {s}:{}\n\n", .{
            try std.fs.path.resolve(fba.allocator(), &.{ imgui_path, loc.filename }),
            loc.line,
        });
    }

    var bits: [32]?Bit = self.bits;

    if (maybe_base_type) |base| {
        for (&bits, base.bits) |*final_bit, base_bit| {
            if (base_bit) |bit| {
                if (final_bit.* == null) {
                    final_bit.* = bit;
                }
            }
        }
    }

    var b: usize = 0;
    while (b < self.width) {
        if (bits[b]) |bit| {
            try Metadata.write_pre_comments(bit.comments, writer, .{ .newline = true, .line_prefix = "    " });
            try writer.print("    {}: bool = false,", .{ std.zig.fmtId(bit.name) });
            try Metadata.write_post_comments(bit.comments, writer, .{});
            b += 1;
        } else {
            var e = b + 1;
            while (e < self.width and bits[e] == null) e += 1;
            try writer.print("    __reserved_{}: u{} = 0,\n", .{ b, e - b });
            b = e;
        }
    }

    if (maybe_base_type) |base| {
        try base.write_combos(bits, writer);
    }

    try self.write_combos(bits, writer);

    if (maybe_base_type) |base| {
        try writer.print("\n    pub const Base = ig.{};\n", .{ std.zig.fmtId(base.name) });
    }

    try writer.writeAll("\n    const mixin = " ++ naming.misc.Flags_Mixin ++ "(@This());\n");

    const Flags_Mixin = @field(util, naming.misc.Flags_Mixin);
    for (@typeInfo(Flags_Mixin(Dummy)).@"struct".decls) |decl| {
        try writer.print("    pub const {} = mixin.{};\n", .{
            std.zig.fmtId(decl.name),
            std.zig.fmtId(decl.name),
        });
    }

    try writer.writeAll("};");
    try Metadata.write_post_comments(self.comments, writer, .{});
}

fn write_combos(self: Flags_Type, bits: [32]?Bit, writer: anytype) !void {
    if (self.combos.len > 0) try writer.writeByte('\n');

    for (self.combos) |combo| {
        try Metadata.write_pre_comments(combo.comments, writer, .{ .newline = true, .line_prefix = "    " });

        const bitset: std.bit_set.IntegerBitSet(32) = .{
            .mask = @intCast(combo.value),
        };

        var write_symbolic = true;
        var iter = bitset.iterator(.{});
        while (iter.next()) |bit| {
            if (bits[bit] == null) write_symbolic = false;
        }

        if (write_symbolic) {
            try writer.print("    pub const {}: {} = .{{", .{ std.zig.fmtId(combo.name), std.zig.fmtId(self.name) });

            var first = true;
            iter = bitset.iterator(.{});
            while (iter.next()) |bit| {
                if (first) {
                    first = false;
                } else {
                    try writer.writeAll(",");
                }

                try writer.print(" .{} = true", .{ std.zig.fmtId(bits[bit].?.name) });
            }

            try writer.writeAll(" };");
        } else {
            try writer.print("    pub const {} = from_c(0x{X});", .{ std.zig.fmtId(combo.name), combo.value });
        }

        try Metadata.write_post_comments(combo.comments, writer, .{});
    }
}

pub const Bit = struct {
    name: []const u8,
    comments: ?Metadata.Comments,
};

pub const Combo = struct {
    name: []const u8,
    value: i32,
    comments: ?Metadata.Comments,
};

const Dummy = packed struct (i32) {
    x: i32 = 0,
};

const Flags_Type = @This();

const util = @import("util");
const Metadata = @import("Metadata.zig");
const naming = @import("naming");
const std = @import("std");
