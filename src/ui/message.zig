//! Messages are sent to `WNode`s in order to coerce them to do something.
const builtin = @import("builtin");
const std = @import("std");
const area = @import("area.zig");
const WidgetIndex = @import("WidgetManager.zig").WidgetIndex;

pub const Message = SystemMessage;
const message_tag = u16;
// TODO: Revisit the idea of allowing users to define their own message types.
//       I deemed it a bit unwieldy at the moment to be bouncing around these
//       concerns without a PoC.

/// Classifies whether a message is user-defined or library/system-defined.
// pub const Scope = enum {system, user};

/// SystemMessages are the simplest messages a window ought to handle.
/// These messages are copyable.
pub const SystemMessage = union(enum) {
    /// The window ought to come to a stop. This may not be instant (e.g. it may
    /// prompt a user for saving), but it should be expected that
    /// `WNode.VTable.release` will be called soon.
    Deinit: void,
    /// The window requires repainting.
    Repaint: void,
    /// The window has been resized to a new `Area`.
    Resize: area.Bounded,
    /// A Child was added to this node with the corresponding index.
    ChildAdded: WidgetIndex,
    Init: void,

    // /// Convenience function to easily convert to a `SomeMessage`, effectively
    // /// erasing the information that this was a `SystemMessage`.
    // /// Lifetime: must be as long or longer than the resulting `SomeMessage`.
    // pub inline fn erase(self: *SystemMessage) SomeMessage {
    //     return SomeMessage {
    //         .tag = @enumFromInt(@intFromEnum(self)),
    //         .data = self.value(),
    //     };
    // }

    // fn value(self: *SystemMessage) *anyopaque {
    //     return switch (self) {
    //         .Resize =>  @ptrCast(@alignCast(&self.Resize)),
    //         .Init, .Deinit, .Resize => null,
    //     };
    // }

    pub fn subscribedBy(self: SystemMessage, subs: MsgSubscriptions) bool {
        return switch (self) {
            inline else => |_, tag| @field(subs, @tagName(tag))
        };
    }
};

/// Bitfield-like struct that contains each type of message.
pub const MsgSubscriptions = blk: {
    const messages = @typeInfo(SystemMessage).@"union".fields;

    // For better debugging, use a normal struct. Otherwise, keep it packed.
    // TODO: profile MsgSubscription packed vs auto.
    const alignment, const layout = blk2: {
        if (builtin.mode == .Debug) break :blk2 .{1, .auto};
        break :blk2 .{0, .@"packed"};
    };

    var fields: [messages.len]std.builtin.Type.StructField = undefined;
    for (messages, 0..) |message, idx| {
        fields[idx] = std.builtin.Type.StructField {
            .type = bool,
            .name = message.name,
            .is_comptime = false,
            .default_value_ptr = &false,
            .alignment = alignment,
        };
    }
    break :blk @Type(.{ .@"struct" = .{
        .layout = layout,
        .is_tuple = false,
        .fields = &fields,
        .decls = &.{},
    }});
};

/// Default subscription set.
pub const AllMessages: MsgSubscriptions = blk: {
    var subscriptions: MsgSubscriptions = .{};
    const fields = @typeInfo(MsgSubscriptions).@"struct".fields;

    for (fields) |field| {
        @field(subscriptions, field.name) = true;
    }

    break :blk subscriptions;
};

/// Return a new `MsgSubscriptions` combining both structs.
pub fn mergeSubscriptions(lSubs: MsgSubscriptions, rSubs: MsgSubscriptions) MsgSubscriptions {
    var subscriptions: MsgSubscriptions = .{};
    inline for (std.meta.fieldNames(MsgSubscriptions)) |name| {
        @field(subscriptions, name) = @field(lSubs, name) or @field(rSubs, name);
    }
    return subscriptions;
}

// fn MergedUnions(comptime L: type, comptime R: type) type {
//     const l_fields = @typeInfo(L).Union.fields;
//     const r_fields = @typeInfo(R).Union.fields;

//     var i: usize = 0;
//     var fields: [l_fields.len + r_fields.len]std.builtin.Type.UnionField = undefined;
//     for (l_fields) |field| {
//         fields[i] = field;
//         i += 1;
//     }

//     for (r_fields) |field| {
//         fields[i] = field;
//         i += 1;
//     }

//     return @Type(.{ .Union = .{
//         .layout = .auto,
//         .tag_type = null,
//         .fields = fields[0..i],
//         .decls = &.{},
//     } });
// }

// /// Returns a union type that only contains actions that are scoped to
// /// the given scope.
// /// TU must be a tagged union.
// pub fn ScopedAction(comptime TU: type, comptime s: Scope) type {
//   const all_fields = @typeInfo(TU).Union.fields;

//   // Find all fields that are scoped to s
//   var i: usize = 0;
//   var fields: [all_fields.len]std.builtin.Type.UnionField = undefined;
//   for (all_fields) |field| {
//     const action = @unionInit(TU, field.name, undefined);
//     if (action.scope() == s) {
//       fields[i] = field;
//       i += 1;
//     }
//   }

//   // Build our union
//   return @Type(.{ .Union = .{
//     .layout = .auto,
//     .tag_type = null,
//     .fields = fields[0..i],
//     .decls = &.{},
//   } });
// }

// /// Create a message type for use by your widgets. Behavior is undefined if a
// /// consistent message type is not used.
// pub fn MessageTag(user_messages: type) type {
//     // FIXME: This doesn't work now that we are using a tagged union.
//     const system_fields = @typeInfo(SystemMessageTag).@"enum".fields;

//     const user_fields = switch (@typeInfo(user_messages)) {
//         .@"enum" => |e| e.fields,
//         else => @compileError("Could not create message: '" ++ @typeName(user_messages) ++ "' must be an enum."),
//     };

//     var fields: [system_fields.len + user_fields.len]std.builtin.Type.EnumField = undefined;

//     for (system_fields, 0..) |f, i| {
//         fields[i] = f;
//     }

//     for (user_fields, 0..) |f, i| {
//         fields[i] = f;
//     }

//     return @Type(.{.@"enum" = .{
//         .decls = &.{},
//         .tag_type = message_tag,
//         .fields = &fields,
//         .is_exhaustive = true,
//     }});
// }

// pub fn Message(comptime user_message: type) type {
//     return MergedUnions(SystemMessage, user_message);
// }

// /// Anonymous non-exhaustive enum used for message types within the library.
// /// These should be cast to your message type using `@enumFromInt(@intFromEnum(someMessage))`.
// pub const SomeMessageTag = enum(message_tag) {
//     _,

//     /// Convenience function to concretize `SomeMessage` to your message tag type.
//     pub inline fn erase(self: SomeMessageTag, comptime T: type) T {
//         return @enumFromInt(@intFromEnum(self));
//     }
// };

// /// REVIEW: Not sure this is the correct or best representation we can use.
// pub const SomeMessage = struct {
//     tag: SomeMessageTag,
//     data: *anyopaque,

//     pub fn convert(self: SomeMessage, comptime user_message: type) Message(user_message) {

//     }
// };
