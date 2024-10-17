pub const ID = u32;

pub fn check_version() void {
    if (!c.ImGui_DebugCheckVersionAndDataLayout(
        ig.version_str,
        @sizeOf(ig.internal.IO),
        @sizeOf(ig.Style),
        @sizeOf(ig.Vec2),
        @sizeOf(ig.Vec4),
        @sizeOf(ig.Draw_Vert),
        @sizeOf(ig.Draw_Idx),
    )) {
        @panic("ImGui version doesn't match bindings!");
    }
    if (ig.internal.c.GetImFontGlyphSize() != @sizeOf(ig.Font_Glyph)) {
        std.debug.panic("Struct size mismatch: sizeof(ImFontGlyph) == {}, @sizeOf(ig.Font_Glyph) == {}", .{
            ig.internal.c.GetImFontGlyphSize(),
            @sizeOf(ig.Font_Glyph),
        });
    }
    if (ig.internal.c.GetImGuiContextSize() != @sizeOf(ig.internal.Context)) {
        std.debug.panic("Struct size mismatch: sizeof(ImGuiContext) == {}, @sizeOf(ig.internal.Context) == {}", .{
            ig.internal.c.GetImGuiContextSize(),
            @sizeOf(ig.internal.Context),
        });
    }
    if (ig.internal.c.GetImGuiContextTempBufferOffset() != @offsetOf(ig.internal.Context, "temp_buffer")) {
        std.debug.panic("Struct size mismatch: offsetof(ImGuiContext, TempBuffer) == {}, @offsetOf(ig.internal.Context, \"temp_buffer\") == {}", .{
            ig.internal.c.GetImGuiContextTempBufferOffset(),
            @offsetOf(ig.internal.Context, "temp_buffer"),
        });
    }
    if (ig.internal.c.GetImGuiWindowSize() != @sizeOf(ig.internal.Window)) {
        std.debug.panic("Struct size mismatch: sizeof(ImGuiWindow) == {}, @sizeOf(ig.internal.Window) == {}", .{
            ig.internal.c.GetImGuiWindowSize(),
            @sizeOf(ig.internal.Window),
        });
    }
    if (ig.internal.c.GetImGuiStackLevelInfoSize() != @sizeOf(ig.internal.Stack_Level_Info)) {
        std.debug.panic("Struct size mismatch: sizeof(ImGuiStackLevelInfo) == {}, @sizeOf(ig.internal.Stack_Level_Info) == {}", .{
            ig.internal.c.GetImGuiStackLevelInfoSize(),
            @sizeOf(ig.internal.Stack_Level_Info),
        });
    }
    if (ig.internal.c.GetImGuiDockNodeSize() != @sizeOf(ig.internal.Dock_Node)) {
        std.debug.panic("Struct size mismatch: sizeof(ImGuiDockNode) == {}, @sizeOf(ig.internal.Dock_Node) == {}", .{
            ig.internal.c.GetImGuiDockNodeSize(),
            @sizeOf(ig.internal.Dock_Node),
        });
    }
    if (ig.internal.c.GetImGuiBoxSelectStateSize() != @sizeOf(ig.internal.Box_Select_State)) {
        std.debug.panic("Struct size mismatch: sizeof(ImGuiBoxSelectState) == {}, @sizeOf(ig.internal.Box_Select_State) == {}", .{
            ig.internal.c.GetImGuiBoxSelectStateSize(),
            @sizeOf(ig.internal.Box_Select_State),
        });
    }
    if (ig.internal.c.GetImGuiTableColumnSize() != @sizeOf(ig.internal.Table_Column)) {
        std.debug.panic("Struct size mismatch: sizeof(ImGuiTableColumn) == {}, @sizeOf(ig.internal.Table_Column) == {}", .{
            ig.internal.c.GetImGuiTableColumnSize(),
            @sizeOf(ig.internal.Table_Column),
        });
    }
    if (ig.internal.c.GetImGuiTableSize() != @sizeOf(ig.internal.Table)) {
        std.debug.panic("Struct size mismatch: sizeof(ImGuiTable) == {}, @sizeOf(ig.internal.Table) == {}", .{
            ig.internal.c.GetImGuiTableSize(),
            @sizeOf(ig.internal.Table),
        });
    }
    if (ig.internal.c.GetImGuiTableTempDataSize() != @sizeOf(ig.internal.Table_Temp_Data)) {
        std.debug.panic("Struct size mismatch: sizeof(ImGuiTableTempData) == {}, @sizeOf(ig.internal.Table_Temp_Data) == {}", .{
            ig.internal.c.GetImGuiTableTempDataSize(),
            @sizeOf(ig.internal.Table_Temp_Data),
        });
    }
}

pub fn Flags_Mixin(comptime Flag: type) type {
    return struct {
        pub const C_Type = @typeInfo(Flag).@"struct".backing_integer.?;

        pub inline fn to_c(self: Flag) C_Type {
            return @bitCast(self);
        }
        pub inline fn from_c(value: C_Type) Flag {
            return @bitCast(value);
        }
        pub inline fn with(a: Flag, b: Flag) Flag {
            return from_c(to_c(a) | to_c(b));
        }
        pub inline fn only(a: Flag, b: Flag) Flag {
            return from_c(to_c(a) & to_c(b));
        }
        pub inline fn without(a: Flag, b: Flag) Flag {
            return from_c(to_c(a) & ~to_c(b));
        }
        pub inline fn has_all_set(a: Flag, b: Flag) bool {
            return (to_c(a) & to_c(b)) == to_c(b);
        }
        pub inline fn has_any_set(a: Flag, b: Flag) bool {
            return (to_c(a) & to_c(b)) != 0;
        }
        pub inline fn is_empty(a: Flag) bool {
            return to_c(a) == 0;
        }
        pub inline fn eql(a: Flag, b: Flag) bool {
            return to_c(a) == to_c(b);
        }
    };
}

pub fn Enum_Mixin(comptime Enum: type) type {
    return struct {
        pub const C_Type = @typeInfo(Enum).@"enum".tag_type;

        pub inline fn to_c(self: Enum) C_Type {
            return @intFromEnum(self);
        }

        pub inline fn from_c(value: C_Type) Enum {
            return @enumFromInt(value);
        }
    };
}

pub fn Struct_Union_Mixin(comptime T: type) type {
    return struct {
        pub inline fn init() T {
            return std.mem.zeroes(T);
        }

        pub inline fn to_c(self: T) T.C_Type {
            return @bitCast(self);
        }

        pub inline fn from_c(value: T.C_Type) T {
            return @bitCast(value);
        }
    };
}

pub fn init(comptime T: type) T {
    if (@hasDecl(T, "init")) {
        return .init();
    }
    return .{};
}

pub fn deinit(comptime T: type, ptr: *T) void {
    if (@hasDecl(T, "deinit")) {
        ptr.deinit();
    }
}

pub fn eql(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    if (@hasDecl(T, "eql")) {
        return a.eql(b);
    }
    return std.meta.eql(a, b);
}

