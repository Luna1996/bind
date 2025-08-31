const std = @import("std");

pub fn Bind(comptime Type: type, comptime conf: struct {
  is_bind: enum {bind, auto, none} = .bind,
}) type {
  return struct {
    const Self = @This();

    const fields = @typeInfo(Type).@"struct".fields;
    const size = fields.len;

    context: usize = 0,
    methods: [size]usize = [_]usize{0} ** size,
    is_bind: if (conf.is_bind == .auto) std.bit_set.StaticBitSet(size) else void = 
             if (conf.is_bind == .auto) .initEmpty()                   else {},

    pub fn init(host: anytype, alias: anytype) Self {
      var self = Self {};
      const Host: type = if (@TypeOf(host) == type) host else blk: {
        self.context = @intFromPtr(host);
        break :blk std.meta.Child(@TypeOf(host));
      };
      inline for (fields, 0..) |field, i| {
        const name = field.name;
        const method =
          if (@hasField(@TypeOf(alias), name))
            @field(alias, name)
          else if (@hasDecl(Host, name))
            @field(Host, name)
          else
            {};
        if (@TypeOf(method) == void) continue;
        const is_ptr = comptime std.meta.activeTag(@typeInfo(@TypeOf(method))) == .pointer;
        self.methods[i] = @intFromPtr(if (is_ptr) method else &method);

        if (comptime conf.is_bind == .auto) {
          const Method = if (is_ptr) std.meta.Child(@TypeOf(method)) else @TypeOf(method);
          const is_bind = @typeInfo(Method).@"fn".params.len == @typeInfo(BindFn(name)).@"fn".params.len;
          if (is_bind) self.is_bind.set(i);
        }
      }
      return self;
    }

    pub fn call(self: *const Self, comptime name: []const u8, args: Args(name)) Return(name) {
      const method = self.methods[id(name)];
      switch (comptime conf.is_bind) {
        .bind => {
          const bind_fn: *const BindFn(name) = @ptrFromInt(method);
          return if (comptime shouldTry(name))
            try @call(.auto, bind_fn, .{ self.context } ++ args)
          else  @call(.auto, bind_fn, .{ self.context } ++ args);
        },
        .none => {
          const free_fn: *const FreeFn(name) = @ptrFromInt(method);
          return if (comptime shouldTry(name))
            try @call(.auto, free_fn, args)
          else  @call(.auto, free_fn, args);
        },
        .auto => if (self.is_bind.isSet(id(name))) {
          const bind_fn: *const BindFn(name) = @ptrFromInt(method);
          return if (comptime shouldTry(name))
            try @call(.auto, bind_fn, .{ self.context } ++ args)
          else  @call(.auto, bind_fn, .{ self.context } ++ args);
        } else {
          const free_fn: *const FreeFn(name) = @ptrFromInt(method);
          return if (comptime shouldTry(name))
            try @call(.auto, free_fn, args)
          else  @call(.auto, free_fn, args);
        },
      }
    }

    pub fn canCall(self: *const Self, comptime name: []const u8) bool {
      return self.methods[id(name)] != 0;
    }

    pub fn getBindFn(self: *const Self, comptime name: []const u8) *const BindFn(name) {
      return @ptrFromInt(self.methods[id(name)]);
    }

    pub fn getFreeFn(self: *const Self, comptime name: []const u8) *const FreeFn(name) {
      return @ptrFromInt(self.methods[id(name)]);
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