const std = @import("std");
const Bind = @import("bind").Bind;

const A = struct {
  x: usize,
  pub fn f(self: *const A) usize {
    return self.x + 1;
  }
};

const B = struct {
  pub fn f() usize {
    return 1;
  }
};

const I = Bind(struct {
  f: fn() usize,
});

pub fn main() !void {
  const a = A { .x = 3 };
  const ai = I.init(&a);
  const bi = I.init(B);
  std.debug.print("{d}, {d}\n", .{ai.call("f", .{}), bi.call("f", .{})});
}