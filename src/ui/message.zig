//! Messages are sent to `WNode`s in order to coerce them to do something.
const std = @import("std");
const area = @import("area.zig");

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
};

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
