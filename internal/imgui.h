// cimgui_internal.h has #include "imgui.h", which breaks horribly when running it through translate-c,
// because C++ is not C.  It should really probably be importing cimgui.h instead, so we'll tell
// translate-c that's what imgui.h is:

#include "cimgui.h"