pub fn Vector(comptime T: type) type {
    if (@typeInfo(T) == .@"opaque") @compileError("Vector of opaque type is not allowed; use Opaque_Vector(" ++ @typeName(T) ++ ") instead");
    return extern struct {
        size: u32 = 0,
        capacity: u32 = 0,
        data: ?[*]T = null,

        const Self = @This();

        // Constructors, destructor
        pub fn deinit(self: *Self) void {
            if (self.data) |d| c.ImGui_MemFree(@ptrCast(d));
            self.* = undefined;
        }

        pub fn clone(self: Self) Self {
            var cloned: Self = .{};
            if (self.size != 0) {
                cloned.resize_undefined(self.size);
                @memcpy(cloned.data.?, self.data.?[0..self.size]);
            }
            return cloned;
        }

        pub fn copy(self: *Self, other: Self) void {
            self.size = 0;
            if (other.size != 0) {
                self.resize_undefined(other.size);
                @memcpy(self.data.?, other.data.?[0..other.size]);
            }
        }

        pub fn from_slice(slice: []const T) Self {
            var result: Self = .{};
            if (slice.len != 0) {
                result.resize_undefined(@intCast(slice.len));
                @memcpy(result.data.?, slice);
            }
            return result;
        }

        /// Important: does not destruct anything
        pub fn clear(self: *Self) void {
            if (self.data) |d| c.ImGui_MemFree(@ptrCast(d));
            self.* = .{};
        }

        /// Destruct and delete all pointer values, then clear the array.
        /// T must be a pointer or optional pointer.
        pub fn clear_delete(self: *Self) void {
            comptime var ti = @typeInfo(T);
            const is_optional = (ti == .Optional);
            if (is_optional) ti = @typeInfo(ti.Optional.child);
            if (ti != .Pointer or ti.Pointer.is_const or ti.Pointer.size != .One)
                @compileError("clear_delete() can only be called on vectors of mutable single-item pointers, cannot apply to Vector(" ++ @typeName(T) ++ ").");
            const ValueT = ti.Pointer.child;

            if (is_optional) {
                for (self.items()) |it| {
                    if (it) |_ptr| {
                        const ptr: *ValueT = _ptr;
                        util.deinit(ValueT, ptr);
                        c.ImGui_MemFree(ptr);
                    }
                }
            } else {
                for (self.items()) |_ptr| {
                    const ptr: *ValueT = _ptr;
                    util.deinit(ValueT, ptr);
                    c.ImGui_MemFree(@ptrCast(ptr));
                }
            }
            self.clear();
        }

        pub fn clear_destruct(self: *Self) void {
            for (self.items()) |*ptr| {
                util.deinit(T, ptr);
            }
            self.clear();
        }

        pub fn empty(self: Self) bool {
            return self.size == 0;
        }

        pub fn size_in_bytes(self: Self) u32 {
            return self.size * @sizeOf(T);
        }

        pub fn max_size(self: Self) u32 {
            _ = self;
            return 0x7FFFFFFF / @sizeOf(T);
        }

        pub fn items(self: *Self) []T {
            return if (self.size == 0) &.{} else self.data.?[0..self.size];
        }

        pub fn buffer(self: *Self) []T {
            return if (self.capacity == 0) &.{} else self.data.?[0..self.capacity];
        }

        pub fn _grow_capacity(self: Self, sz: u32) u32 {
            const new_cap: u32 = if (self.capacity == 0) 8 else (self.capacity + self.capacity / 2);
            return if (new_cap > sz) new_cap else sz;
        }

        pub fn resize_undefined(self: *Self, new_size: u32) void {
            if (new_size > self.capacity) {
                self.reserve(self._grow_capacity(new_size));
            }
            self.size = new_size;
        }
        pub fn resize_splat(self: *Self, new_size: u32, value: T) void {
            if (new_size > self.capacity) {
                self.reserve(self._grow_capacity(new_size));
            }
            if (new_size > self.size) {
                @memset(self.data.?[self.size..new_size], value);
            }
            self.size = new_size;
        }
        /// Resize a vector to a smaller size, guaranteed not to cause a reallocation
        pub fn shrink(self: *Self, new_size: u32) void {
            std.debug.assert(new_size <= self.size);
            self.size = new_size;
        }
        pub fn reserve(self: *Self, new_capacity: u32) void {
            if (new_capacity <= self.capacity) return;
            const new_data: ?[*]T = @alignCast(@ptrCast(c.ImGui_MemAlloc(new_capacity * @sizeOf(T))));
            if (self.data) |sd| {
                if (self.size != 0) {
                    @memcpy(new_data.?, sd[0..self.size]);
                }
                c.ImGui_MemFree(@ptrCast(sd));
            }
            self.data = new_data;
            self.capacity = new_capacity;
        }
        pub fn reserve_discard(self: *Self, new_capacity: u32) void {
            if (new_capacity <= self.capacity) return;
            if (self.data) |sd| c.ImGui_MemFree(@ptrCast(sd));
            self.data = @alignCast(@ptrCast(c.ImGui_MemAlloc(new_capacity * @sizeOf(T))));
            self.capacity = new_capacity;
        }

        // NB: It is illegal to call push_back/push_front/insert with a reference pointing inside the ImVector data itself! e.g. v.push_back(v.items()[10]) is forbidden.
        pub fn push_back(self: *Self, v: T) void {
            if (self.size == self.capacity) {
                self.reserve(self._grow_capacity(self.size + 1));
            }
            self.data.?[self.Size] = v;
            self.size += 1;
        }
        pub fn pop_back(self: *Self) void {
            self.size -= 1;
        }
        pub fn push_front(self: *Self, v: T) void {
            if (self.size == 0) self.push_back(v) else self.insert(0, v);
        }
        pub fn erase(self: *Self, index: u32) void {
            std.debug.assert(index < self.size);
            self.size -= 1;
            const len = self.size;
            if (index < len) {
                var it = index;
                const data = self.data.?;
                while (it < len) : (it += 1) {
                    data[it] = data[it + 1];
                }
            }
        }
        pub fn erase_range(self: *Self, start_index: u32, end_index: u32) void {
            std.debug.assert(start_index <= end_index);
            std.debug.assert(end_index <= self.size);
            if (start_index == end_index) return;
            const len = self.Size;
            self.size -= (end_index - start_index);
            if (end_index < len) {
                var it = start_index;
                var end_it = end_index;
                const data = self.data.?;
                while (end_it < len) : ({
                    it += 1;
                    end_it += 1;
                }) {
                    data[it] = data[end_it];
                }
            }
        }
        pub fn erase_unsorted(self: *Self, index: u32) void {
            std.debug.assert(index < self.size);
            self.size -= 1;
            if (index != self.Size) {
                self.data.?[index] = self.data.?[self.Size];
            }
        }
        pub fn insert(self: *Self, index: u32, v: T) void {
            std.debug.assert(index <= self.size);
            if (self.size == self.capacity) {
                self.reserve(self._grow_capacity(self.Size + 1));
            }
            const data = self.data.?;
            if (index < self.size) {
                var it = self.size;
                while (it > index) : (it -= 1) {
                    data[it] = data[it - 1];
                }
            }
            data[index] = v;
            self.size += 1;
        }
        pub fn contains(self: Self, v: T) bool {
            for (self.items()) |*it| {
                if (util.eql(T, v, it.*)) return true;
            }
            return false;
        }
        pub fn find(self: Self, v: T) ?u32 {
            for (self.items(), 0..) |*it, i| {
                if (util.eql(T, v, it.*)) return @intCast(i);
            }
            return null;
        }
        pub fn find_erase(self: *Self, v: T) bool {
            if (self.find(v)) |idx| {
                self.erase(idx);
                return true;
            }
            return false;
        }
        pub fn find_erase_unsorted(self: *Self, v: T) bool {
            if (self.find(v)) |idx| {
                self.erase_unsorted(idx);
                return true;
            }
            return false;
        }

        pub fn eql(self: Self, other: Self) bool {
            if (self.size != other.size) return false;
            for (self.items(), other.items()) |s, o| {
                if (!util.eql(T, s, o)) return false;
            }
            return true;
        }
    };
}

