#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#else
#include "cimgui_internal.h"
#endif
// imgui.h structs
size_t GetImFontGlyphSize();

// imgui_internal.h structs
size_t GetImGuiContextSize();
size_t GetImGuiWindowSize();
size_t GetImGuiStackLevelInfoSize();
size_t GetImGuiDockNodeSize();
size_t GetImGuiBoxSelectStateSize();
size_t GetImGuiTableColumnSize();
size_t GetImGuiTableSize();
size_t GetImGuiTableTempDataSize();

// This is particularly important to get right since we use it for every formatted text call
size_t GetImGuiContextTempBufferOffset();

#ifdef __cplusplus
}
#endif
