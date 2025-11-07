//! The Root of all `WidgetManager`s. All events are passed to the root widget
//! to be forwarded to its children. This widget is the parent of every widget
//! under a `WidgetManager`.
const std = @import("std");
const builtin = @import("builtin");

const WRoot = @This();
const WNode = @import("WNode.zig");
const Event = @import("WidgetManager.zig").Event;
const Window = @import("window.zig").Window;
const Area = @import("area.zig").Area;
const messages = @import("message.zig");

pub fn wNode() WNode {
    return WNode {
        .ctx = undefined,
        .vtable = &.{
            .handleMsg = handleMsg,
            .release = release,
        },
        .subscriptions = messages.AllMessages,
    };
}

fn handleMsg(node: *WNode, m: Event, window: *Window) WNode.WidgetError!void {
    // Sanity checks to ensure the root node isn't corrupt.
    std.debug.assert(node.parentIndx == null);
    std.debug.assert(node.siblings.next == null);
    std.debug.assert(node.siblings.prev == null);

    if (m.message == .Resize) {
        window.resize(m.message.Resize);
    }

    window.beginPaint();
    defer window.endPaint();
    window.clear();


    // Broadcast the message to all of our children.
    var it = node.children.first;
    while (it) |childEntry| : (it = childEntry.next) {
        var childNode: *WNode = @fieldParentPtr("siblings", childEntry);
        try childNode.handleMsg(m, window);
    }
}

fn release() void {}
