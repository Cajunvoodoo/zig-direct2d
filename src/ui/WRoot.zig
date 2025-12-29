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
        // FIXME: draw area for root node should make sense and shouldn't be arbitrary.
        .drawArea = .{
            .tl = .{ .x = 0, .y = 0},
            .br = .{ .x = std.math.maxInt(u16), .y = std.math.maxInt(u16), },
        },
    };
}

fn handleMsg(node: *WNode, m: Event, window: *Window) WNode.WidgetError!bool {
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

    // FIXME: We need to be a bit more strategic here. Only in some situations
    //        should our children receive the message.
    // Broadcast the message to all of our children.
    switch (m.message) {
        .Mouse1DownAbs => |m1Pos| {
            var it = node.children.first;
            var destChild: ?*WNode = null;
            while (it) |childEntry| : (it = childEntry.next) {
                var childNode: *WNode = @fieldParentPtr("siblings", childEntry);
                if (m.message.subscribedBy(childNode.subscriptions) and childNode.drawArea.containsPos(m1Pos)) {
                    std.log.debug("Draw area {any} contains {any}", .{childNode.drawArea, m1Pos});
                    if (destChild) |currTgtChild| {
                        destChild = if (currTgtChild.z_level > childNode.z_level) currTgtChild else childNode;
                    } else {
                        destChild = childNode;
                    }
                }
            }
            // We found the highest z-level child who wants this message, so
            // call their handler function.
            if (destChild) |child| {
                const useCallback: bool = try child.handleMsg(m, window);
                if (useCallback) {
                    try messages.invokeMsgCb(&child.msgCallbacks, child, m.message, m.source, window);
                }
            }
        },
        else => {
            var it = node.children.first;
            while (it) |childEntry| : (it = childEntry.next) {
                var childNode: *WNode = @fieldParentPtr("siblings", childEntry);
                if (m.message.subscribedBy(childNode.subscriptions)) {
                    const useCallback: bool = try childNode.handleMsg(m, window);
                    if (useCallback) {
                        try messages.invokeMsgCb(&childNode.msgCallbacks, childNode, m.message, m.source, window);
                    }
                }

            }
        }
    }
    return false;
}

fn release() void {}
