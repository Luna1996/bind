const std = @import("std");

pub fn Bind(comptime body: anytype, comptime kind: enum {bind, auto, none}) type {
  return struct {
    const Self = @This();

    const type_map = getTypeMap();
    const type_len = type_map.kvs.len;

    context: usize = 0,
    methods: Methods() = .{},
    is_bind: if (kind == .auto) std.bit_set.StaticBitSet(type_len) else void = 
             if (kind == .auto) .initEmpty()                       else {},

    pub fn init(host: anytype, alias: anytype) Self {
      var self = Self {};
      const Host: type = if (@TypeOf(host) == type) host else blk: {
        self.context = @intFromPtr(host);
        break :blk std.meta.Child(@TypeOf(host));
      };
      inline for (type_map.keys()) |name| {
        const method = if (@hasField(@TypeOf(alias), name)) @field(alias, name)
                       else if (@hasDecl(Host, name))       @field(Host, name)
                       else                                 {};
        if (@TypeOf(method) == void) continue;
        const is_ptr = comptime std.meta.activeTag(@typeInfo(@TypeOf(method))) == .pointer;
        self.methods[i] = @intFromPtr(if (is_ptr) method else &method);

        if (comptime conf.kind == .auto) {
          const Method = if (is_ptr) std.meta.Child(@TypeOf(method)) else @TypeOf(method);
          const is_bind = @typeInfo(Method).@"fn".params.len == @typeInfo(BindFn(name)).@"fn".params.len;
          if (is_bind) self.is_bind.set(i);
        }
      }
      return self;
    }

    pub fn call(self: *const Self, comptime name: []const u8, args: Args(name)) Return(name) {
      const method = self.methods[id(name)];
      switch (comptime conf.kind) {
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

    fn getTypeMap() std.StaticStringMap(type) {
      const fields = @typeInfo(@TypeOf(body)).@"struct".fields;
      comptime var kv_list: [fields.len]std.meta.Tuple(&.{[]const u8, type}) = undefined;
      inline for (fields, 0..) |field, i| {
        kv_list[i] = .{field.name, @field(body, field.name)};
      }
      return .initComptime(kv_list);
    }

    fn BindFn(comptime name: []const u8) type {
      const info = @typeInfo(FreeFn(name)).@"fn";
      comptime var param_types: [info.params.len + 1]type = undefined;
      comptime var param_attrs: [info.params.len + 1]std.builtin.Type.Fn.Param.Attributes = undefined;
      param_types[0] = usize;
      param_attrs[0] = .{};
      inline for (info.params, 1..) |param, i| {
        param_types[i] = param.type;
        param_attrs[i] = .{ .@"noalias" = param.is_noalias };
      }
      return @Fn(&param_types, &param_attrs, info.return_type orelse void, .{
        .@"callconv" = info.calling_convention,
        .varargs = info.is_var_args,
      });
    }

    fn FreeFn(comptime name: []const u8) type {
      return fields[id(name)].type;
    }

    fn Args(comptime name: []const u8) type {
      return std.meta.ArgsTuple(FreeFn(name));
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