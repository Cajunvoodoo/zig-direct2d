//! The main widget class. These widgets form a tree and are stored in an array.
//! The tree is tracked via a `DoublyLinkedList`.
const std = @import("std");

const Area = @import("area.zig").Area;
const WidgetManager = @import("WidgetManager.zig").WidgetManager;
const WidgetIndex = WidgetManager.WidgetIndex;
const Event = WidgetManager.Event;
const Window = @import("window.zig").Window;

pub const WNode = @This();


/// User data. If a widget must contain user-defined data, this field should
/// point to the start of it.
ctx: *anyopaque,

vtable: *const VTable,

/// The rectangle this widget is contained within. This is relative to its parent.
/// Nothing may be drawn outside of this area.
drawArea: Area,

/// This value is null when it is the root of the widget tree or when a `WNode`
/// is partially initialized (e.g. before it gets added to the tree).
parentIndx: ?WidgetIndex = null,

/// Our node containing our peers (siblings). This is for the parent to enumerate
/// its child widgets.
/// Entry in parent's `WNode.children`.
siblings: std.DoublyLinkedList.Node = .{},

/// Hold's this `WNode`'s children.
children: std.DoublyLinkedList = .{},

pub const VTable = struct {

    // /// Repaint the widget in its `WNode.area`.
    // ///
    // /// This method is called once the widget manager knows all of the widgets
    // /// that need repainting. It does this using the writer.
    // repaint: *const fn() WidgetError!void,
    // NOTE: moved repaint into the handleMsg routine because more context was needed
    //       and the functionality felt duplicated.

    /// The core method for each WNode. Widgets ought to handle `Repaint`, `Init`,
    /// and `Deinit`.
    /// TODO: make repainting able to target specific widgets
    handleMsg: *const fn(wNode: *WNode, m: Event, window: *Window) WidgetError!void,

    /// Release the resources associated with this `WNode`. This may never fail.
    /// This must be threadsafe.
    release: *const fn() void,
};

pub const WidgetError = error {
    /// The widget could not be repainted.
    RepaintFailed,
    UnknownError,
    /// Widget initialization failed.
    InitFailed,
};

pub fn handleMsg(wNode: *WNode, m: Event, window: *Window) WidgetError!void {
    return wNode.vtable.handleMsg(wNode, m, window);
}

// TODO: clip to drawArea (requires method in Window)
