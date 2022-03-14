// Modules
const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const testing = std.testing;
// Types
const Dir = fs.Dir;
const File = fs.File;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;
// Functions
const eql = mem.eql;
const copy = mem.copy;
const trim = mem.trim;
const split = mem.split;
const indexOf = mem.indexOf;
const tokenize = mem.tokenize;
const startsWith = mem.startsWith;
const parseUnsigned = fmt.parseUnsigned;

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
    if (name.len == 0) return error.MissingToken;
    // Check name does not contains blanks
    if (indexOf(u8, name, " ") != null) return error.InvalidToken;

    return name;
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

const GetDirectiveContentResult = struct {
    data: ?[]const u8,
    pos: usize,
};

pub fn getDirectiveContent(monolith: []const u8, directive: []const u8) !GetDirectiveContentResult {
    // Directive index
    var start: usize = 0;
    var end: usize = 0;
    // Get monolith reader
    var it = split(u8, monolith, "\n");

    // Read lines until the directive is found
    while (it.next()) |line| {
        // Update position
        start += line.len + 1;
        end += line.len + 1;
        // Parse directive
        const found_directive = getDirectiveName(line) catch continue;
        if (eql(u8, directive, found_directive)) break;
    }

    // Read lines unitl next directive
    while (it.next()) |line| {
        // Stop if a new directive is found
        if (isDirective(line)) break;
        // Update position
        end += line.len + 1;
    }

    // If EOF correct for extra \n character counted
    if (it.next() == null) end -= 1;

    return GetDirectiveContentResult{
        .data = if (start == end) null else monolith[start..end],
        .pos = end,
    };
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
    if (path.len == 0) return error.MissingToken;
    // Check path does not contains blanks
    if (indexOf(u8, path, " ") != null) return error.InvalidToken;

    return path;
}

pub fn isIncludePath(line: []const u8) bool {
    // Remove comment
    const semicolon = if (indexOf(u8, line, ";")) |index| index else line.len;
    const include = line[0..semicolon];
    // Check keyword is present
    if (!startsWith(u8, include, "#include")) return false;
    // Get delimiter index
    const i = if (indexOf(u8, include, "\"")) |index| index else return false;
    const j = if (indexOf(u8, include[i + 1 ..], "\"")) |index| index + i + 1 else return false;
    // Extract path
    const path = trim(u8, include[i + 1 .. j], " ");
    // Check path is not empty
    if (path.len == 0) return false;
    // Check path does not contains blanks
    if (indexOf(u8, path, " ") != null) return false;

    return true;
}

pub fn getDefineString(line: []const u8) ![]const u8 {
    // Remove comment
    const semicolon = if (indexOf(u8, line, ";")) |index| index else line.len;
    const define = line[0..semicolon];
    // Check keyword is present
    if (!startsWith(u8, define, "#define")) return error.MissingKeyword;
    // Get delimiter index
    const i = if (indexOf(u8, define, " ")) |index| index else return error.MissingSeparator;
    // Extract path
    const string = trim(u8, define[i..], " ");
    // Check path is not empty
    if (string.len == 0) return error.MissingToken;
    // Check path does not contains blanks
    if (indexOf(u8, string, " ") != null) return error.InvalidToken;

    return string;
}

pub fn isDefineString(line: []const u8) bool {
    // Remove comment
    const semicolon = if (indexOf(u8, line, ";")) |index| index else line.len;
    const define = line[0..semicolon];
    // Check keyword is present
    if (!startsWith(u8, define, "#define")) return false;
    // Get delimiter index
    const i = if (indexOf(u8, define, " ")) |index| index else return false;
    // Extract path
    const string = trim(u8, define[i..], " ");
    // Check path is not empty
    if (string.len == 0) return false;
    // Check path does not contains blanks
    if (indexOf(u8, string, " ") != null) return false;

    return true;
}

pub fn writeMonolith(writer: anytype, dir: Dir, file_name: []const u8, allocator: Allocator) anyerror!void {
    // Reading buffer
    var buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(buffer);
    // Open file
    var file = try dir.openFile(file_name, .{});
    // File reader
    var reader = file.reader();

    // Read until the directive is found
    while (try reader.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
        // Remove comment
        const semicolon = if (indexOf(u8, line, ";")) |index| index else line.len;
        const content_line = line[0..semicolon];
        // Trim content
        const content = trim(u8, content_line, " ");
        // Skip if line is empty
        if (content.len == 0) continue;
        // Write content
        if (isIncludePath(content)) {
            // Get path
            const path = try getIncludePath(content);
            // Write recursively
            try writeMonolith(writer, dir, path, allocator);
        } else {
            try writer.print("{s}\n", .{content});
        }
    }
}

