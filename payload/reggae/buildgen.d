/**
 This module implements the binary that is used to generate the build
 in the case of the make, ninja and tup backends, i.e. it translates
 D code into the respective output.

 For the binary target this module implements the binary that actually
 performs the build
 */
module reggae.buildgen;

import reggae.build: Build;
import reggae.options: Options;


version(unittest) {
    void doBuildFor(alias module_ = "reggaefile")(in Options options, string[] buildgenArgs) {
        doBuildForImpl!module_(options, buildgenArgs);
    }
} else
      alias doBuildFor = doBuildForImpl;

private void doBuildForImpl(alias module_ = "reggaefile")(in Options options, string[] buildgenArgs) {
    auto build = getBuildObject!module_(options);
    doBuild(build, options, buildgenArgs);
}

Build getBuildObject(alias module_)(in Options options) {
    alias buildFunc = getBuildFunc!module_;
    static if(is(buildFunc == void))
        throw new Exception("No `Build reggaeBuild()` function in " ~ module_);
    else
        return getBuildObjectImpl!module_(options);
}

// calls the build function or loads it from the cache and returns
// the Build object
private Build getBuildObjectImpl(alias module_)(in Options options) {
    import reggae.path: buildPath;
    import std.file: exists, timeLastModified, thisExePath;
    import std.stdio: File;

    immutable cacheFileName = buildPath(".reggae", "cache");
    if(!options.cacheBuildInfo ||
       !cacheFileName.exists ||
        thisExePath.timeLastModified > cacheFileName.timeLastModified) {
        alias buildFunc = getBuildFunc!module_;
        auto build = buildFunc(); //actually call the function to get the build description

        if(options.cacheBuildInfo) {
            auto file = File(cacheFileName, "w");
            file.rawWrite(build.toBytes(options));
        }

        return build;
    } else {
        auto file = File(cacheFileName);
        auto buffer = new ubyte[cast(size_t) file.size];
        return Build.fromBytes(file.rawRead(buffer));
    }
}

private template getBuildFunc(alias module_) {
    static if(is(typeof(module_) == string)) {
        mixin(`static import `, module_, `;`);
        alias getBuildFunc = getBuildFunc!(mixin(module_));
    } else { // it's a module, not a string
        static if(__traits(hasMember, module_, "reggaeBuild"))
            alias getBuildFunc = module_.reggaeBuild;
        else
            alias getBuildFunc = void;
    }

}

// Exports / does the build (binary backend) / produces the build file(s) (make, ninja, tup)
// `buildgenArgs` is for the binary build, and only when called by the user, i.e. when there's
// a `build` binary to ball in the 1st place
void doBuild(Build build, in Options options, string[] buildgenArgs) {
    if(!options.noCompilationDB) writeCompilationDB(build, options);
    options.export_ ? exportBuild(build, options) : doOneBuild(build, options, buildgenArgs);
}


// `buildgenArgs` is for the binary build, and only when called by the user, i.e. when there's
// a `build` binary to ball in the 1st place
private void doOneBuild(Build build, in Options options, string[] buildgenArgs) {
    import reggae.types: Backend;
    import reggae.backend;

    final switch(options.backend) with(Backend) {

        version(minimal) {
            import std.conv;

            case make:
            case ninja:
            case tup:
                throw new Exception(text("Support for ", options.backend, " not compiled in"));
        } else {

            case make:
                Makefile(build, options).writeBuild;
                break;

            case ninja:
                Ninja(build, options).writeBuild;
                break;

            case tup:
                Tup(build, options).writeBuild;
                break;
        }

        case binary:
            Binary(build, options).run(buildgenArgs);
            break;

        case none:
            throw new Exception("A backend must be specified with -b/--backend");
        }
}

private void exportBuild(Build build, in Options options) {
    import reggae.types: Backend;
    import reggae.backend;
    import std.exception;
    import std.meta;

    enforce(options.backend == Backend.none, "Cannot specify a backend and export at the same time");

    version(minimal)
        throw new Exception("export not supported in minimal version");
    else
        foreach(B; AliasSeq!(Makefile, Ninja, Tup))
            B(build, options).writeBuild;
}


private void writeCompilationDB(Build build, in Options options) {
    import reggae.path: buildPath;
    import reggae.build: Target;
    import std.file;
    import std.conv;
    import std.algorithm;
    import std.string;
    import std.path: dirSeparator;
    import std.stdio: File;

    auto file = File(buildPath(options.workingDir, "compile_commands.json"), "w");
    file.writeln("[");

    enum objPathPrefix = "objs" ~ dirSeparator;

    immutable cwd = getcwd;
    string entry(Target target) {
        auto command = target
            .shellCommand(options)
            .replace(`"`, `\"`)
            .split(" ")
            .map!(a => a.startsWith(objPathPrefix) ? buildPath(options.workingDir, a) : a)
            .join(" ")
        ;
        return
            "    {\n" ~
            text(`        "directory": "`, cwd, `"`) ~ ",\n" ~
            text(`        "command": "`, command, `"`) ~ ",\n" ~
            text(`        "file": "`, target.dependenciesInProjectPath(options.projectPath).join(" "), `"`) ~ "\n" ~
            "    }";
    }

    file.write(build.range.map!(a => entry(a)).join(",\n"));
    file.writeln;
    file.writeln("]");
}