pub fn Opaque_Vector(comptime T: type) type {
    return extern struct {
        size: u32 = 0,
        capacity: u32 = 0,
        data: ?*T = null,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            if (self.data) |d| c.ImGui_MemFree(@ptrCast(d));
            self.* = undefined;
        }
    };
}

pub fn Pool(comptime T: type) type {
    return extern struct {
        buf: Vector(T) = .{}, // Contiguous data
        map: ig.internal.Storage = .init(), // ID->Index
        free_idx: Idx = 0, // Next free idx to use
        alive_count: Idx = 0, // Number of active/alive items (for display purpose)

        pub const Idx = ig.internal.Pool_Idx;

        const Self = @This();

        pub fn deinit(self: *Self) void {
            self.clear();
        }

        pub fn get_by_key(self: *Self, key: ig.ID) ?*T {
            const idx = self.map.get_int(key, .{ .default_val = -1 });
            return if (idx != -1) &self.buf[idx] else null;
        }

        pub fn get_by_index(self: *Self, n: Idx) *T {
            return &self.buf[n];
        }

        pub fn get_index(self: Self, ptr: *const T) Idx {
            const many_ptr: [*]const T = @ptrCast(ptr);
            const idx = many_ptr - self.buf.data.?;
            std.debug.assert(idx >= 0 and idx < self.buf.size);
            return @intCast(idx);
        }

        pub fn get_or_add_by_key(self: *Self, key: ig.ID) *T {
            const p_idx = self.map.get_int_ref(key, .{ .default_val = -1 });
            if (p_idx.* != -1) return &self.buf[*p_idx];
            p_idx.* = self.free_idx;
            return self.add();
        }

        pub fn contains(self: Self, ptr: *const T) bool {
            const ptr_int = @intFromPtr(ptr);
            const begin = @intFromPtr(self.buf.data);
            const end = @intFromPtr(self.buf.data + self.buf.size);
            return ptr_int >= begin and ptr_int < end;
        }

        pub fn clear(self: *Self) void {
            for (self.map.data) |storage_pair| {
                const idx = storage_pair.__anonymous_type0.val_i;
                if (idx != -1) {
                    util.deinit(T, &self.buf[idx]);
                }
            }
            self.map.clear();
            self.buf.clear();
            self.free_idx = 0;
            self.alive_count = 0;
        }

        pub fn add(self: *Self) *T {
            const idx = self.free_idx;
            if (idx == self.buf.size) {
                self.buf.resize(self.buf.size + 1);
                self.free_idx = idx + 1;
            } else {
                @memcpy(&self.free_idx, @as(*anyopaque, &self.buf[idx]));
            }
            self.buf[idx] = util.init(T);
            self.alive_count += 1;
            return &self.buf[idx];
        }

        pub fn remove_ptr(self: *Self, key: ig.ID, ptr: *const T) void {
            self.remove_idx(key, self.get_index(ptr));
        }

        pub fn remove_idx(self: *Self, key: ig.ID, idx: Idx) void {
            util.deinit(T, &self.buf[idx]);
            @memcpy(@as(*anyopaque, &self.buf[idx]), &self.free_idx);
            self.free_idx = idx;
            self.map.set_int(key, -1);
            self.alive_count -= 1;
        }

        pub fn reserve(self: *Self, capacity: i32) void {
            self.buf.reserve(capacity);
            self.map.data.reserve(capacity);
        }

        pub fn get_alive_count(self: Self) i32 {
            return self.alive_count;
        }

        pub fn get_buf_size(self: Self) i32 {
            return self.buf.size;
        }

        pub fn get_map_size(self: Self) i32 {
            return self.map.data.size;
        }

        pub fn try_get_map_data(self: *Self, n: Idx) ?*T {
            const idx = self.map.data[n].__anonymous_type0.val_i;
            if (idx == -1) return null;
            return self.get_by_index(idx);
        }
    };
}

pub fn Span(comptime T: type) type {
    return extern struct {
        data: ?[*]T = null,
        data_end: ?[*]T = null,

        const Self = @This();

        pub inline fn init_slice(slice: []T) Self {
            return .{
                .data = slice.ptr,
                .data_end = slice.ptr + slice.len,
            };
        }

        pub inline fn init_ptr_len(ptr: [*]T, len: i32) Self {
            std.debug.assert(len >= 0);
            return .{
                .data = ptr,
                .data_end = ptr + len,
            };
        }

        pub inline fn set_slice(self: *Self, slice: []T) void {
            self.data = slice.ptr;
            self.data_end = slice.ptr + slice.len;
        }

        pub inline fn set_ptr_len(self: *Self, ptr: [*]T, len: i32) void {
            std.debug.assert(len >= 0);
            self.data = ptr;
            self.data_end = ptr + len;
        }

        pub inline fn set_ptr_end(self: *Self, ptr: [*]T, end: [*]T) void {
            std.debug.assert(@intFromPtr(ptr) <= @intFromPtr(end));
            self.data = ptr;
            self.data_end = end;
        }

        pub inline fn size(self: Self) i32 {
            if (self.data == null or self.data_end == null) return 0;
            return @intCast(self.data_end.? - self.data.?);
        }

        pub inline fn size_in_bytes(self: Self) i32 {
            return self.size() * @sizeOf(T);
        }

        pub inline fn get_ptr(self: *Self, index: i32) *T {
            std.debug.assert(index >= 0);
            std.debug.assert(self.data + index < self.data_end);
            return &self.data[index];
        }

        pub inline fn get(self: Self, index: i32) T {
            std.debug.assert(index >= 0);
            std.debug.assert(self.data + index < self.data_end);
            return self.data[index];
        }

        pub inline fn index_from_ptr(self: Self, ptr: *const T) i32 {
            const ptr_many: [*]const T = ptr;
            std.debug.assert(ptr_many >= self.data and ptr_many < self.data_end);
            return @intCast(ptr_many - self.data);
        }

        pub inline fn maybe_index_from_ptr(self: Self, ptr: *const T) ?i32 {
            const ptr_many: [*]const T = ptr;
            if (ptr_many >= self.data and ptr_many < self.data_end) {
                return @intCast(ptr_many - self.data);
            } else return null;
        }
    };
}

