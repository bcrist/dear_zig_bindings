#include "check_sizes.h"
#include "imgui.h"
#include "imgui_internal.h"

extern "C" {
    size_t GetImFontGlyphSize() {
        return sizeof(ImFontGlyph);
    }
    size_t GetImGuiContextSize() {
        return sizeof(ImGuiContext);
    }
    size_t GetImGuiWindowSize() {
        return sizeof(ImGuiWindow);
    }
    size_t GetImGuiStackLevelInfoSize() {
        return sizeof(ImGuiStackLevelInfo);
    }
    size_t GetImGuiDockNodeSize() {
        return sizeof(ImGuiDockNode);
    }
    size_t GetImGuiBoxSelectStateSize() {
        return sizeof(ImGuiBoxSelectState);
    }
    size_t GetImGuiTableColumnSize() {
        return sizeof(ImGuiTableColumn);
    }
    size_t GetImGuiTableSize() {
        return sizeof(ImGuiTable);
    }
    size_t GetImGuiTableTempDataSize() {
        return sizeof(ImGuiTableTempData);
    }
    size_t GetImGuiContextTempBufferOffset() {
        return offsetof(ImGuiContext, TempBuffer);
    }
}