pub fn createMonolith(dir: Dir, file_name: []const u8, allocator: Allocator) anyerror![]u8 {
    // Initialize monolith
    var monolith = ArrayList(u8).init(allocator);
    // Create monolith
    try writeMonolith(monolith.writer(), dir, file_name, allocator);

    return monolith.toOwnedSlice();
}

pub const SystemDirective = struct {
    allocator: Allocator,
    name: []u8,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .name = undefined,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
    }

    pub fn setName(self: *Self, name: []const u8) !void {
        self.name = try self.allocator.alloc(u8, name.len);
        copy(u8, self.name, name);
    }

    pub fn parseMonolith(self: *Self, monolith: []const u8) !void {
        const content = try getDirectiveContent(monolith, "system");
        const data = if (content.data) |data| data else "";
        const name = trim(u8, data, "\n");
        try self.setName(name);
    }
};

pub const MoleculesDirective = struct {
    allocator: Allocator,
    molecules: std.StringArrayHashMap(u64),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .molecules = StringArrayHashMap(u64).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.molecules.deinit();
    }

    pub fn addMolecule(self: *Self, name: []const u8, number: u64) !void {
        try self.molecules.putNoClobber(name, number);
    }

    pub fn parseMonolith(self: *Self, monolith: []const u8) !void {
        const content = try getDirectiveContent(monolith, "molecules");
        const data = if (content.data) |data| data else return;

        var lines = tokenize(u8, data, "\n");
        while (lines.next()) |line| {
            var tokens = tokenize(u8, line, " ");
            const name = tokens.next().?;
            const number = try parseUnsigned(u64, tokens.next().?, 10);
            if (tokens.next() != null) return error.UnexpectedToken;
            try self.addMolecule(name, number);
        }
    }
};

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
    try testing.expectError(error.MissingToken, getDirectiveName(bad7));

    const bad8 = "[    ]";
    try testing.expectError(error.MissingToken, getDirectiveName(bad8));

    const bad9 = "[ f o o ]";
    try testing.expectError(error.InvalidToken, getDirectiveName(bad9));
}

test "Top getDirectiveContent" {
    const monolith =
        \\[ foo ]
        \\a
        \\
        \\b 1.23
        \\[ bar ]
        \\[ baz ]
        \\c
        \\
    ;

    var content = try getDirectiveContent(monolith, "foo");

    try testing.expectEqual(@as(usize, 18), content.pos);
    try testing.expect(content.data != null);

    var lines = tokenize(u8, content.data.?, "\n");
    try testing.expectEqualSlices(u8, lines.next().?, "a"[0..]);
    try testing.expectEqualSlices(u8, lines.next().?, "b 1.23"[0..]);
    try testing.expect(lines.next() == null);

    content = try getDirectiveContent(monolith, "bar");

    try testing.expectEqual(@as(usize, 26), content.pos);
    try testing.expect(content.data == null);

    content = try getDirectiveContent(monolith, "baz");

    try testing.expectEqual(@as(usize, 36), content.pos);
    try testing.expect(content.data != null);

    lines = tokenize(u8, content.data.?, "\n");
    try testing.expectEqualSlices(u8, lines.next().?, "c"[0..]);
    try testing.expect(lines.next() == null);
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
    try testing.expectError(error.MissingToken, getIncludePath(bad7));

    const bad8 = "#include \"          \"";
    try testing.expectError(error.MissingToken, getIncludePath(bad8));

    const bad9 = "#include \"/ home / foo \"";
    try testing.expectError(error.InvalidToken, getIncludePath(bad9));
}

test "Top getDefineString" {
    const define1 = "#define foo";
    try testing.expectEqualSlices(u8, "foo", try getDefineString(define1));

    const define2 = "#define     foo      ";
    try testing.expectEqualSlices(u8, "foo", try getDefineString(define2));

    const define3 = "#define foo ; with comment";
    try testing.expectEqualSlices(u8, "foo", try getDefineString(define3));

    const bad1 = "";
    try testing.expectError(error.MissingKeyword, getDefineString(bad1));

    const bad2 = "; comment";
    try testing.expectError(error.MissingKeyword, getDefineString(bad2));

    const bad3 = ";#define";
    try testing.expectError(error.MissingKeyword, getDefineString(bad3));

    const bad4 = "#definefoo";
    try testing.expectError(error.MissingSeparator, getDefineString(bad4));

    const bad5 = "#define";
    try testing.expectError(error.MissingSeparator, getDefineString(bad5));

    const bad6 = "#define          ";
    try testing.expectError(error.MissingToken, getDefineString(bad6));

    const bad7 = "#define ; foo";
    try testing.expectError(error.MissingToken, getDefineString(bad7));

    const bad8 = "#define f o o";
    try testing.expectError(error.InvalidToken, getDefineString(bad8));
}