pub fn Chunk_Stream(comptime T: type) type {
    return extern struct {
        buf: Vector(u8) = .{},

        const Self = @This();
        comptime {
            std.debug.assert(@alignOf(T) <= 4);
        }

        const Chunk_Start = struct {
            chunk_size: u32,
            first: T,
        };

        pub fn deinit(self: *Self) void {
            self.clear();
        }

        pub fn clear(self: *Self) void {
            self.buf.clear();
        }

        pub fn empty(self: Self) bool {
            return self.buf.empty();
        }

        pub fn size(self: Self) u32 {
            return self.buf.size;
        }

        pub fn alloc_chunk(self: *Self, size_in_bytes: u32) *T {
            const alloc_size = std.mem.alignForward(u32, size_in_bytes + 4, 4);
            const offset = self.buf.size;
            self.buf.resize_undefined(offset + alloc_size);
            const initial: *Chunk_Start = @ptrCast(self.buf.data.? + offset);
            initial.chunk_size = alloc_size;
            return &initial.first;
        }

        pub fn begin(self: *Self) ?*T {
            if (self.buf.data == null or self.buf.size == 0) return null;
            const initial: *Chunk_Start = @ptrCast(self.buf.data.?);
            return &initial.first;
        }

        pub fn next_chunk(self: *Self, ptr: *T) ?*T {
            if (self.begin()) |b| {
                const ptr_many: [*]T = ptr;
                std.debug.assert(ptr_many >= b and ptr_many < self.end());
                const initial: *Chunk_Start = @fieldParentPtr("first", ptr);
                const first: [*]T = @ptrCast(&initial.first);
                return first + initial.chunk_size / @sizeOf(T);
            } else return null;
        }

        pub fn chunk_size(ptr: *const T) u32 {
            const initial: *Chunk_Start = @fieldParentPtr("first", ptr);
            return initial.chunk_size;
        }

        pub fn end(self: Self) *T {
            return @ptrCast(self.buf.data + self.buf.size);
        }

        pub fn offset_from_ptr(self: Self, ptr: *const T) u32 {
            const ptr_many: [*]T = ptr;
            std.debug.assert(ptr_many >= begin().? and ptr_many < end());
            const ptr_u8: [*]const u8 = @ptrCast(ptr);
            return @intCast(ptr_u8 - self.buf.data.?);
        }

        pub fn ptr_from_offset(self: Self, offset: u32) *T {
            std.debug.assert(offset >= 4 and offset < self.buf.size);
            return @ptrCast(self.buf.data.? + offset);
        }
    };
}

pub const Vec2 = extern struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn eql(self: Vec2, other: Vec2) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn to_c(self: Vec2) C_Type {
        return @bitCast(self);
    }

    pub fn from_c(self: C_Type) Vec2 {
        return @bitCast(self);
    }

    pub const C_Type = c.ImVec2;

    pub const zeroes: Vec2 = .{ .x = 0, .y = 0 };
    pub const ones: Vec2 = .{ .x = 1, .y = 1 };
};

pub const Vec4 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 0,

    pub fn init(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn eql(self: Vec4, other: Vec4) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z and self.w == other.w;
    }

    pub fn to_c(self: Vec2) C_Type {
        return @bitCast(self);
    }

    pub fn from_c(self: C_Type) Vec2 {
        return @bitCast(self);
    }

    pub const C_Type = c.ImVec4;

    pub const zeroes: Vec4 = .{ .x = 0, .y = 0, .z = 0, .w = 0 };
    pub const ones: Vec4 = .{ .x = 1, .y = 1, .z = 1, .w = 1 };
};

pub const Color_Packed = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub inline fn init_packed(p: C_Type) Color_Packed {
        return @bitCast(p);
    }

    pub inline fn init_rgba(r: u8, g: u8, b: u8, a: u8) Color_Packed {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub inline fn init_rgb(r: u8, g: u8, b: u8) Color_Packed {
        return init_rgba(r, g, b, 255);
    }

    pub inline fn init_rgba_f32(r: f32, g: f32, b: f32, a: f32) Color_Packed {
        return .{
            .r = @intFromFloat(r * 255),
            .g = @intFromFloat(g * 255),
            .b = @intFromFloat(b * 255),
            .a = @intFromFloat(a * 255),
        };
    }

    pub inline fn init_rgb_f32(r: f32, g: f32, b: f32) Color_Packed {
        return init_rgba_f32(r, g, b, 1);
    }

    pub inline fn init_hsva_f32(h: f32, s: f32, v: f32, a: f32) Color_Packed {
        var r: f32 = undefined;
        var g: f32 = undefined;
        var b: f32 = undefined;
        c.ImGui_ColorConvertHSVtoRGB(h, s, v, &r, &g, &b);
        return init_rgba_f32(r, g, b, a);
    }
    pub fn init_hsv_f32(h: f32, s: f32, v: f32) Color_Packed {
        return init_hsva_f32(h, s, v, 1.0);
    }

    pub inline fn unpack(self: Color_Packed) Color {
        return @bitCast(c.ImGui_ColorConvertU32ToFloat4(self.to_c()));
    }

    pub inline fn with_style_alpha(self: Color_Packed) Color_Packed {
        return init_packed(c.ImGui_GetColorU32ImU32Ex(self.to_c()));
    }

    pub inline fn eql(self: Color_Packed, other: Color_Packed) bool {
        return std.meta.eql(self, other);
    }

    pub inline fn to_c(self: Color_Packed) C_Type {
        return @bitCast(self);
    }

    pub inline fn from_c(v: C_Type) Color_Packed {
        return @bitCast(v);
    }

    pub const transparent = Color_Packed.init_rgba(0, 0, 0, 0);
    pub const black = Color_Packed.init_rgb(0, 0, 0);
    pub const white = Color_Packed.init_rgb(255, 255, 255);
    pub const red = Color_Packed.init_rgb(255, 0, 0);
    pub const yellow = Color_Packed.init_rgb(255, 255, 0);
    pub const green = Color_Packed.init_rgb(0, 255, 0);
    pub const cyan = Color_Packed.init_rgb(0, 255, 255);
    pub const blue = Color_Packed.init_rgb(0, 0, 255);
    pub const magenta = Color_Packed.init_rgb(255, 0, 255);

    pub const C_Type = u32;
};

