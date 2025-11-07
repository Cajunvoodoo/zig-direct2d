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
    @memset(node_buf, .{.wnode = undefined, .free = true});
    const evt_buf = try gpa.alloc(Event, 100);
    defer gpa.free(evt_buf);
    // @memset(evt_buf, .{});

    const _wm = WidgetManager.init(node_buf, evt_buf);
    var window = windowMod.init(_wm);

    const wRect: WRect = .{
        .style = .{.unfilled = 10},
        .rectBounds = .{
            .tl = .{.x = 100, .y = 100},
            .br = .{.x = 300, .y = 300},
        }
    };
    var wRect1 = wRect;

    var hr: WNode.WidgetIndex = undefined;
    hr = window.widgetManager.addWNode(null, wRect1.wNode());
    std.debug.assert(@intFromEnum(hr) == 1);

    var wRect2: WRect = wRect;
    wRect2.rectBounds.tl = .{.x = 50, .y = 50};
    wRect2.rectBounds.br = .{.x = 100, .y = 100};
    wRect2.style = .filled;
    hr = window.widgetManager.addWNode(null, wRect2.wNode());
    std.debug.assert(@intFromEnum(hr) == 2);

    try window.create("Test Window Name", .{.x = 100, .y = 100, .width = 500, .height = 300});

    var msg: win32.MSG = undefined;
    while (0 != win32.GetMessageW(&msg, null, 0, 0)) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);

        wRect1.rectBounds.tl.x += 5;
        wRect1.rectBounds.tl.y += 5;
        wRect1.rectBounds.br.x += 5;
        wRect1.rectBounds.br.y += 5;
    }
}
