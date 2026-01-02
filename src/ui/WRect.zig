//! Primitive retangle widget. This widget performs OS-specific functionality
//! in order to draw a rectangle.
const std = @import("std");
const builtin = @import("builtin");

const WNode = @import("WNode.zig");
const Area = @import("area.zig").Area;
const msg = @import("message.zig");
const Window = @import("window.zig").Window;
const Event = @import("WidgetManager.zig").Event;

const WRect = @This();

///////////////////////////////////////////////////////////////////////////////
//                                   FIELDS                                  //
///////////////////////////////////////////////////////////////////////////////

// TODO: move color into its own file and abstract
// const Color = struct {
//     r:
// }
pub const Style = union(enum) {
    filled: void,
    unfilled: f32,
};

/// The OS-specific information for drawing this primitive widget.
os_ctx: OsCtx = .{},
/// Whether to draw the rectangle as filled or not. Defined in call to `toWNode()`.
style: Style = undefined,

/// OS-specific context. An instantiation of this struct is stored in `WRect` itself.
const OsCtx = switch(builtin.os.tag) {
    .windows => struct {
        const SafeRelease = @import("winnt/WindowNT.zig").SafeRelease;
        const D2D1 = @import("winnt/D2D1.zig");
        brush: ?*win32.ID2D1SolidColorBrush = null,

        const win32 = @import("win32").everything;

        // Below functions are present on all platforms.

        pub fn init(self: *OsCtx, window: *Window) !void {
            const color = D2D1.ColorF(.{ .r = 1, .g = 1, .b = 0 });
            // TODO: use color abstraction here to allow for customization
            var brush: *win32.ID2D1SolidColorBrush = undefined;
            const hr = window.pRenderTarget.?.ID2D1RenderTarget.CreateSolidColorBrush(&color, null, &brush);

            if (win32.SUCCEEDED(hr)) {
                self.brush = brush;
            } else return error.CtxInitFailed;
        }

        pub fn deinit(self: *OsCtx) void {
            SafeRelease(&self.brush);
        }

        pub fn paint(self: *OsCtx, wRect: *WRect, wNode: *WNode, window: *Window) !void {
            const rt = &window.pRenderTarget.?.ID2D1RenderTarget;
            // START DRAW
            var ps: win32.PAINTSTRUCT = undefined;
            _ = win32.BeginPaint(window.hwnd.?, &ps);
            rt.BeginDraw();

            // DRAW BODY
            // rt.Clear(&D2D1.ColorFU32(.{.rgb = D2D1.SkyBlue}));
            // TODO: abstract the rectangle this shape belongs to out.
            const rect: win32.D2D_RECT_F = .{
                .left   = @floatFromInt(wNode.drawArea.tl.x),
                .top    = @floatFromInt(wNode.drawArea.tl.y),
                .right  = @floatFromInt(wNode.drawArea.br.x),
                .bottom = @floatFromInt(wNode.drawArea.br.y),
            };
            // Draw the rectangle according to its style.
            // We use the default stroke.
            switch (wRect.style) {
                .filled => rt.FillRectangle(&rect, &self.brush.?.ID2D1Brush),
                .unfilled => rt.DrawRectangle(&rect, &self.brush.?.ID2D1Brush, wRect.style.unfilled, null),
            }

            // END DRAW
            const hr = rt.EndDraw(null, null);
            if (win32.FAILED(hr) or hr == win32.D2DERR_RECREATE_TARGET) {
                self.deinit();
            }

            // TODO: move this out into a larger scope. repainting may take
            //       longer and may span several widgets. Ending painting for
            //       each widget is surely inefficient, right?
            _ = win32.EndPaint(window.hwnd.?, &ps);
        }
    },
    else => |platform| @compileError("WRect not yet supported for platform '" ++ @tagName(platform) ++ "'"),
};

pub const Options = struct {
    rectBounds: Area,
    style: Style,
};

///////////////////////////////////////////////////////////////////////////////
//                               IMPLEMENTATION                              //
///////////////////////////////////////////////////////////////////////////////

pub fn toWNode(self: *WRect, options: Options) WNode {
    self.style = options.style;
    return WNode {
        .ctx = @ptrCast(@alignCast(self)),
        .vtable = &.{
            .handleMsg = handleMsg,
            .release = noop,
            // .repaint = repaint,
        },
        .drawArea = options.rectBounds,
    };
}

fn handleMsg(node: *WNode, m: Event, window: *Window) WNode.WidgetError!bool {
    var self: *WRect = @ptrCast(@alignCast(node.ctx));
    std.log.debug("WRect ({*}) received event from node#{d}: {}", .{self, m.source, m.message});
    switch (m.message) {
        .Init => {
            self.init(window) catch return error.InitFailed;
        },
        .Deinit => {
            self.deinit();
        },
        .Repaint => {
            self.paint(node, window) catch return error.RepaintFailed;
        },
        else => return true,
    }
    return false;
}

fn init(self: *WRect, window: *Window) !void {
    return self.os_ctx.init(window);
}

fn deinit(self: *WRect) void {
    return self.os_ctx.deinit();
}

fn paint(self: *WRect, node: *WNode, window: *Window) !void {
    return self.os_ctx.paint(self, node, window);
}

// fn repaint() WNode.WidgetError!void {

// }

fn noop() void {}

// WHERE I AM AT:
// need to write the overarching Window code,
// ^ Needed to answer "how does the widget get the resources to draw itself?"
//    Needs:
//     - ID2D1Factory, <-- in Window
//     - ID2D1HwndRenderTarget, <-- in Window
//     - ID2D1SolidColorBrush, <-- in our Ctx???
// remaining questions: "how to provide these resources to the widget?"
