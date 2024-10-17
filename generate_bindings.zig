pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var iter = try std.process.argsWithAllocator(a);
    _ = iter.next(); // ignore generate_bindings executable name/path
    const python_cmd = iter.next() orelse return error.ExpectedPythonCmd;
    const imgui_path = iter.next() orelse return error.ExpectedImGuiPath;
    const dear_bindings_path = iter.next() orelse return error.ExpectedDearBindingsPath;
    const output_dir = iter.next() orelse return error.ExpectedOutputDir;
    const last = iter.next() orelse "";
    const translate_packed = std.mem.eql(u8, last, "translate-packed");

    try std.fs.cwd().makePath(output_dir);

    const dear_bindings_py = try std.fs.path.resolve(a, &.{ dear_bindings_path, "dear_bindings.py" });

    {
        var generate = std.process.Child.init(&.{
            python_cmd, dear_bindings_py,
            "--emit-combined-json-metadata",
            "--generateunformattedfunctions",
            "-o", try std.fs.path.resolve(a, &.{ output_dir, "cimgui" }),
            try std.fs.path.resolve(a, &.{ imgui_path, "imgui.h" }),
        }, a);

        const term = try generate.spawnAndWait();
        if (term != .Exited or term.Exited != 0) return error.FailedToGenerateCImGui;
    }

    {
        var generate = std.process.Child.init(&.{
            python_cmd, dear_bindings_py,
            "--emit-combined-json-metadata",
            "--generateunformattedfunctions",
            "-o", try std.fs.path.resolve(a, &.{ output_dir, "cimgui_internal" }),
            "--include", try std.fs.path.resolve(a, &.{ imgui_path, "imgui.h" }),
            try std.fs.path.resolve(a, &.{ imgui_path, "imgui_internal.h" }),
        }, a);

        const term = try generate.spawnAndWait();
        if (term != .Exited or term.Exited != 0) return error.FailedToGenerateCImGuiInternal;
    }

    if (translate_packed) {
        // Fix stupid bitfields in structs that prevents translate-c from working
        const path = try std.fs.path.resolve(a, &.{ output_dir, "cimgui.h" });
        const stat = try std.fs.cwd().statFile(path);
        var contents = try std.fs.cwd().readFileAllocOptions(a, path, 100_000_000, stat.size, 1, null);

        contents = try std.mem.replaceOwned(u8, a, contents, "\r", "");

        try replace(contents,
            \\typedef struct ImFontGlyph_t
            \\{
            \\    unsigned int Colored : 1;     // Flag to indicate glyph is colored and should generally ignore tinting (make it usable with no shift on little-endian as this is used in loops)
            \\    unsigned int Visible : 1;     // Flag to indicate glyph has no visible pixels (e.g. space). Allow early out when rendering.
            \\    unsigned int Codepoint : 30;  // 0x0000..0x10FFFF
            \\    float        AdvanceX;
            ,
            \\typedef struct ImFontGlyph_t
            \\{
            \\//unsigned int Colored : 1; // Flag to indicate glyph is colored and should generally ignore tinting (make it usable with no shift on little-endian as this is used in loops)
            \\//unsigned int Visible : 1; // Flag to indicate glyph has no visible pixels (e.g. space). Allow early out when rendering.
            \\//unsigned int Codepoint : 30; // 0x0000..0x10FFFF
            \\ unsigned int Packed;
            \\    float AdvanceX;
        );

        try std.fs.cwd().writeFile(.{
            .sub_path = path,
            .data = contents
        });
    }

    if (translate_packed) {
        // Fix stupid bitfields in internal structs that prevents translate-c from working
        const path = try std.fs.path.resolve(a, &.{ output_dir, "cimgui_internal.h" });
        const stat = try std.fs.cwd().statFile(path);
        var contents = try std.fs.cwd().readFileAllocOptions(a, path, 100_000_000, stat.size, 1, null);

        contents = try std.mem.replaceOwned(u8, a, contents, "\r", "");

        try replace(contents, // ImGuiBoxSelectState
            \\    ImGuiID       ID;
            \\    bool          IsActive;
            \\    bool          IsStarting;
            \\    bool          IsStartedFromVoid;  // Starting click was not from an item.
            \\    bool          IsStartedSetNavIdOnce;
            \\    bool          RequestClear;
            \\    ImGuiKeyChord KeyMods : 16;       // Latched key-mods for box-select logic.
            \\    ImVec2        StartPosRel;
            ,
            \\    ImGuiID   ID;
            \\    bool      IsActive;
            \\    bool      IsStarting;
            \\    bool      IsStartedFromVoid;  // Starting click was not from an item.
            \\    bool       IsStartedSetNavIdOnce;
            \\  //bool        RequestClear;
            \\  //ImGuiKeyChord KeyMods : 16;       // Latched key-mods for box-select logic.
            \\    int PackedFlags;
            \\    ImVec2        StartPosRel;
        );

        try replace(contents, // ImGuiDockNode
            \\    ImGuiID                 RefViewportId;         // Reference viewport ID from visible window when HostWindow == NULL.
            \\    ImGuiDataAuthority      AuthorityForPos : 3;
            \\    ImGuiDataAuthority      AuthorityForSize : 3;
            \\    ImGuiDataAuthority      AuthorityForViewport : 3;
            \\    bool                    IsVisible : 1;         // Set to false when the node is hidden (usually disabled as it has no active window)
            \\    bool                    IsFocused : 1;
            \\    bool                    IsBgDrawnThisFrame : 1;
            \\    bool                    HasCloseButton : 1;    // Provide space for a close button (if any of the docked window has one). Note that button may be hidden on window without one.
            \\    bool                    HasWindowMenuButton : 1;
            \\    bool                    HasCentralNodeChild : 1;
            \\    bool                    WantCloseAll : 1;      // Set when closing all tabs at once.
            \\    bool                    WantLockSizeOnce : 1;
            \\    bool                    WantMouseMove : 1;     // After a node extraction we need to transition toward moving the newly created host window
            \\    bool                    WantHiddenTabBarUpdate : 1;
            \\    bool                    WantHiddenTabBarToggle : 1;
            \\} ImGuiDockNode;
            ,
            \\    ImGuiID                 RefViewportId;         // Reference viewport ID from visible window when HostWindow == NULL.
            \\    //ImGuiDataAuthority   AuthorityForPos : 3;
            \\    //ImGuiDataAuthority   AuthorityForSize : 3;
            \\    //ImGuiDataAuthority   AuthorityForViewport : 3;
            \\    //bool                 IsVisible : 1;         // Set to false when the node is hidden (usually disabled as it has no active window)
            \\    //bool                 IsFocused : 1;
            \\    //bool                 IsBgDrawnThisFrame : 1;
            \\    //bool                 HasCloseButton : 1;    // Provide space for a close button (if any of the docked window has one). Note that button may be hidden on window without one.
            \\    //bool                 HasWindowMenuButton : 1;
            \\    //bool                HasCentralNodeChild : 1;
            \\    //bool                WantCloseAll : 1;      // Set when closing all tabs at once.
            \\    //bool                WantLockSizeOnce : 1;
            \\    //bool                WantMouseMove : 1;     // After a node extraction we need to transition toward moving the newly created host window
            \\    //bool                WantHiddenTabBarUpdate : 1;
            \\    //bool                WantHiddenTabBarToggle : 1;
            \\    int PackedBits;
            \\} ImGuiDockNode;
        );

        try replace(contents, // ImGuiStackLevelInfo
            \\typedef struct ImGuiStackLevelInfo_t
            \\{
            \\    ImGuiID       ID;
            \\    ImS8          QueryFrameCount;  // >= 1: Query in progress
            \\    bool          QuerySuccess;     // Obtained result from DebugHookIdInfo()
            \\    ImGuiDataType DataType : 8;
            \\    char          Desc[57];         // Arbitrarily sized buffer to hold a result (FIXME: could replace Results[] with a chunk stream?) FIXME: Now that we added CTRL+C this should be fixed.
            \\} ImGuiStackLevelInfo;
            ,
            \\typedef struct ImGuiStackLevelInfo_t
            \\{
            \\    ImGuiID       ID;
            \\    ImS8          QueryFrameCount;  // >= 1: Query in progress
            \\    bool          QuerySuccess;     // Obtained result from DebugHookIdInfo()
            \\    ImGuiDataType DataType;    
            \\    char          Desc[57];         // Arbitrarily sized buffer to hold a result (FIXME: could replace Results[] with a chunk stream?) FIXME: Now that we added CTRL+C this should be fixed.
            \\} ImGuiStackLevelInfo;
        );

        try replace(contents, // ImGuiContext
            \\    float                          ActiveIdTimer;
            \\    bool                           ActiveIdIsJustActivated;             // Set at the time of activation for one frame
            \\    bool                           ActiveIdAllowOverlap;                // Active widget allows another widget to steal active id (generally for overlapping widgets, but not always)
            \\    bool                           ActiveIdNoClearOnFocusLoss;          // Disable losing active id if the active id window gets unfocused.
            \\    bool                           ActiveIdHasBeenPressedBefore;        // Track whether the active id led to a press (this is to allow changing between PressOnClick and PressOnRelease without pressing twice). Used by range_select branch.
            \\    bool                           ActiveIdHasBeenEditedBefore;         // Was the value associated to the widget Edited over the course of the Active state.
            \\    bool                           ActiveIdHasBeenEditedThisFrame;
            \\    bool                           ActiveIdFromShortcut;
            \\    int                            ActiveIdMouseButton : 8;
            \\    ImVec2                         ActiveIdClickOffset;
            ,
            \\    float                          ActiveIdTimer;
            \\    bool                           ActiveIdIsJustActivated;             // Set at the time of activation for one frame
            \\    bool                           ActiveIdAllowOverlap;                // Active widget allows another widget to steal active id (generally for overlapping widgets, but not always)
            \\    bool                           ActiveIdNoClearOnFocusLoss;          // Disable losing active id if the active id window gets unfocused.
            \\    bool                           ActiveIdHasBeenPressedBefore;        // Track whether the active id led to a press (this is to allow changing between PressOnClick and PressOnRelease without pressing twice). Used by range_select branch.
            \\    bool                           ActiveIdHasBeenEditedBefore;         // Was the value associated to the widget Edited over the course of the Active state.
            \\    bool                           ActiveIdHasBeenEditedThisFrame;
            \\    bool                           ActiveIdFromShortcut;
            \\    int                            ActiveIdMouseButton;    
            \\    ImVec2                         ActiveIdClickOffset;
        );

        try replace(contents, // ImGuiWindow
            \\    ImGuiDir                 AutoPosLastDirection;
            \\    ImS8                     HiddenFramesCanSkipItems;                        // Hide the window for N frames
            \\    ImS8                     HiddenFramesCannotSkipItems;                     // Hide the window for N frames while allowing items to be submitted so we can measure their size
            \\    ImS8                     HiddenFramesForRenderOnly;                       // Hide the window until frame N at Render() time only
            \\    ImS8                     DisableInputsFrames;                             // Disable window interactions for N frames
            \\    ImGuiCond                SetWindowPosAllowFlags : 8;                      // store acceptable condition flags for SetNextWindowPos() use.
            \\    ImGuiCond                SetWindowSizeAllowFlags : 8;                     // store acceptable condition flags for SetNextWindowSize() use.
            \\    ImGuiCond                SetWindowCollapsedAllowFlags : 8;                // store acceptable condition flags for SetNextWindowCollapsed() use.
            \\    ImGuiCond                SetWindowDockAllowFlags : 8;                     // store acceptable condition flags for SetNextWindowDock() use.
            \\    ImVec2                   SetWindowPosVal;                                 // store window position when using a non-zero Pivot (position set needs to be processed when we know the window size)
            ,
            \\    ImGuiDir                 AutoPosLastDirection;
            \\    ImS8                     HiddenFramesCanSkipItems;                        // Hide the window for N frames
            \\    ImS8                     HiddenFramesCannotSkipItems;                     // Hide the window for N frames while allowing items to be submitted so we can measure their size
            \\    ImS8                     HiddenFramesForRenderOnly;                       // Hide the window until frame N at Render() time only
            \\    ImS8                     DisableInputsFrames;                             // Disable window interactions for N frames
            \\    ImS8                     SetWindowPosAllowFlags;                          // store acceptable condition flags for SetNextWindowPos() use.
            \\    ImS8                     SetWindowSizeAllowFlags;                         // store acceptable condition flags for SetNextWindowSize() use.
            \\    ImS8                     SetWindowCollapsedAllowFlags;                    // store acceptable condition flags for SetNextWindowCollapsed() use.
            \\    ImS8                     SetWindowDockAllowFlags;                         // store acceptable condition flags for SetNextWindowDock() use.
            \\    ImVec2                   SetWindowPosVal;                                 // store window position when using a non-zero Pivot (position set needs to be processed when we know the window size)
        );

        try replace(contents, // ImGuiWindow
            \\    // Docking
            \\    bool                     DockIsActive : 1;                                // When docking artifacts are actually visible. When this is set, DockNode is guaranteed to be != NULL. ~~ (DockNode != NULL) && (DockNode->Windows.Size > 1).
            \\    bool                     DockNodeIsVisible : 1;
            \\    bool                     DockTabIsVisible : 1;                            // Is our window visible this frame? ~~ is the corresponding tab selected?
            \\    bool                     DockTabWantClose : 1;
            \\    short                    DockOrder;
            ,
            \\    // Docking
            \\    //bool             DockIsActive : 1                                 // When docking artifacts are actually visible. When this is set, DockNode is guaranteed to be != NULL. ~~ (DockNode != NULL) && (DockNode->Windows.Size > 1).
            \\    //bool             DockNodeIsVisible : 1;
            \\    //bool             DockTabIsVisible : 1;                            // Is our window visible this frame? ~~ is the corresponding tab selected?
            \\    //bool             DockTabWantClose : 1;
            \\    bool DockBoolFlags;
            \\    short                    DockOrder;
        );

        try replace(contents, // ImGuiTableColumn
            \\    ImU8                     CannotSkipItemsQueue;          // Queue of 8 values for the next 8 frames to disable Clipped/SkipItem
            \\    ImU8                     SortDirection : 2;             // ImGuiSortDirection_Ascending or ImGuiSortDirection_Descending
            \\    ImU8                     SortDirectionsAvailCount : 2;  // Number of available sort directions (0 to 3)
            \\    ImU8                     SortDirectionsAvailMask : 4;   // Mask of available sort directions (1-bit each)
            \\    ImU8                     SortDirectionsAvailList;
            ,
            \\    ImU8                     CannotSkipItemsQueue;          // Queue of 8 values for the next 8 frames to disable Clipped/SkipItem
            \\    //ImU8          SortDirection : 2;             // ImGuiSortDirection_Ascending or ImGuiSortDirection_Descending
            \\    //ImU8          SortDirectionsAvailCount : 2;  // Number of available sort directions (0 to 3)
            \\    //ImU8         SortDirectionsAvailMask : 4;   // Mask of available sort directions (1-bit each)
            \\    ImU8 SortDirectionBits;
            \\    ImU8                     SortDirectionsAvailList;
        );

        try replace(contents, // ImGuiTable
            \\    float                      RowIndentOffsetX;
            \\    ImGuiTableRowFlags         RowFlags : 16;              // Current row flags, see ImGuiTableRowFlags_
            \\    ImGuiTableRowFlags         LastRowFlags : 16;
            \\    int                        RowBgColorCounter;
            ,
            \\    float              RowIndentOffsetX;
            \\  //ImGuiTableRowFlags RowFlags : 16;              // Current row flags, see ImGuiTableRowFlags_
            \\  //ImGuiTableRowFlags LastRowFlags : 16;
            \\    int RowFlagsPacked;
            \\    int                        RowBgColorCounter;
        );

        try replace(contents, // ImGuiTableTempData
            \\    ImGuiTableColumnIdx SortOrder;
            \\    ImU8                SortDirection : 2;
            \\    ImU8                IsEnabled : 1;  // "Visible" in ini file
            \\    ImU8                IsStretch : 1;
            \\} ImGuiTableColumnSettings;
            ,
            \\    ImGuiTableColumnIdx SortOrder;
            \\  //ImU8        SortDirection : 2;
            \\  //ImU8         IsEnabled : 1;  // "Visible" in ini file
            \\  //ImU8         IsStretch : 1;
            \\    ImU8 PackedFlags;
            \\} ImGuiTableColumnSettings;
        );

        try std.fs.cwd().writeFile(.{
            .sub_path = path,
            .data = contents
        });
    }
}

fn replace(haystack: []u8, comptime needle: []const u8, comptime replacement: []const u8) !void {
    if (needle.len != replacement.len) {
        @compileLog(needle.len, replacement.len);
    }
    if (std.mem.indexOf(u8, haystack, needle)) |index| {
        const buf = haystack[index..][0..needle.len];
        @memcpy(buf, replacement);
    } else return error.BitfieldNotFound;
}

const std = @import("std");
