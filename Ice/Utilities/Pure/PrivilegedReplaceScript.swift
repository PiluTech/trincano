//
//  PrivilegedReplaceScript.swift
//  Ice
//

/// Builds the shell script that replaces the installed app as administrator.
///
/// The destination checks live INSIDE the script, right before `rm`/`ditto`,
/// so they run in the same privileged process as the replacement. The
/// password prompt happens when the script starts, which makes any check done
/// earlier in the app stale; these ones cannot be. A small window between
/// the last check and `rm` remains, but it is a few shell commands wide.
///
/// The new copy is first built in a hidden sibling folder (same volume), and
/// only after the checks does `rm` + `mv` (a rename) swap it in, so a failed
/// `ditto` never leaves the destination without the app.
///
/// Exit codes of the checks are those of `ReplacementTargetPlan.Verdict`.
enum PrivilegedReplaceScript {
    static func build(source: String, destination: String, expectedBundleIdentifier: String) -> String {
        let plistBuddy = "/usr/libexec/PlistBuddy"
        let symlink = ReplacementTargetPlan.Verdict.refusedSymlink.scriptExitCode ?? 1
        let otherApp = ReplacementTargetPlan.Verdict.refusedOtherApp.scriptExitCode ?? 1
        let partial = ReplacementTargetPlan.Verdict.refusedIncompleteBundle.scriptExitCode ?? 1
        let prepareFailed = 20
        let copyFailed = 21
        // `[ -L ]` comes first: it does not follow the link, and a dangling
        // link would otherwise look like "nothing there".
        return """
        src=\(quoted(source))
        dest=\(quoted(destination))
        tmp=$(/usr/bin/mktemp -d "$(/usr/bin/dirname "$dest")/.trincano-new.XXXXXX") || exit \(prepareFailed)
        trap '/bin/rm -rf "$tmp"' EXIT
        /usr/bin/ditto "$src" "$tmp/app" || exit \(copyFailed)
        if [ -L "$dest" ]; then exit \(symlink); fi
        if [ -e "$dest" ]; then
            plist="$dest/Contents/Info.plist"
            [ -f "$plist" ] || exit \(partial)
            id=$(\(plistBuddy) -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null) || exit \(partial)
            exe=$(\(plistBuddy) -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null) || exit \(partial)
            case "$exe" in ""|*/*) exit \(partial);; esac
            [ -f "$dest/Contents/MacOS/$exe" ] || exit \(partial)
            [ "$id" = \(quoted(expectedBundleIdentifier)) ] || exit \(otherApp)
        fi
        /bin/rm -rf "$dest" && /bin/mv "$tmp/app" "$dest"
        """
    }

    static func quoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
