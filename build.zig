pub const Naming_Convention = enum {
    zig_standard, // PascalTypes / camelFunctions  / snake_fields / snake_variables
    snake, // Proper_Snake_Types / snake_functions / snake_fields / snake_variables
//  imgui, //        PascalTypes / PascalFunctions / PascalFields / snake_variables
};

pub fn build(b: *std.Build) void {
    const imgui_path = b.dependency("imgui", .{}).path(".");
    const dear_bindings_path = b.dependency("dear_bindings", .{}).path(".");

    const naming_convention = b.option(Naming_Convention, "naming", "Which case/naming convention should be used for the generated code?") orelse .zig_standard;

    const python_cmd = b.option([]const u8, "python", "name or path to python 3.10+.  Default is 'python'") orelse "python";

    const validate_all_struct_sizes = b.option(bool, "validate_packed_structs", "Attempt to validate @sizeOf structs containing bitfields.  These are normally skipped by translate-c so it requires some extra manual work to ensure translate-c never sees them, and this is likely to break when updating to a new version of ImGui.") orelse false;

    // Unfortunately dear_bindings.py doesn't take the exact output file name, but only the stem.
    // It then adds the .h/.cpp/.json extension for the files it generates.
    // Zig doesn't provide a good way to handle this with addSystemCommand, so instead we compile
    // and run a small zig program that lets us use addOutputDirectoryArg instead:

    const generate_bindings_exe = b.addExecutable(.{
        .name = "generate_bindings",
        .root_source_file = b.path("generate_bindings.zig"),
        .optimize = .ReleaseSafe,
        .target = b.host,
    });

    const generate_bindings = b.addRunArtifact(generate_bindings_exe);
    generate_bindings.addArg(python_cmd);
    generate_bindings.addDirectoryArg(imgui_path);
    generate_bindings.addDirectoryArg(dear_bindings_path);
    const bindings_path = generate_bindings.addOutputDirectoryArg("cimgui");
    generate_bindings.addArg(if (validate_all_struct_sizes) "translate-packed" else "no-translate-packed");

    generate_bindings.addFileInput(imgui_path.path(b, "imgui.h"));
    generate_bindings.addFileInput(imgui_path.path(b, "imgui_internal.h"));
    generate_bindings.addFileInput(dear_bindings_path.path(b, "dear_bindings.py"));

    if (b.option(bool, "pip_install", "Run `pip install -r requirements.txt` for the dear_bindings library") orelse false) {
        const pip_install = b.addSystemCommand(&.{
            "pip", "install", "-r",
        });
        pip_install.addFileArg(dear_bindings_path.path(b, "requirements.txt"));

        generate_bindings.step.dependOn(&pip_install.step);
    }

    const imgui_wf = b.addNamedWriteFiles("imgui");
    _ = imgui_wf.addCopyDirectory(imgui_path, "", .{ .include_extensions = &.{ ".h" }});
    _ = imgui_wf.addCopyFile(bindings_path.path(b, "cimgui.h"), "cimgui.h");
    _ = imgui_wf.addCopyFile(bindings_path.path(b, "cimgui_internal.h"), "cimgui_internal.h");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const imgui = b.addStaticLibrary(.{
        .name = "cimgui",
        .optimize = optimize,
        .target = target,
    });
    imgui.linkLibC();
    imgui.linkLibCpp();

    imgui.root_module.addCMacro("IMGUI_DISABLE_OBSOLETE_FUNCTIONS", "");

    imgui.addIncludePath(imgui_path);
    imgui.addCSourceFiles(.{
        .root = imgui_path,
        .files = &.{
            "imgui.cpp",
            "imgui_demo.cpp",
            "imgui_draw.cpp",
            "imgui_tables.cpp",
            "imgui_widgets.cpp",
        },
        .flags = &.{ "-Werror", "-Wall" },
    });

    imgui.addIncludePath(bindings_path);
    imgui.addCSourceFiles(.{
        .root = bindings_path,
        .files = &.{
            "cimgui.cpp",
            "cimgui_internal.cpp",
        },
        .flags = &.{ "-Werror", "-Wall", "-Wno-unused-function" },
    });
    imgui.addCSourceFile(.{
        .file = b.path("check_sizes.cpp"),
        .flags = &.{ "-Werror", "-Wall", "-Wno-unused-function" },
    });

    b.installArtifact(imgui);

    const translate_cimgui_h = b.addTranslateC(.{
        .root_source_file = bindings_path.path(b, "cimgui.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_cimgui_h.addIncludePath(bindings_path);
    translate_cimgui_h.addIncludePath(b.path("internal"));
    translate_cimgui_h.defineCMacro("IMGUI_DISABLE_OBSOLETE_FUNCTIONS", "");
    const cimgui_module = translate_cimgui_h.addModule("cimgui");

    const translate_cimgui_internal_h = b.addTranslateC(.{
        .root_source_file = b.path("check_sizes.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_cimgui_internal_h.addIncludePath(bindings_path);
    translate_cimgui_internal_h.addIncludePath(b.path("internal"));
    translate_cimgui_internal_h.defineCMacro("IMGUI_DISABLE_OBSOLETE_FUNCTIONS", "");
    const cimgui_internal_module = translate_cimgui_internal_h.addModule("cimgui_internal");

    b.getInstallStep().dependOn(&b.addInstallFile(translate_cimgui_h.getOutput(), "cimgui.h.zig").step);
    b.getInstallStep().dependOn(&b.addInstallFile(translate_cimgui_internal_h.getOutput(), "cimgui_internal.h.zig").step);

    const naming = b.createModule(.{
        .root_source_file = b.path(b.fmt("naming/{s}.zig", .{ @tagName(naming_convention) })),
    });

    // this module doesn't have the ig import, but we don't need it for generate_zig
    const temp_util = b.createModule(.{
        .root_source_file = b.path(b.fmt("util/{s}.zig", .{ @tagName(naming_convention) })),
        .imports = &.{
            .{ .name = "cimgui", .module = cimgui_module },
        },
    });

    const generate_zig_exe = b.addExecutable(.{
        .name = "generate_zig",
        .root_source_file = b.path("generate_zig.zig"),
        .optimize = .Debug,
        .target = b.host,
    });
    generate_zig_exe.root_module.addImport("naming", naming);
    generate_zig_exe.root_module.addImport("util", temp_util);

    const generate_zig = b.addRunArtifact(generate_zig_exe);
    generate_zig.addDirectoryArg(imgui_path);
    generate_zig.addFileArg(bindings_path.path(b, "cimgui.json"));
    generate_zig.addFileArg(bindings_path.path(b, "cimgui_internal.json"));
    const generated_zig_dir = generate_zig.addOutputDirectoryArg(".");
    generate_zig.addArg(if (validate_all_struct_sizes) "validate-packed" else "no-validate-packed");

    b.getInstallStep().dependOn(&b.addInstallFile(generated_zig_dir.path(b, "ig.zig"), "ig.zig").step);
    b.getInstallStep().dependOn(&b.addInstallFile(generated_zig_dir.path(b, "internal.zig"), "internal.zig").step);

    const util = b.createModule(.{
        .root_source_file = b.path(b.fmt("util/{s}.zig", .{ @tagName(naming_convention) })),
        .imports = &.{
            .{ .name = "cimgui", .module = cimgui_module },
        },
    });

    const ig = b.addModule("ig", .{
        .root_source_file = generated_zig_dir.path(b, "ig.zig"),
        .imports = &.{
            .{ .name = "util", .module = util },
            .{ .name = "cimgui", .module = cimgui_module },
            .{ .name = "cimgui_internal", .module = cimgui_internal_module },
        },
    });
    ig.linkLibrary(imgui);

    util.addImport("ig", ig);
}

const std = @import("std");
