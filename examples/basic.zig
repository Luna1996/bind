const std = @import("std");
const Bind = @import("bind").Bind;

const A = struct {
  x: usize,
  pub fn t(self: *const A) usize {
    return self.x + 1;
  }
};

const I = Bind(struct {
  f: fn() usize,
}, .{});

pub fn main() !void {
  const a = A { .x = 3 };
  const ai = I.init(&a, .{.f = A.t});
  const t1 = try std.time.Instant.now();
  for (0..1000000) |_| _ = a.t();
  const t2 = try std.time.Instant.now();
  for (0..1000000) |_| _ = ai.call("f", .{});
  const t3 = try std.time.Instant.now();
  const f = ai.getBindFn("f");
  for (0..1000000) |_| _ = f(ai.context);
  const t4 = try std.time.Instant.now();
  std.debug.print("1,000,000 function call test:\n  direct call: {d: >8} ns\nindirect call: {d: >8} ns\n   proxy call: {d: >8} ns\n", .{t2.since(t1), t4.since(t3), t3.since(t2)});
}