// Modules
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const testing = std.testing;
// Types
const File = fs.File;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
// Functions
const eql = mem.eql;
const copy = mem.copy;
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

pub fn isDirective(line: []const u8) bool {
    // Remove comment
    const semicolon = if (indexOf(u8, line, ";")) |index| index else line.len;
    const directive = line[0..semicolon];
    // Get delimiter indexes
    const i = if (indexOf(u8, directive, "[")) |index| index else return false;
    const j = if (indexOf(u8, directive, "]")) |index| index else return false;
    // Extract name
    const name = trim(u8, directive[i + 1 .. j], " ");
    // Check name is not empty
    if (name.len == 0) return false;
    // Check name does not contains blanks
    if (indexOf(u8, name, " ") != null) return false;

    return true;
}

pub fn getDirectiveLines(file: File, directive: []const u8, allocator: Allocator) ![][]const u8 {
    // Initialize list
    var directive_lines = ArrayList([]const u8).init(allocator);
    // Initialize buffer
    var buffer = [_]u8{0} ** 1000;
    // File position
    var pos = try file.getPos();
    // Get file reader
    const reader = file.reader();

    // Read until the directive is found
    while (try reader.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
        const found_directive = getDirectiveName(line) catch continue;
        if (eql(u8, directive, found_directive)) break;
        // Update position
        pos = try file.getPos();
    }

    // Save lines
    while (try reader.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
        // Stop if a new directive is found
        if (isDirective(line)) break;
        // Remove comment
        const semicolon = if (indexOf(u8, line, ";")) |index| index else line.len;
        const content = line[0..semicolon];
        // Skip if line is empty
        if (content.len == 0) continue;
        // Save content
        var directive_line = try allocator.alloc(u8, content.len);
        copy(u8, directive_line, content);
        try directive_lines.append(directive_line);
        // Update position
        pos = try file.getPos();
    }

    // Position file before directive block ends
    try file.seekTo(pos);

    return directive_lines.toOwnedSlice();
}

test "Top getDirectiveName" {
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

test "Top getIncludePath" {
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

test "Top getDirectiveLines" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const handle = tmp.dir;

    var top = try handle.createFile("tmp.top", .{ .read = true });
    defer top.close();

    const w = top.writer();
    try w.print("{s}", .{
        \\[ foo ]
        \\a
        \\b
        \\c
    });

    try top.seekTo(0);

    const lines = try getDirectiveLines(top, "foo", testing.allocator);
    defer testing.allocator.free(lines);
    defer for (lines) |line| testing.allocator.free(line);

    try testing.expect(lines.len == 3);
    try testing.expectEqualSlices(u8, lines[0], "a"[0..]);
    try testing.expectEqualSlices(u8, lines[1], "b"[0..]);
    try testing.expectEqualSlices(u8, lines[2], "c"[0..]);
}