pub const Color = extern struct {
    v: Vec4,

    pub inline fn init_rgba(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .v = .init(r, g, b, a) };
    }

    pub inline fn init_rgb(r: f32, g: f32, b: f32) Color {
        return init_rgba(r, g, b, 1);
    }

    pub inline fn init_rgba_unorm(r: u8, g: u8, b: u8, a: u8) Color {
        const inv_255: f32 = 1.0 / 255.0;
        const rf: f32 = @floatFromInt(r);
        const gf: f32 = @floatFromInt(g);
        const bf: f32 = @floatFromInt(b);
        const af: f32 = @floatFromInt(a);
        return init_rgba(rf * inv_255, gf * inv_255, bf * inv_255, af * inv_255);
    }

    pub inline fn init_rgb_unorm(r: u8, g: u8, b: u8) Color {
        return init_rgba_unorm(r, g, b, 255);
    }

    /// Convert HSVA to RGBA color
    pub inline fn init_hsva(h: f32, s: f32, v: f32, a: f32) Color {
        var r: f32 = undefined;
        var g: f32 = undefined;
        var b: f32 = undefined;
        c.ImGui_ColorConvertHSVtoRGB(h, s, v, &r, &g, &b);
        return init_rgba(r, g, b, a);
    }

    pub inline fn init_hsv(h: f32, s: f32, v: f32) Color {
        return init_hsva(h, s, v, 1.0);
    }

    /// Convert an integer 0xaabbggrr to a floating point color
    pub inline fn init_packed(p: Color_Packed) Color {
        const v = p.to_c();
        return init_rgba_unorm(
            @truncate(v >> 0),
            @truncate(v >> 8),
            @truncate(v >> 16),
            @truncate(v >> 24),
        );
    }

    /// Convert from a floating point color to an integer 0xaabbggrr
    pub inline fn pack(self: Color) Color_Packed {
        return Color_Packed.init_packed(c.ImGui_ColorConvertFloat4ToU32(self.to_c()));
    }

    pub inline fn pack_with_style_alpha(self: Color) Color_Packed {
        return Color_Packed.init_packed(c.ImGui_GetColorU32ImVec4(self.to_c()));
    }

    pub inline fn eql(self: Color, other: Color) bool {
        return self.v.eql(other.v);
    }

    pub inline fn to_c(self: Color) C_Type {
        return @bitCast(self);
    }

    pub inline fn from_c(v: C_Type) Color {
        return @bitCast(v);
    }

    pub const transparent = Color.init_rgba(0, 0, 0, 0);
    pub const black = Color.init_rgb(0, 0, 0);
    pub const white = Color.init_rgb(1, 1, 1);
    pub const red = Color.init_rgb(1, 0, 0);
    pub const yellow = Color.init_rgb(1, 1, 0);
    pub const green = Color.init_rgb(0, 1, 0);
    pub const cyan = Color.init_rgb(0, 1, 1);
    pub const blue = Color.init_rgb(0, 0, 1);
    pub const magenta = Color.init_rgb(1, 0, 1);

    pub const C_Type = c.ImVec4;
};

const allocator_impl = struct {
    fn alloc(_: *anyopaque, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) std.mem.Allocator.Error![]u8 {
        _ = len_align;
        _ = ret_addr;
        std.debug.assert(ptr_align <= @alignOf(*anyopaque)); // Alignment larger than pointers is not supported
        const ptr: [*]u8 = @ptrCast(c.ImGui_MemAlloc(len) orelse return error.OutOfMemory);
        return ptr[0..len];
    }
    fn resize(_: *anyopaque, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) ?usize {
        _ = len_align;
        _ = ret_addr;
        std.debug.assert(buf_align <= @alignOf(*anyopaque)); // Alignment larger than pointers is not supported
        if (new_len > buf.len) return null;
        if (new_len == 0 and buf.len != 0) c.ImGui_MemFree(buf.ptr);
        return new_len;
    }
    fn free(_: *anyopaque, buf: []u8, buf_align: u29, ret_addr: usize) void {
        _ = buf_align;
        _ = ret_addr;
        if (buf.len != 0) c.ImGui_MemFree(buf.ptr);
    }

    pub const vtable: std.mem.Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .free = free,
    };
};

pub const allocator: std.mem.Allocator = .{
    .ptr = undefined,
    .vtable = &allocator_impl.vtable,
};

const Menu_Item_Stateful_Options = struct {
    shortcut: ?[*:0]const u8 = null,
    enabled: bool = true,
};
/// return true when activated + toggle (*p_selected) if p_selected != NULL
pub inline fn menu_item_stateful(label: [*:0]const u8, selected: *bool, options: Menu_Item_Stateful_Options) bool {
    return c.ImGui_MenuItemBoolPtr(@ptrCast(label), @ptrCast(options.shortcut), @ptrCast(selected), options.enabled);
}

pub inline fn push_style_color(idx: ig.Col, color: Color) void {
    c.ImGui_PushStyleColorImVec4(idx.to_c(), color.to_c());
}

pub inline fn push_style_color_packed(idx: ig.Col, color: Color_Packed) void {
    c.ImGui_PushStyleColor(idx.to_c(), color.to_c());
}

const Get_Style_Color_Options = struct {
    alpha_mul: f32 = 1,
};
/// retrieve given style color with style alpha applied and optional extra alpha multiplier, packed as a 32-bit value suitable for ImDrawList
pub inline fn get_style_color_packed(idx: ig.Col, options: Get_Style_Color_Options) Color_Packed {
    return Color_Packed.from_c(c.ImGui_GetColorU32Ex(idx.to_c(), options.alpha_mul));
}

/// retrieve style color as stored in ImGuiStyle structure. use to feed back into PushStyleColor(), otherwise use GetColorU32() to get style color with style alpha baked in.
pub inline fn get_style_color(idx: ig.Col) Color {
    return Color.from_c(c.ImGui_GetStyleColorVec4(idx.to_c()));
}

pub fn fmt(comptime format: []const u8, args: anytype) [:0]const u8 {
    const ctx = ig.internal.get_current_context();
    const buf = ctx.temp_buffer.items();
    return std.fmt.bufPrintZ(buf, format, args) catch txt: {
        buf[buf.len - 1] = 0;
        break :txt @ptrCast(buf[0 .. buf.len - 1]);
    };
}

pub inline fn text(comptime format: []const u8, args: anytype) void {
    ig.text_unformatted(fmt(format, args));
}

pub fn text_colored(color: Color, comptime format: []const u8, args: anytype) void {
    push_style_color(.text, color);
    text(format, args);
    ig.pop_style_color(.{});
}

pub fn text_disabled(comptime format: []const u8, args: anytype) void {
    push_style_color(.text, get_style_color(.text_disabled));
    text(format, args);
    ig.pop_style_color(.{});
}

pub fn text_wrapped(comptime format: []const u8, args: anytype) void {
    ig.push_text_wrap_pos(.auto);
    text(format, args);
    ig.pop_text_wrap_pos();
}

pub fn label_text(label: [*:0]const u8, comptime format: []const u8, args: anytype) void {
    c.ImGui_LabelTextUnformatted(label, fmt(format, args).ptr);
}

pub fn bullet_text(comptime format: []const u8, args: anytype) void {
    c.ImGui_BulletTextUnformatted(fmt(format, args).ptr);
}

pub fn separator_text(comptime format: []const u8, args: anytype) void {
    if (ig.internal.get_current_window().skip_items) return;

    // The SeparatorText() vs SeparatorTextEx() distinction is designed to be considerate that we may want:
    // - allow separator-text to be draggable items (would require a stable ID + a noticeable highlight)
    // - this high-level entry point to allow formatting? (which in turns may require ID separate from formatted string)
    // - because of this we probably can't turn 'const char* label' into 'const char* fmt, ...'
    // Otherwise, we can decide that users wanting to drag this would layout a dedicated drag-item,
    // and then we can turn this into a format function.
    const label = fmt(format, args);
    const end = internal_c.ImGui_FindRenderedTextEndEx(label.ptr, label.ptr + label.len);
    internal_c.ImGui_SeparatorTextEx(0, label.ptr, end, 0);
}

