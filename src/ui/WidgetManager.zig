const builtin = @import("builtin");
const std = @import("std");
const Io = std.Io;
const Instant = std.time.Instant;

const msg = @import("message.zig");
const Window = @import("window.zig").Window;
pub const WNode = @import("WNode.zig");

// re-export for ease-of-use.
pub const WidgetManager = @This();

/// Index into the widget array.
pub const WidgetIndex = enum(usize) {
    root = 0,
    _
};

// :WidgetArrayResizing
// XXX: When we resize the array, we need to recalculate pointers. This shouldn't
//      be too hard, but may simply be finicky. The relative offset from the start
//      of the array will not change, but we will have to index each and every widget
//      to fix them.
//      This can be fixed by implementing a DoublyLinkedList on top of the array,
//      using the indices instead of pointers. This change would not be hard.
//      Alternatively, we allocate this list *once* with a user-provided maximum
//      number of nodes and simply error if we go over this amount, obviating the
//      need to reallocate the array.

/// Global array of all nodes.
global_nodes: []Node,

/// Next free node.
next_free: usize,

/// Event writer, for widgets or other components to write new events to.
/// Events will be realized when this writer is flushed or overflows (or any other
/// time `drain` is called).
/// This field is intended to be accessed directly.
evt_writer: Event.Writer,

/// Contains extra metadata about a `WNode`, such as its freed status.
/// TODO: Probably also want a mutex or something.
pub const Node = struct {
    /// This member is null when the node is free.
    node: ?WNode,
};

/// Events are actions that are passed to widgets. They can originate from user
/// action (e.g. clicking somewhere), operating-system intervention (e.g. closing
/// your window), or from other widgets. Events contain a message to interpret
/// their meaning.
pub const Event = struct {
    message: msg.Message,
    /// Where this event was fired from. Events from the system are always 0.
    source: WidgetIndex,

    pub const Writer = struct {
        interface: Io.Writer,
        /// The last write error that occurred. Null if no event occurred during writing.
        last_write_error: ?WNode.WidgetError,

        pub fn init(buffer: []Event) Writer {
            return .{
                .last_write_error = null,
                .interface = .{
                    .vtable = &.{ .drain = drainEvts },
                    .buffer = @ptrCast(buffer),
                },
            };
        }
        // TODO: initAllocating for an Allocating writer.

        /// Drain events. This is the method used in the `Io.Writer` interface.
        /// Each element in `data` MUST be a valid `Event`. It is undefined if
        /// an element is an illegal size.
        ///
        /// Errors that occur during this message due to the dispatching of events
        /// are lost.
        ///
        /// This function should be kept small to enable inlining.
        pub fn drainEvts(io_w: *Io.Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
            var self: *Event.Writer = @alignCast(@fieldParentPtr("interface", io_w));
            var widgetMgr: *WidgetManager = @alignCast(@fieldParentPtr("evt_writer", self));
            const buffered: []u8 = io_w.buffered();
            std.debug.assert(data.len != 0);

            // std.log.debug("Draining events, got data = {any}", .{data});
            // std.log.debug("Draining events, buffered = {any}", .{buffered});

            if (buffered.len != 0) {
                const evts: []Event = std.mem.bytesAsSlice(Event, @as([]align(8) u8, @alignCast(buffered)));
                std.debug.assert(evts.len != 0);
                widgetMgr.dispatchEvt(evts[0]) catch |err| {
                    self.last_write_error = err;
                    return error.WriteFailed;
                };
                return io_w.consume(@sizeOf(Event));
                // for (evts) |evt| {

                // }
            }
            if (data.len == 0) return 0;

            const evts: []const Event = std.mem.bytesAsSlice(Event, data);

            // for (data[0..data.len-1]) |evtBytes| {
            for (evts[0..evts.len-1]) |evt| {
                // std.debug.assert(evt.len == @sizeOf(Event));
                widgetMgr.dispatchEvt(evt) catch |err| {
                    self.last_write_error = err;
                    return error.WriteFailed;
                };
                return io_w.consume(@sizeOf(Event));
            }

            for (0..splat) |_| {
                // std.debug.assert(data[data.len-1].len == @sizeOf(Event));
                widgetMgr.dispatchEvt(evts[data.len-1]) catch |err| {
                    self.last_write_error = err;
                    return error.WriteFailed;
                };
            }

            self.last_write_error = null;
            return Io.Writer.countSplat(data, splat);
        }

        /// Write an event to be dispatched when this writer is drained.
        /// Guaranteed to write the entire event bytes into the writer.
        pub fn writeEvt(self: *Event.Writer, evt: Event) Io.Writer.Error!void {
            // std.log.debug("Event writer: Writing event: {}", .{evt}); // TODO: remove this log if perf is an issue
            const bytes = std.mem.asBytes(&evt);
            // try self.interface.writeAll(@bitCast(evt));
            // try self.interface.writeAll(bytes);
            const bytesWritten = try self.interface.write(bytes);
            _ = bytesWritten;
            // std.log.debug("Wrote {d} bytes to buffer: {any}", .{bytesWritten, bytes});
        }
    };
};

