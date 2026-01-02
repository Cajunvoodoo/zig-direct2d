const std = @import("std");
const builtin = @import("builtin");
const WidgetManager = @import("WidgetManager.zig");
const msg = @import("message.zig");
const area = @import("area.zig");

const native_os = builtin.os.tag;

/// An operating-system Window. Each represents a new drawing space on the client
/// machine.
pub const Window = switch(native_os) {
    ///////////////////////////////////////////////////////////////////////////
    //                                WINDOWS                                 //
    ///////////////////////////////////////////////////////////////////////////

    .windows => blk: {
        const WindowNT = @import("winnt/WindowNT.zig");
        break :blk WindowNT;
    },
    else => |platform| @compileError("Window not yet supported for platform '" ++ @tagName(platform) ++ "'"),
};

/// Options used during creation of a `Window`.
pub const Options = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,

    pub const Default: Options = .{
        .x      = if (native_os == .windows) @bitCast(@as(i32, -1)) else 100,
        .y      = if (native_os == .windows) @bitCast(@as(i32, -1)) else 100,
        .height = if (native_os == .windows) @bitCast(@as(i32, -1)) else 100,
        .width  = if (native_os == .windows) @bitCast(@as(i32, -1)) else 100,
    };
};

pub const Error = error {
    WindowCreationFailed,
    Unknown,
};

/// Create a `Window` using a `widgetManager`.
pub fn init(widgetManager: WidgetManager) Window {
    return Window {
        .widgetManager = widgetManager,
    };
}