pub inline fn tree_node_str_id(id: [*:0]const u8, comptime format: []const u8, args: anytype) bool {
    return c.ImGui_TreeNodeStrUnformatted(id, fmt(format, args).ptr);
}
pub inline fn tree_node_ptr_id(id: *const anyopaque, comptime format: []const u8, args: anytype) bool {
    return c.ImGui_TreeNodePtrUnformatted(id, fmt(format, args).ptr);
}

pub inline fn tree_node_ex_str_id(id: [*:0]const u8, flags: ig.Tree_Node_Flags, comptime format: []const u8, args: anytype) bool {
    return c.ImGui_TreeNodeExStrUnformatted(id, flags, fmt(format, args).ptr);
}
pub inline fn tree_node_ex_ptr_id(id: *const anyopaque, flags: ig.Tree_Node_Flags, comptime format: []const u8, args: anytype) bool {
    return c.ImGui_TreeNodeExPtrUnformatted(id, flags, fmt(format, args).ptr);
}

pub inline fn set_tooltip(comptime format: []const u8, args: anytype) void {
    return c.ImGui_SetTooltipUnformatted(fmt(format, args).ptr);
}
pub inline fn set_item_tooltip(comptime format: []const u8, args: anytype) void {
    return c.ImGui_SetItemTooltipUnformatted(fmt(format, args).ptr);
}

pub inline fn log_text(comptime format: []const u8, args: anytype) void {
    c.ImGui_LogTextUnformatted(fmt(format, args).ptr);
}

/// ImGui/cimgui only provides a stateful bool/flags version of checkbox, but
/// sometimes a non-stateful version is helpful
pub fn checkbox(label: [*:0]const u8, checked: bool) bool {
    var mutable_checked = checked;
    return c.ImGui_Checkbox(label, &mutable_checked);
}

pub fn checkbox_stateful(label: [*:0]const u8, comptime T: type, state: *T, checked_value: T) bool {
    var all_on = false;
    var any_on = false;

    switch (@typeInfo(T)) {
        .int => {
            all_on = (state.* & checked_value) == checked_value;
            any_on = (state.* & checked_value) != 0;
        },
        .bool => {
            all_on = state.* == checked_value;
            any_on = all_on;
        },
        .@"struct" => {
            const info = @typeInfo(T).@"struct";
            if (info.layout == .@"packed") {
                var on_count: usize = 0;
                var total_count: usize = 0;
                inline for (info.fields) |field| {
                    if (field.type == bool) {
                        if (@field(checked_value, field.name) and @field(state.*, field.name)) {
                            on_count += 1;
                        }
                        total_count += 1;
                    }
                }
                all_on = on_count == total_count;
                any_on = on_count > 0;
            } else {
                all_on = util.eql(state.*, checked_value);
                any_on = all_on;
            }
        },
        else => {
            all_on = util.eql(state.*, checked_value);
            any_on = all_on;
        },
    }

    if (!all_on and any_on) {
        const ctx: ig.internal.Context = ig.internal.get_current_context();
        ctx.next_item_data.item_flags.mixed_value = true;
    }

    const pressed = c.ImGui_Checkbox(label, &all_on);
    if (pressed) {
        switch (@typeInfo(T)) {
            .int => {
                if (all_on) {
                    state.* |= checked_value;
                } else {
                    state.* &= ~checked_value;
                }
            },
            .bool => {
                if (all_on) {
                    state.* = checked_value;
                } else {
                    state.* = !checked_value;
                }
            },
            .@"struct" => {
                const info = @typeInfo(T).@"struct";
                if (info.layout == .@"packed") {
                    inline for (info.fields) |field| {
                        if (field.type == bool and @field(checked_value, field.name)) {
                            @field(state.*, field.name) = all_on;
                        }
                    }
                } else {
                    if (all_on) {
                        state.* = checked_value;
                    } else {
                        state.* = .{};
                    }
                }
            },
            else => {
                if (all_on) {
                    state.* = checked_value;
                } else {
                    state.* = std.mem.zeroes(T);
                }
            },
        }
    }
    return pressed;
}

pub fn radio_button_stateful(label: [*:0]const u8, comptime T: type, state: *T, active_value: T) bool {
    const pressed = ig.radio_button(label, util.eql(state.*, active_value));
    if (pressed) state.* = active_value;
    return pressed;
}

/// Widgets: Combo Box (Dropdown)
/// - The BeginCombo()/EndCombo() api allows you to manage your contents and selection state however you want it, by creating e.g. Selectable() items.
/// - The old Combo() api are helpers over BeginCombo()/EndCombo() which are kept available for convenience purpose. This is analogous to how ListBox are created.
pub inline fn begin_combo(label: [*:0]const u8, preview_value: ?[*:0]const u8, flags: ig.Combo_Flags) bool {
    // see C:\Users\Ben\AppData\Local\zig\p\1220388fad9c32584aec3bba9ccdf7d240ab4e81999e0e567a2d832e54177d908daf\imgui.h:578
    return c.ImGui_BeginCombo(@ptrCast(label), @ptrCast(preview_value), flags.to_c());
    // TODO: better way to handle missing/incorrect is_nullable data in the dear bindings json
}

fn Combo_List_Box_Options(comptime T: type) type {
    return struct {
        max_height_in_items: i32 = -1,
        formatter: fn (value: T, writer: std.io.AnyWriter) anyerror!void = default_formatter,

        fn default_formatter(value: T, writer: std.io.AnyWriter) anyerror!void {
            if (T == []const u8 or T == []u8) {
                try writer.print("{s}", .{value});
                return;
            }
            switch (@typeInfo(T)) {
                .@"enum" => if (@typeInfo(T).@"enum".is_exhaustive) {
                    return try writer.print("{s}", .{@tagName(value)});
                },
                .pointer => |info| {
                    if (info.size == .One) {
                        return try Combo_List_Box_Options(info.child).default_formatter(value.*, writer);
                    }
                },
                .optional => |info| {
                    if (value) |v| {
                        try Combo_List_Box_Options(info.child).default_formatter(v, writer);
                    } else {
                        try writer.writeAll("(none)");
                    }
                    return;
                },
                else => {},
            }
            try writer.print("{any}", .{value});
        }
    };
}
pub inline fn combo(label: [*:0]const u8, comptime T: type, current_index: *usize, items: []const T, comptime options: Combo_List_Box_Options(T)) bool {
    const helper = struct {
        fn format_item(item: T) [*:0]const u8 {
            const buf = ig.internal.get_current_context().temp_buffer.items();
            var stream = std.io.fixedBufferStream(buf);
            const writer = stream.writer();
            options.formatter(item, writer.any()) catch {};
            var final = stream.getWritten();
            if (final.len == buf.len) final.len -= 1;
            buf[final.len] = 0;
            return @ptrCast(final);
        }
    };

    const initial_index = current_index.*;
    const preview_value = if (initial_index < items.len) helper.format_item(items[initial_index]) else null;

    if (options.max_height_in_items != -1 and !ig.internal.get_current_context().next_window_data.flags.has_size_constraint) {
        const height = ig.internal.calc_max_popup_height_from_item_count(options.max_height_in_items);
        ig.internal.set_next_window_size_constraints(.zeroes, .init(std.math.floatMax(f32), height));
    }

    if (!ig.begin_combo(label, preview_value, .{})) {
        return false;
    }

    // Display items
    var value_changed = false;
    var clipper = ig.List_Clipper.init();
    clipper.begin(@intCast(items.len), .{});
    if (initial_index < items.len) {
        clipper.include_item_by_index(@intCast(initial_index));
    }
    while (clipper.step()) {
        for (@intCast(clipper.display_start)..@intCast(clipper.display_end)) |i| {
            ig.push_id_int(@intCast(i));
            defer ig.pop_id();

            const selected = i == initial_index;
            if (ig.selectable(helper.format_item(items[i]), .{ .selected = selected }) and !selected) {
                value_changed = true;
                current_index.* = i;
            }
            if (selected) ig.set_item_default_focus();
        }
    }

    ig.end_combo();
    if (value_changed) {
        ig.internal.mark_item_edited(ig.internal.get_current_context().last_item_data.id);
    }

    return value_changed;
}

