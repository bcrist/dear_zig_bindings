# Dear (Zig) Bindings

Ziggified bindings for Dear ImGui, via Dear Bindings.

## Why?

There are a bunch of open source repos with Zig bindings for Dear ImGui, however none of them met my wants/needs, which are:

* C interfaces generated with Dear Bindings rather than cimgui or entirely manually-maintained bindings
* Able to take advantage of Zig features like packed structs, enums, and comptime
* Exposes `imgui_internal.h` functions and structs as well as just the public API, so that backends and custom widgets can be written in Zig
* Not tied to a specific version of Dear ImGui or a specific backend

## How?

If you don't need a specific ImGui version, just add this repo as you would any other Zig package:

```
zig fetch --save https://github.com/bcrist/dear_zig_bindings#main
```

Then add the `ig` module to your compile step and use it.  You will also need a backend implementation since none is included, and for this you have three options:
* Write it in Zig, interfacing with `ig` and `ig.internal` functions and data types
* Write it in C, interfacing with the Dear Bindings generated headers
* Write it in C++, interfacing directly with the Dear ImGui headers

You can find an example of the first option here: [Dear (Zig) Bindings: Sokol Backend](https://github.com/bcrist/dear_zig_bindings_sokol)
For the latter two options, you can use the `NamedWriteFiles` exported as `imgui` to ensure you're using headers which match the static library attached to the `ig` module.

### Build Dependencies

Since this repo uses Dear Bindings, you will need to have a Python 3.10+ interpretter available on your path.  By default it also assumes that you've `pip install`ed the Dear Bindings dependencies in whatever python environment you run `zig build` in.  You can however force the build system to install the python packages with `zig build -Dpip_install=true`.

### Changing ImGui Versions

If you want to use a differnt ImGui version, just fork this repo and change the `build.zig.zon` to reference whatever commit you want.  Note that `zig build -Dvalidate_packed_structs=true` will likely break on versions of Dear ImGui that are significantly different, and some added/renamed functions may require extra work to ensure the generated bindings look and work correctly.

### Naming Conventions

By default, standard Zig naming conventions are used for generated names, however you can also generate functions and type names in full snake case.  These can be selected with `zig build -Dnaming=snake`.  It should be possible to modify the code to also support using full pascal case, to match the original Dear ImGui style more closely, but I haven't put in the work to support that.
