// Flight-test for systems-ide's Zig IDE tier. Mirrors flight-tests/rust's
// shape: a small program with a struct, a method, and a deliberately
// commented-out syntax error for exercising diagnostics.
//
// The commented-out line below is a syntax error (missing semicolon).
// `zig ast-check` (Doom's own zig flycheck checker, see config.el's
// `+zig-common-config`) only validates AST shape, not semantics -- but
// confirmed live that this checker is never actually the one that runs:
// `flycheck-get-checker-for-buffer` reports `lsp`, not `zig`, whenever
// +lsp is active (same checker-priority-contest shape as ruby-lsp-ls vs
// rubocop-ls elsewhere in this project). zls's own LSP diagnostics win
// instead, and those cover semantics too -- confirmed live that both this
// syntax error and a genuine type error (e.g. an unused local, which Zig
// treats as a compile error) both surface correctly through `SPC b c`.
const std = @import("std");
const counter = @import("counter.zig");

pub fn main() void {
    const message = "Hello";
    std.debug.print("{s}\n", .{message});

    var c = counter.Counter{ .n = 0, .name = "test" };
    c.inc();
    std.debug.print("Counter{{ .n = {d}, .name = \"{s}\" }}\n", .{ c.n, c.name });

    // const bad = 5 // uncomment to trigger an ast-check/flycheck diagnostic (missing semicolon)

    for (0..10) |i| {
        std.debug.print("{d}\n", .{i});
    }
}