pub fn combo_enum(label: [*:0]const u8, comptime T: type, state: *T, options: Combo_List_Box_Options) bool {
    const is_optional = @typeInfo(T) == .optional;
    const E = if (is_optional) @typeInfo(T).optional.child else T;
    const info: std.builtin.Type.Enum = @typeInfo(E).@"enum";
    const values = std.enums.values(E);

    const is_normal = comptime normal: {
        if (!info.is_exhaustive) break :normal false;
        for (0.., info.fields) |index, field| {
            if (field.value != index) break :normal false;
        }
        break :normal true;
    };

    const current = state.*;
    var current_item: usize = std.math.maxInt(usize);

    if (is_normal) {
        if (is_optional) {
            if (current) |v| {
                current_item = @intCast(@intFromEnum(v));
            }
        } else {
            current_item = @intCast(@intFromEnum(current));
        }
    } else if (is_optional) {
        if (current) |v| {
            for (0.., values) |i, ev| {
                if (v == ev) {
                    current_item = @intCast(i);
                    break;
                }
            }
        }
    } else {
        for (0.., values) |i, ev| {
            if (current == ev) {
                current_item = @intCast(i);
                break;
            }
        }
    }

    const changed = combo(label, E, &current_item, values, options);
    if (changed) {
        if (current_item < values.len) {
            if (is_normal) {
                const raw: std.meta.Tag(T) = @intCast(current_item);
                state.* = @enumFromInt(raw);
            } else {
                for (0.., values) |i, ev| {
                    if (i == current_item) {
                        state.* = ev;
                        break;
                    }
                } else if (is_optional) {
                    state.* = null;
                }
            }
        } else if (is_optional) {
            state.* = null;
        }
    }
    return changed;
}

pub inline fn list_box(label: [*:0]const u8, comptime T: type, current_index: *usize, items: []const T, comptime options: Combo_List_Box_Options(T)) bool {
    const helper = struct {
        fn format_item(item: T) [*:0]const u8 {
            const buf = ig.internal.get_current_context().temp_buffer.items();
            var stream = std.io.fixedBufferStream(buf);
            const writer = stream.writer();
            options.formatter(item, writer.any()) catch {};
            var final = stream.getWritten();
            if (final.len == buf.len) final.len -= 1;
            buf[final.len] = 0;
            return @ptrCast(final);
        }
    };

    var height_in_items = options.max_height_in_items;
    if (options.max_height_in_items < 0) {
        height_in_items = @min(items.len, 7);
    }
    var height_in_items_f: f32 = @floatFromInt(height_in_items);
    height_in_items_f += 0.25;
    const size = Vec2.init(0, @trunc(ig.get_text_line_height_with_spacing() * height_in_items_f + ig.get_style().frame_padding.y * 2));

    if (!ig.begin_list_box(label, size)) return false;

    // Assume all items have even height (= 1 line of text). If you need items of different height,
    // you can create a custom version of ListBox() in your code without using the clipper.
    var value_changed = false;
    var clipper = ig.List_Clipper.init();
    clipper.begin(items.len, .{ .items_height = ig.get_text_line_height_with_spacing() }); // We know exactly our line height here so we pass it as a minor optimization, but generally you don't need to.
    clipper.include_item_by_index(@intCast(current_index.*));
    while (clipper.step()) {
        for (@intCast(clipper.display_start)..@intCast(clipper.display_end)) |i| {
            ig.push_id_int(@intCast(i));
            defer ig.pop_id();

            const selected = i == current_index.*;
            if (ig.selectable(helper.format_item(items[i]), .{ .selected = selected })) {
                value_changed = true;
                current_index.* = i;
            }
            if (selected) ig.set_item_default_focus();
        }
    }

    ig.end_list_box();
    if (value_changed) {
        ig.internal.mark_item_edited(ig.internal.get_current_context().last_item_data.id);
    }

    return value_changed;
}

pub fn list_box_enum(label: [*:0]const u8, comptime T: type, state: *T, options: Combo_List_Box_Options) bool {
    const is_optional = @typeInfo(T) == .optional;
    const E = if (is_optional) @typeInfo(T).optional.child else T;
    const info: std.builtin.Type.Enum = @typeInfo(E).@"enum";
    const values = std.enums.values(E);

    const is_normal = comptime normal: {
        if (!info.is_exhaustive) break :normal false;
        for (0.., info.fields) |index, field| {
            if (field.value != index) break :normal false;
        }
        break :normal true;
    };

    const current = state.*;
    var current_item: usize = std.math.maxInt(usize);

    if (is_normal) {
        if (is_optional) {
            if (current) |v| {
                current_item = @intCast(@intFromEnum(v));
            }
        } else {
            current_item = @intCast(@intFromEnum(current));
        }
    } else if (is_optional) {
        if (current) |v| {
            for (0.., values) |i, ev| {
                if (v == ev) {
                    current_item = @intCast(i);
                    break;
                }
            }
        }
    } else {
        for (0.., values) |i, ev| {
            if (current == ev) {
                current_item = @intCast(i);
                break;
            }
        }
    }

    const changed = list_box(label, E, &current_item, values, options);
    if (changed) {
        if (current_item < values.len) {
            if (is_normal) {
                const raw: std.meta.Tag(T) = @intCast(current_item);
                state.* = @enumFromInt(raw);
            } else {
                for (0.., values) |i, ev| {
                    if (i == current_item) {
                        state.* = ev;
                        break;
                    }
                } else if (is_optional) {
                    state.* = null;
                }
            }
        } else if (is_optional) {
            state.* = null;
        }
    }
    return changed;
}

