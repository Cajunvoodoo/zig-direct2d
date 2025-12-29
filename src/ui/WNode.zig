//! The main widget class. These widgets form a tree and are stored in an array.
//! The tree is tracked via a `DoublyLinkedList`.
const std = @import("std");

const area = @import("area.zig");
const WidgetManager = @import("WidgetManager.zig").WidgetManager;
pub const WidgetIndex = WidgetManager.WidgetIndex;
const Event = WidgetManager.Event;
const Window = @import("window.zig").Window;
const messageMod = @import("message.zig");
const MsgSubscriptions = messageMod.MsgSubscriptions;
const AllMessages = messageMod.AllMessages;
const MsgCallbacks = messageMod.MsgCallbacks;
const emptyCallbacks = messageMod.emptyCallbacks;

pub const WNode = @This();

///////////////////////////////////////////////////////////////////////////////
//                             INSTANCE VARIABLES                            //
///////////////////////////////////////////////////////////////////////////////


/// User data. If a widget must contain user-defined data, this field should
/// point to the start of it.
ctx: *anyopaque,

vtable: *const VTable,

/// The rectangle this widget is contained within. This is relative to its parent.
/// Nothing may be drawn outside of this area.
drawArea: area.Area,

/// This value is null when it is the root of the widget tree or when a `WNode`
/// is partially initialized (e.g. before it gets added to the tree).
parentIndx: ?WidgetIndex = null,

/// Our node containing our peers (siblings). This is for the parent to enumerate
/// its child widgets.
/// Entry in parent's `WNode.children`.
siblings: std.DoublyLinkedList.Node = .{},

/// Hold's this `WNode`'s children.
children: std.DoublyLinkedList = .{},

/// The messages this WNode should receive.
subscriptions: MsgSubscriptions = AllMessages,

/// The z-level of the widget. Higher = more priority.
z_level: u8 = 0,

/// The user-level callbacks. This is slightly different than `handleMsg`.
/// In particular, the user-facing api should use `msgCallbacks` rather than
/// `handleMsg`. `handleMsg` defines the *behavior* of the widget, whereas
/// `msgCallbacks` defines what the widget should actually do. These are only
/// called when `handleMsg` returns `true`.
msgCallbacks: MsgCallbacks = emptyCallbacks,


///////////////////////////////////////////////////////////////////////////////
//                          GENERIC WNODE FUNCTIONS                          //
///////////////////////////////////////////////////////////////////////////////

/// Check if the node's draw area contains a particular point/position.
pub fn pointInDrawArea(node: *WNode, pos: area.Pos) bool {
    return node.drawArea.containsPos(pos);
}


///////////////////////////////////////////////////////////////////////////////
//                            INTERFACE DEFINITION                            //
///////////////////////////////////////////////////////////////////////////////

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
    ///
    /// The return value determines if the relevant callback should be called
    /// (if such a callback exists).
    /// TODO: make repainting able to target specific widgets.
    handleMsg: *const fn(wNode: *WNode, m: Event, window: *Window) WidgetError!bool,

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
    /// An index into the global nodes failed because the specific widget is
    /// marked as free.
    NoWidgetAtIndex,
    WidgetIndexOutOfBounds,
    /// The widget specified should not receive a provided message because it is
    /// not subscribed to message of that kind.
    NoSubscription,
};

pub fn handleMsg(wNode: *WNode, m: Event, window: *Window) WidgetError!bool {
    return wNode.vtable.handleMsg(wNode, m, window);
}

// TODO: clip to drawArea (requires method in Window)