test "Top writeMonolith" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const handle = tmp.dir;

    var top = try handle.createFile("tmp.top", .{ .read = true });
    defer top.close();

    try top.writer().writeAll(
        \\[ foo ]
        \\a
        \\
        \\b 1.23
        \\; comment 1
        \\
        \\c 1.0 1.0
        \\
        \\[ bar ]
        \\d
        \\e ; with extra comment
        \\; comment 2
        \\
    );

    try top.seekTo(0);

    var monolith = ArrayList(u8).init(testing.allocator);
    defer monolith.deinit();

    try writeMonolith(monolith.writer(), handle, "tmp.top", testing.allocator);

    try testing.expectEqualStrings(
        \\[ foo ]
        \\a
        \\b 1.23
        \\c 1.0 1.0
        \\[ bar ]
        \\d
        \\e
        \\
    , monolith.items);
}

test "Top writeMonolith with include path" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const handle = tmp.dir;

    var itp1 = try handle.createFile("tmp1.itp", .{ .read = true });
    defer itp1.close();

    try itp1.writer().writeAll(
        \\; comment
        \\[ foo ]
        \\a
        \\b
        \\
        \\; final comment
        \\
    );

    try itp1.seekTo(0);

    var itp2 = try handle.createFile("tmp2.itp", .{ .read = true });
    defer itp2.close();

    try itp2.writer().writeAll(
        \\; comment
        \\[ baz ]
        \\e
        \\f
        \\; comment for the next line
        \\g
        \\
    );

    try itp2.seekTo(0);

    var top = try handle.createFile("tmp.top", .{ .read = true });
    defer top.close();

    try top.writer().writeAll(
        \\; comment
        \\#include "./tmp1.itp"
        \\
        \\; comment
        \\[ bar ]
        \\c
        \\
        \\d
        \\
        \\;comment
        \\#include "./tmp2.itp"
        \\
        \\[ cux ]
        \\h
        \\
    );

    try top.seekTo(0);

    var monolith = ArrayList(u8).init(testing.allocator);
    defer monolith.deinit();

    try writeMonolith(monolith.writer(), handle, "tmp.top", testing.allocator);

    try testing.expectEqualStrings(
        \\[ foo ]
        \\a
        \\b
        \\[ bar ]
        \\c
        \\d
        \\[ baz ]
        \\e
        \\f
        \\g
        \\[ cux ]
        \\h
        \\
    , monolith.items);
}

test "Top createMonolith" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const handle = tmp.dir;

    var itp = try handle.createFile("tmp.itp", .{ .read = true });
    defer itp.close();

    try itp.writer().writeAll(
        \\[ foo ]
        \\a
        \\b
        \\c
        \\
    );

    try itp.seekTo(0);

    var top = try handle.createFile("tmp.top", .{ .read = true });
    defer top.close();

    try top.writer().writeAll(
        \\#include "./tmp.itp"
        \\[ bar ]
        \\d
        \\e
        \\
    );

    try top.seekTo(0);

    var monolith = try createMonolith(handle, "tmp.top", testing.allocator);
    defer testing.allocator.free(monolith);

    try testing.expectEqualStrings(
        \\[ foo ]
        \\a
        \\b
        \\c
        \\[ bar ]
        \\d
        \\e
        \\
    , monolith);
}

test "Top SystemDirective" {
    var system_directive = SystemDirective.init(testing.allocator);
    defer system_directive.deinit();

    const monolith =
        \\[ system ]
        \\POPC membrane
        \\
    ;

    try system_directive.parseMonolith(monolith);
    try testing.expectEqualStrings(system_directive.name, "POPC membrane");
}

test "Top MoleculesDirective" {
    var molecules_directive = MoleculesDirective.init(testing.allocator);
    defer molecules_directive.deinit();

    const monolith =
        \\[ molecules ]
        \\foo 1
        \\bar 2
        \\baz 3
        \\
    ;

    try molecules_directive.parseMonolith(monolith);

    var it = molecules_directive.molecules.iterator();

    var mol1 = it.next().?;
    try testing.expectEqualStrings("foo", mol1.key_ptr.*);
    try testing.expectEqual(@as(u64, 1), mol1.value_ptr.*);

    var mol2 = it.next().?;
    try testing.expectEqualStrings("bar", mol2.key_ptr.*);
    try testing.expectEqual(@as(u64, 2), mol2.value_ptr.*);

    var mol3 = it.next().?;
    try testing.expectEqualStrings("baz", mol3.key_ptr.*);
    try testing.expectEqual(@as(u64, 3), mol3.value_ptr.*);

    try testing.expect(it.next() == null);
}

test "Top MoleculesDirective return error.UnexpectedToken" {
    var molecules_directive = MoleculesDirective.init(testing.allocator);
    defer molecules_directive.deinit();

    const monolith =
        \\[ molecules ]
        \\foo 1
        \\bar 2 bad
        \\baz 3
        \\
    ;

    const err = molecules_directive.parseMonolith(monolith);
    try testing.expectError(error.UnexpectedToken, err);
}
