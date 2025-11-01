const std = @import("std");

const WidgetManager = @import("ui/WidgetManager.zig");
const Event = WidgetManager.Event;
const WNode = @import("ui/WNode.zig");
const windowMod = @import("ui/window.zig");
// const msg = @import("ui/message.zig");

const WRect = @import("ui/WRect.zig");

const win32 = @import("win32").everything;
pub const UNICODE = true;

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const node_buf = try gpa.alloc(WidgetManager.Node, 100);
    defer gpa.free(node_buf);
    @memset(node_buf, .{.node = null});
    const evt_buf = try gpa.alloc(Event, 100);
    defer gpa.free(evt_buf);
    // @memset(evt_buf, .{});

    const _wm = WidgetManager.init(node_buf, evt_buf);
    var window = windowMod.init(_wm);

    var wRect: WRect = .{
        .area = .{
            .tl = .{.x = 100, .y = 100},
            .br = .{.x = 300, .y = 300},
        }
    };

    _ = window.widgetManager.addWNode(wRect.wNode());

    try window.Create("Test Window Name", .{.x = 100, .y = 100, .width = 500, .height = 300});

    // TODO: add win32 traditional main loop
    var msg: win32.MSG = undefined;
    while (0 != win32.GetMessageW(&msg, null, 0, 0)) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }
}
