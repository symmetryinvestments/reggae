/**
   Wrapper structs to ensure type-safety and readability, as well
   as helper types to use as arguments to build commands.
 */
module reggae.types;

import reggae.rules.common: exeExt;
import std.path: baseName, stripExtension, defaultExtension;

@safe:

struct SourceFileName {
    string value;
}

struct BinaryFileName {
    string value;
}

struct App {
    SourceFileName srcFileName;
    BinaryFileName exeFileName;

    this(SourceFileName srcFileName) pure {
        immutable stripped = srcFileName.value.baseName.stripExtension;
        immutable exeFileName = BinaryFileName(exeExt == "" ? stripped : stripped.defaultExtension(exeExt));

        this(srcFileName, exeFileName);
    }

    this(SourceFileName srcFileName, BinaryFileName exeFileName) @safe pure nothrow {
        this.srcFileName = srcFileName;
        this.exeFileName = exeFileName;
    }
}


struct Flags {
    string[] value;

    this(string value) @trusted pure {
        import std.array: split;
        this.value = value.split;
    }

    this(inout(string)[] values) inout @safe @nogc pure nothrow {
        this.value = values;
    }
}

struct CompilerFlags {
    string[] value;

    this(string value) @trusted pure {
        import std.array: split;
        this.value = value.split;
    }

    this(string[] values...) @safe pure nothrow {
        this.value = values.dup;
    }

    this(inout(string)[] values) inout @safe @nogc pure nothrow {
        this.value = values;
    }
}

struct LinkerFlags {
    string[] value;

    this(string value) @trusted pure {
        import std.array: split;
        this.value = value.split;
    }

    this(string[] values...) @safe pure nothrow {
        this.value = values.dup;
    }

    this(inout(string)[] values) inout @safe @nogc pure nothrow {
        this.value = values;
    }
}

struct ImportPaths {
    string[] value;

    this(inout(string)[] value) inout pure {
        this.value = value;
    }

    this(inout(string) value) inout pure {
        this([value]);
    }

}

alias IncludePaths = ImportPaths;

struct StringImportPaths {
    string[] value;

    this(inout(string)[] value) inout pure {
        this.value = value;
    }

    this(inout(string) value) inout pure {
        this([value]);
    }

}

struct SrcDirs {
    string[] value;

    this(inout(string)[] value) inout pure {
        this.value = value;
    }

    this(inout(string) value) inout pure {
        this([value]);
    }

}

struct SrcFiles {
    string[] value;

    this(inout(string)[] value) inout pure {
        this.value = value;
    }

    this(inout(string) value) inout pure {
        this([value]);
    }

}

struct ExcludeFiles {
    string[] value;

    this(inout(string)[] value) inout pure {
        this.value = value;
    }

    this(inout(string) value) inout pure {
        this([value]);
    }

}

struct ExeName {
    string value;
}

struct TargetName {
    string value;
}

enum Backend {
    none,
    make,
    ninja,
    tup,
    binary,
}


struct Dirs {
    string[] value = ["."];

    this(inout(string)[] value) inout pure {
        this.value = value;
    }

    this(inout(string) value) inout pure {
        this([value]);
    }
}

struct Files {
    string[] value;

    this(inout(string)[] value) inout pure {
        this.value = value;
    }

    this(inout(string) value) inout pure {
        this([value]);
    }
}

struct Filter(alias F) {
    alias func = F;
}

auto Sources(Files files, F = Filter!(a => true))() {
    return Sources!(Dirs(), files, F)();
}

auto Sources(string dir, Files files = Files(), F = Filter!(a => true))() {
    return Sources!([dir], files, F)();
}

auto Sources(string[] dirs, Files files = Files(), F = Filter!(a => true))() {
    return Sources!(Dirs(dirs), files, F)();
}

auto Sources(Dirs dirs = Dirs(), Files files = Files(), F = Filter!(a => true))() {
    return SourcesImpl!(F.func)(dirs, files);
}

struct SourceFile {
    string value;
}

struct SourcesImpl(alias F) {
    Dirs dirs;
    Files files;
    Filter!F filter;

    alias filterFunc = F;
}

struct ProjectDir {
    string value = "$project";
}