pub const Error = error {
    Unknown
};

pub fn init(node_buf: []Node,
    evt_buf: []Event,
) WidgetManager {
    std.debug.assert(node_buf.len > 0);
    std.debug.assert(evt_buf.len > 0);
    const evt_writer = Event.Writer.init(evt_buf);

    return WidgetManager {
        .evt_writer = evt_writer,
        .global_nodes = node_buf,
        .next_free = 0,
    };
}

// FIXME: handle children and change this to account for the parent of this node.
pub fn addWNode(self: *WidgetManager, wNode: WNode) WidgetIndex {
    std.debug.assert(self.next_free < self.global_nodes.len); // sanity check
    std.debug.assert(self.global_nodes[self.next_free].node == null);
    std.log.debug("Adding new node with indx {d}: {}", .{self.next_free, wNode});

    self.global_nodes[self.next_free] = .{.node = wNode};
    // TODO: BUG: Calculate the next free index correctly.
    defer self.next_free += 1;
    return @enumFromInt(self.next_free);
}

/// Remove a Widget. If the widget didn't exist, then this operation is a no-op.
/// The index must be within bounds of the widget array.
pub fn removeWNode(self: *WidgetManager, indx: WidgetIndex) void {
    std.log.debug("Removing node@{d}", .{indx});
    std.debug.assert(indx < self.global_nodes.len);

    // REVIEW: should next_free be a WidgetIndex, or a usize?
    self.global_nodes[indx].node = null;
    self.next_free = indx;
}

/// Immediately realize an event onto the global nodes/widgets.
pub fn dispatchEvt(self: *WidgetManager, evt: Event) WNode.WidgetError!void {
    std.log.debug("{s} START DISPATCH {s}", .{"=+" ** 4, "=+" ** 4});
    defer std.log.debug("{s} END DISPATCH {s}\n", .{"=+" ** 4, "=+" ** 4});
    var _t: Instant = undefined;
    startFrameTime(&_t);
    defer endFrameTime(_t);

    std.log.debug("Dispatch: Event received from node#{d}: {}", .{@intFromEnum(evt.source), evt.message});
    const window: *Window = @fieldParentPtr("widgetManager", self);
    // std.log.debug("Dispatch: Found parent window {}", .{window});
    std.debug.assert(self.global_nodes.ptr == window.widgetManager.global_nodes.ptr);

    // TODO REMOVE THIS CODE
    if (evt.message == .Resize) {
        window.resize(evt.message.Resize);
    }

    // REVIEW: this seems like garbage.
    for (self.global_nodes, 0..) |*mb_node, idx| {
        _ = idx;
        if (mb_node.node) |*node| {
            // std.log.debug("dispatching to node#{d}", .{idx});
            try node.handleMsg(evt, window);
        }
    }
}


inline fn startFrameTime(time: *Instant) void {
    if (builtin.mode == .Debug or true) {
        time.* = Instant.now() catch unreachable;
    }
}

inline fn endFrameTime(startTime: Instant) void {
    if (builtin.mode == .Debug or true) {
        const endTime = Instant.now() catch unreachable;
        const dur = endTime.since(startTime);
        std.log.debug("FRAMETIME: Event dispatch took {D}", .{dur});
    }
}
