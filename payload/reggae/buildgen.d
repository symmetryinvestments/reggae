/**
 This module implements the binary that is used to generate the build
 in the case of the make, ninja and tup backends, i.e. it translates
 D code into the respective output.

 For the binary target this module implements the binary that actually
 performs the build
 */
module reggae.buildgen;

import reggae.build;
import reggae.options;
import reggae.types;
import reggae.backend;
import reggae.path: buildPath;

import std.stdio;
import std.file: timeLastModified;

/**
 Creates a build generator out of a module and a list of top-level targets.
 This will define a function with the signature $(D Build buildFunc()) in
 the calling module and a $(D main) entry point function for a command-line
 executable.
 */
mixin template buildGen(string buildModule, targets...) {
    mixin buildImpl!targets;
    mixin BuildGenMain!buildModule;
}

mixin template BuildGenMain(string buildModule = "reggaefile") {
    import std.stdio;

    // args is empty except for the binary backend,
    // in which case it's used for runtime options
    int main(string[] args) {
        try {
            import reggae.config: options;
            doBuildFor!(buildModule)(options, args); //the user's build description
        } catch(Exception ex) {
            stderr.writeln(ex.msg);
            return 1;
        }

        return 0;
    }
}

void doBuildFor(alias module_ = "reggaefile")(in Options options, string[] args = []) {
    auto build = getBuildObject!module_(options);
    doBuild(build, options, args);
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
    import std.file;

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
void doBuild(Build build, in Options options, string[] args = []) {
    if(!options.noCompilationDB) writeCompilationDB(build, options);
    options.export_ ? exportBuild(build, options) : doOneBuild(build, options, args);
}


private void doOneBuild(Build build, in Options options, string[] args = []) {
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
            Binary(build, options).run(args);
            break;

        case none:
            throw new Exception("A backend must be specified with -b/--backend");
        }
}

private void exportBuild(Build build, in Options options) {
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
    import std.file;
    import std.conv;
    import std.algorithm;
    import std.string;
    import std.path: dirSeparator;

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
