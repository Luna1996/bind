const std = @import("std");

pub fn Bind(comptime Type: type) type {
  return struct {
    const Self = @This();

    const fields = @typeInfo(Type).@"struct".fields;
    const size = fields.len;

    context: usize = 0,
    is_bind: std.bit_set.StaticBitSet(size) = .initEmpty(),
    methods: [size]usize = [_]usize{0} ** size,

    pub fn init(host: anytype) Self {
      var self = Self {};
      const Host: type = if (@TypeOf(host) == type) host else blk: {
        self.context = @intFromPtr(host);
        break :blk std.meta.Child(@TypeOf(host));
      };
      inline for (fields, 0..) |field, i| {
        const name = field.name;
        const method = if (@hasDecl(Host, name)) @field(Host, name) else {};
        if (@TypeOf(method) == void) continue;
        const is_ptr = comptime std.meta.activeTag(@typeInfo(@TypeOf(method))) == .pointer;
        const Method = if (is_ptr) std.meta.Child(@TypeOf(method)) else @TypeOf(method);
        const is_bind = @typeInfo(Method).@"fn".params.len == @typeInfo(BindFn(name)).@"fn".params.len;
        if (is_bind) self.is_bind.set(i);
        self.methods[i] = @intFromPtr(if (is_ptr) method else &method);
      }
      return self;
    }

    pub fn call(self: *const Self, comptime name: []const u8, args: Args(name)) Return(name) {
      const method = self.methods[id(name)];
      if (self.is_bind.isSet(id(name))) {
        const bind_fn: *const BindFn(name) = @ptrFromInt(method);
        if (comptime shouldTry(name)) {
          return try @call(.auto, bind_fn, .{ self.context } ++ args);
        } else {
          return @call(.auto, bind_fn, .{ self.context } ++ args);
        }
      } else {
        const free_fn: *const FreeFn(name) = @ptrFromInt(method);
        if (comptime shouldTry(name)) {
          return try @call(.auto, free_fn, args);
        } else {
          return @call(.auto, free_fn, args);
        }
      }
    }

    pub fn canCall(self: *const Self, comptime name: []const u8) bool {
      return self.methods[id(name)] != 0 and (!self.is_bind.isSet(id(name)) or self.context != 0);
    }

    fn BindFn(comptime name: []const u8) type {
      comptime var info = @typeInfo(FreeFn(name));
      info.@"fn".params = .{std.builtin.Type.Fn.Param{
        .is_generic = false,
        .is_noalias = false,
        .type = usize,
      }} ++ info.@"fn".params;
      return @as(type, @Type(info));
    }

    fn FreeFn(comptime name: []const u8) type {
      return fields[id(name)].type;
    }

    fn Args(comptime name: []const u8) type {
      return @as(type, std.meta.ArgsTuple(FreeFn(name)));
    }

    fn Return(comptime name: []const u8) type {
      return @typeInfo(FreeFn(name)).@"fn".return_type.?;
    }

    fn shouldTry(comptime name: []const u8) bool {
      return std.meta.activeTag(@typeInfo(Return(name))) == .error_union;
    }

    fn id(comptime name: []const u8) comptime_int {
      return std.meta.fieldIndex(Type, name).?;
    }
  };
}