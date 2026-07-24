const std = @import("std");

/// A simple counter, exercising hover docs, go-to-definition, and rename
/// across files (main.zig -> counter.zig).
pub const Counter = struct {
    n: i32,
    name: []const u8,

    pub fn inc(self: *Counter) void {
        self.n += 1;
    }
};

test "increments by one" {
    var c = Counter{ .n = 0, .name = "test" };
    c.inc();
    try std.testing.expectEqual(@as(i32, 1), c.n);
}
