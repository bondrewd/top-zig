// Modules
const std = @import("std");
const mem = std.mem;
const testing = std.testing;
// Functions
const trim = mem.trim;
const indexOf = mem.indexOf;
const startsWith = mem.startsWith;

pub fn getDirectiveName(line: []const u8) ![]const u8 {
    // Remove comment
    const semicolon = if (indexOf(u8, line, ";")) |index| index else line.len;
    const directive = line[0..semicolon];
    // Get delimiter indexes
    const i = if (indexOf(u8, directive, "[")) |index| index else return error.MissingDelimiter;
    const j = if (indexOf(u8, directive, "]")) |index| index else return error.MissingDelimiter;
    // Extract name
    const name = trim(u8, directive[i + 1 .. j], " ");
    // Check name is not empty
    if (name.len == 0) return error.MissingDirectiveName;
    // Check name does not contains blanks
    if (indexOf(u8, name, " ") != null) return error.InvalidDirectiveName;

    return name;
}

pub fn getIncludePath(line: []const u8) ![]const u8 {
    // Remove comment
    const semicolon = if (indexOf(u8, line, ";")) |index| index else line.len;
    const include = line[0..semicolon];
    // Check keyword is present
    if (!startsWith(u8, include, "#include")) return error.MissingKeyword;
    // Get delimiter index
    const i = if (indexOf(u8, include, "\"")) |index| index else return error.MissingDelimiter;
    const j = if (indexOf(u8, include[i + 1 ..], "\"")) |index| index + i + 1 else return error.MissingDelimiter;
    // Extract path
    const path = trim(u8, include[i + 1 .. j], " ");
    // Check path is not empty
    if (path.len == 0) return error.MissingPath;
    // Check path does not contains blanks
    if (indexOf(u8, path, " ") != null) return error.InvalidPath;

    return path;
}

test "getDirectiveName" {
    const directive1 = "[ foo ]";
    try testing.expectEqualSlices(u8, "foo", try getDirectiveName(directive1));

    const directive2 = "      [     foo ] ";
    try testing.expectEqualSlices(u8, "foo", try getDirectiveName(directive2));

    const directive3 = "[foo]";
    try testing.expectEqualSlices(u8, "foo", try getDirectiveName(directive3));

    const directive4 = " [ foo ] ; comment";
    try testing.expectEqualSlices(u8, "foo", try getDirectiveName(directive4));

    const bad1 = "";
    try testing.expectError(error.MissingDelimiter, getDirectiveName(bad1));

    const bad2 = "[ foo ";
    try testing.expectError(error.MissingDelimiter, getDirectiveName(bad2));

    const bad3 = " foo ]";
    try testing.expectError(error.MissingDelimiter, getDirectiveName(bad3));

    const bad4 = " foo ";
    try testing.expectError(error.MissingDelimiter, getDirectiveName(bad4));

    const bad5 = "; comment";
    try testing.expectError(error.MissingDelimiter, getDirectiveName(bad5));

    const bad6 = ";[ foo ]";
    try testing.expectError(error.MissingDelimiter, getDirectiveName(bad6));

    const bad7 = "[]";
    try testing.expectError(error.MissingDirectiveName, getDirectiveName(bad7));

    const bad8 = "[    ]";
    try testing.expectError(error.MissingDirectiveName, getDirectiveName(bad8));

    const bad9 = "[ f o o ]";
    try testing.expectError(error.InvalidDirectiveName, getDirectiveName(bad9));
}

test "getIncludePath" {
    const include1 = "#include \"/home/foo\"";
    try testing.expectEqualSlices(u8, "/home/foo", try getIncludePath(include1));

    const include2 = "#include     \"/home/foo\"";
    try testing.expectEqualSlices(u8, "/home/foo", try getIncludePath(include2));

    const include3 = "#include \"/home/foo\" ; comment";
    try testing.expectEqualSlices(u8, "/home/foo", try getIncludePath(include3));

    const bad1 = "";
    try testing.expectError(error.MissingKeyword, getIncludePath(bad1));

    const bad2 = "; comment";
    try testing.expectError(error.MissingKeyword, getIncludePath(bad2));

    const bad3 = ";#include";
    try testing.expectError(error.MissingKeyword, getIncludePath(bad3));

    const bad4 = "#include /home/foo";
    try testing.expectError(error.MissingDelimiter, getIncludePath(bad4));

    const bad5 = "#include \"/home/foo";
    try testing.expectError(error.MissingDelimiter, getIncludePath(bad5));

    const bad6 = "#include /home/foo\"";
    try testing.expectError(error.MissingDelimiter, getIncludePath(bad6));

    const bad7 = "#include \"\"";
    try testing.expectError(error.MissingPath, getIncludePath(bad7));

    const bad8 = "#include \"          \"";
    try testing.expectError(error.MissingPath, getIncludePath(bad8));

    const bad9 = "#include \"/ home / foo \"";
    try testing.expectError(error.InvalidPath, getIncludePath(bad9));
}
