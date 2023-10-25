module reggae.dub.interop.fetch;


import reggae.from;


package void dubFetch(O)(
    auto ref O output,
    in from!"reggae.options".Options options,
    in string dubSelectionsJson)
    @trusted
{
    static import reggae.dub.interop.dublib;
    import reggae.io: log;
    import dub.dub: Dub, FetchOptions;
    import dub.dependency: Version;
    import dub.packagemanager: PlacementLocation;
    import std.array: replace;
    import std.json: parseJSON, JSONType;
    import std.file: readText;
    import std.parallelism: parallel;

    const(VersionedPackage)[] pkgsToFetch;

    const json = parseJSON(readText(dubSelectionsJson));

    auto dublib = reggae.dub.interop.dublib.Dub(options);
    foreach(dubPackageName, versionJson; json["versions"].object) {

        // skip the ones with a defined path
        if(versionJson.type != JSONType.string) continue;

        const version_ = versionJson.str.replace("==", "");
        const pkg = VersionedPackage(dubPackageName, version_);

        if(needDubFetch(dublib, pkg)) pkgsToFetch ~= pkg;
    }

    output.log("Creating dub object");
    auto dubObj = new Dub(dublib.options.projectPath);

    output.log("Fetching dub packages");
    foreach(pkg; pkgsToFetch.parallel) {
        try
            dubObj.fetch(
                pkg.name,
                Version(pkg.version_),
                PlacementLocation.user,
                FetchOptions.none,
            );
        catch (Exception exc)
        {
            import std.stdio;
            stderr.writefln("Fetching package %s %s failed: %s",
                            pkg.name, pkg.version_, exc.message());
            throw exc;
        }
    }
    output.log("Fetched dub packages");
}


private struct VersionedPackage {
    string name;
    string version_;
}


private bool needDubFetch(
    ref from!"reggae.dub.interop.dublib".Dub dub,
    in VersionedPackage pkg)
    @safe
{
    // first check the file system explicitly
    if(pkgExistsOnFS(pkg)) return false;
    // next ask dub (this is slower)
    if(dub.getPackage(pkg.name, pkg.version_)) return false;

    return true;
}


// dub fetch can sometimes take >10s (!) despite the package already being
// on disk
private bool pkgExistsOnFS(in VersionedPackage pkg) @safe {
    import reggae.path: buildPath, dubPackagesDir;
    import std.file: exists;
    import std.string: replace;

    // Some versions include a `+` and that becomes `_` in the path
    const version_ = pkg.version_.replace("+", "_");

    return buildPath(
        dubPackagesDir,
        pkg.name,
        version_,
        pkg.name ~ ".lock"
    ).exists;
}