pub const structs = struct {
    pub const ImGuiStyle = struct {
        pub fn init() ig.Style {
            const result: ig.Style = .{
                .alpha = 1,
                .disabled_alpha = 0.6,
                .window_padding = .init(8, 8),
                .window_rounding = 0,
                .window_border_size = 1,
                .window_min_size = .init(32, 32),
                .window_title_align = .init(0, 0.5),
                .window_menu_button_position = .left,
                .child_rounding = 0,
                .child_border_size = 1,
                .popup_rounding = 0,
                .popup_border_size = 1,
                .frame_padding = .init(4, 3),
                .frame_rounding = 0,
                .frame_border_size = 0,
                .item_spacing = .init(8, 4),
                .item_inner_spacing = .init(4, 4),
                .cell_padding = .init(4, 2),
                .touch_extra_padding = .init(0, 0),
                .indent_spacing = 21,
                .columns_min_spacing = 6,
                .scrollbar_size = 14,
                .scrollbar_rounding = 9,
                .grab_min_size = 12,
                .grab_rounding = 0,
                .log_slider_deadzone = 4,
                .tab_rounding = 4,
                .tab_border_size = 0,
                .tab_min_width_for_close_button = 0,
                .tab_bar_border_size = 1,
                .tab_bar_overline_size = 2,
                .table_angled_headers_angle = std.math.degreesToRadians(35),
                .table_angled_headers_text_align = .init(0.5, 0),
                .color_button_position = .right,
                .button_text_align = .init(0.5, 0.5),
                .selectable_text_align = .init(0, 0),
                .separator_text_border_size = 3,
                .separator_text_align = .init(0, 0.5),
                .separator_text_padding = .init(20, 3),
                .display_window_padding = .init(19, 19),
                .display_safe_area_padding = .init(3, 3),
                .docking_separator_size = 2,
                .mouse_cursor_scale = 1,
                .anti_aliased_lines = true,
                .anti_aliased_lines_use_tex = true,
                .anti_aliased_fill = true,
                .curve_tessellation_tol = 1.25,
                .circle_tessellation_max_error = 0.3,
                .hover_stationary_delay = 0.15,
                .hover_delay_short = 0.15,
                .hover_delay_normal = 0.4,
                .hover_flags_for_tooltip_mouse = .{ .stationary = true, .delay_short = true, .allow_when_disabled = true },
                .hover_flags_for_tooltip_nav = .{ .no_shared_delay = true, .delay_normal = true, .allow_when_disabled = true },
                .colors = .{ .zeroes } ** ig.Col.count,
            };
            ig.style_colors_dark(.{ .dst = &result });
            return result;
        }
    };

    pub const ImGuiWindowClass = struct {
        pub fn init() ig.Window_Class {
            return .{
                .class_id = 0,
                .parent_viewport_id = std.math.maxInt(ig.ID),
                .focus_route_parent_window_id = 0,
                .viewport_flags_override_set = .{},
                .viewport_flags_override_clear = .{},
                .tab_item_flags_override_set = .{},
                .dock_node_flags_override_set = .{},
                .docking_always_tab_bar = false,
                .docking_allow_unclassed = true,
            };
        }
    };

    pub const ImGuiPayload = struct {
        pub fn init() ig.Payload {
            var result = std.mem.zeroes(ig.Payload);
            result.clear();
            return result;
        }
    };

    pub const ImFontConfig = struct {
        pub fn init() ig.Font_Config {
            return .{
                .font_data = null,
                .font_data_size = 0,
                .font_data_owned_by_atlas = true,
                .font_no = 0,
                .size_pixels = 0,
                .oversample_h = 2,
                .oversample_v = 1,
                .pixel_snap_h = false,
                .glyph_extra_spacing = .zeroes,
                .glyph_offset = .zeroes,
                .glyph_ranges = null,
                .glyph_min_advance_x = 0,
                .glyph_max_advance_x = std.math.floatMax(f32),
                .merge_mode = false,
                .font_builder_flags = 0,
                .rasterizer_multiply = 1,
                .rasterizer_density = 1,
                .ellipsis_char = std.math.maxInt(ig.Wchar),
                .name = .{ 0 } ** 40,
                .dst_font = null,
            };
        }
    };

    pub const ImFontGlyphRangesBuilder = struct {
        pub fn init() ig.Font_Glyph_Ranges_Builder {
            var result = std.mem.zeroes(ig.Font_Glyph_Ranges_Builder);
            result.clear();
            return result;
        }
    };

    pub const ImFontAtlas = struct {
        const Add_Font_TTF_Options = struct {
            font_config: ?*const ig.Font_Config = null,
            glyph_ranges: ?[*:0]const ig.Wchar = null,
        };

        /// font_data should have static lifetime; e.g. from @embedFile
        pub fn add_font_from_memory_ttf_static(self: *ig.Font_Atlas, font_data: []const u8, size_pixels: f32, options: Add_Font_TTF_Options) *ig.Font {
            if (options.font_config == null) {
                var font_config = ig.Font_Config.init();
                font_config.font_data_owned_by_atlas = false;
                var final_options = options;
                final_options.font_config = &font_config;
                return @ptrCast(c.ImFontAtlas_AddFontFromMemoryTTF(@ptrCast(self), @constCast(font_data.ptr), @intCast(font_data.len), size_pixels, @ptrCast(&font_config), options.glyph_ranges));
            } else {
                std.debug.assert(options.font_config.?.font_data_owned_by_atlas == false);
                return @ptrCast(c.ImFontAtlas_AddFontFromMemoryTTF(@ptrCast(self), @constCast(font_data.ptr), @intCast(font_data.len), size_pixels, @ptrCast(options.font_config), options.glyph_ranges));
            }
        }

        /// font_data must have been allocated with zigig.allocator!  The font atlas will take ownership of it and may free it later.
        pub fn add_font_from_memory_ttf_transfer_ownership(self: *ig.Font_Atlas, font_data: []const u8, size_pixels: f32, options: Add_Font_TTF_Options) *ig.Font {
            if (options.font_config) |font_config| std.debug.assert(font_config.font_data_owned_by_atlas == true);
            return @ptrCast(c.ImFontAtlas_AddFontFromMemoryTTF(@ptrCast(self), font_data.ptr, font_data.len, size_pixels, options.font_config, options.glyph_ranges));
        }

        const Get_Tex_Data_Options = struct {
            out_bytes_per_pixel: ?*i32 = null,
        };

        /// 1 byte per-pixel
        pub inline fn get_tex_data_as_alpha8(self: *ig.Font_Atlas, out_pixels: *[*]u8, out_width: *i32, out_height: *i32, options: Get_Tex_Data_Options) void {
            c.ImFontAtlas_GetTexDataAsAlpha8(@ptrCast(self), @ptrCast(out_pixels), @ptrCast(out_width), @ptrCast(out_height), @ptrCast(options.out_bytes_per_pixel));
        }

        /// 4 bytes-per-pixel
        pub inline fn get_tex_data_as_rgba32(self: *ig.Font_Atlas, out_pixels: *[*]u8, out_width: *i32, out_height: *i32, options: Get_Tex_Data_Options) void {
            c.ImFontAtlas_GetTexDataAsRGBA32(@ptrCast(self), @ptrCast(out_pixels), @ptrCast(out_width), @ptrCast(out_height), @ptrCast(options.out_bytes_per_pixel));
        }
    };

    pub const ImFontAtlasCustomRect = struct {
        pub fn init() ig.Font_Atlas_Custom_Rect {
            return .{
                .width = 0,
                .height = 0,
                .x = 0xFFFF,
                .y = 0xFFFF,
                .glyph_id = 0,
                .glyph_advance_x = 0,
                .glyph_offset = .zeroes,
                .font = null,
            };
        }
    };
};

const util = @This();

const ig = @import("ig");
const c = @import("cimgui");
const internal_c = @import("cimgui_internal");
const std = @import("std");
