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

    var field_names: [messages.len][]const u8 = undefined;
    var field_types: [messages.len]type = undefined;
    var field_attrs: [messages.len]std.builtin.Type.StructField.Attributes = undefined;
    for (messages, 0..) |message, idx| {
        field_names[idx] = message.name;
        field_types[idx] = bool;
        field_attrs[idx] = .{
            .@"comptime" = false,
            .@"align" = alignment,
            .default_value_ptr = &false,
        };
    }
    break :blk @Struct(
        layout,
        null,
        &field_names,
        &field_types,
        &field_attrs,
    );
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
