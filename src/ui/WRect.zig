//! Primitive retangle widget. This widget performs OS-specific functionality
//! in order to draw a rectangle.
const std = @import("std");
const builtin = @import("builtin");

const WNode = @import("WNode.zig");
const Area = @import("area.zig").Area;
const msg = @import("message.zig");
const SafeRelease = @import("window.zig").Windows.SafeRelease;
const Window = @import("window.zig").Window;
const D2D1 = @import("window.zig").D2D1;
const Event = @import("WidgetManager.zig").Event;

const WRect = @This();

///////////////////////////////////////////////////////////////////////////////
//                                   FIELDS                                  //
///////////////////////////////////////////////////////////////////////////////

// TODO: move color into its own file and abstract
// const Color = struct {
//     r:
// }

/// The OS-specific information for drawing this primitive widget.
ctx: Ctx = .{},
/// The rectangle to draw as a rectangle. This may be as big but no bigger than
/// the parent node's area.
area: Area,
/// Whether to draw the rectangle as filled or not.
style: union(enum) {
    filled: void,
    /// Width of edge in pixels.
    unfilled: f32,
},

const Ctx = switch(builtin.os.tag) {
    .windows => struct {
        brush: ?*win32.ID2D1SolidColorBrush = null,

        const win32 = @import("win32").everything;

        // Below functions are present on all platforms.

        pub fn init(self: *Ctx, window: *Window) !void {
            const color = D2D1.ColorF(.{ .r = 1, .g = 1, .b = 0 });
            // TODO: use color abstraction here to allow for customization
            var brush: *win32.ID2D1SolidColorBrush = undefined;
            const hr = window.pRenderTarget.?.ID2D1RenderTarget.CreateSolidColorBrush(&color, null, &brush);

            if (win32.SUCCEEDED(hr)) {
                self.brush = brush;
            } else return error.CtxInitFailed;
        }

        pub fn deinit(self: *Ctx) void {
            SafeRelease(&self.brush);
        }

        pub fn paint(self: *Ctx, wRect: *WRect, window: *Window) !void {
            const rt = &window.pRenderTarget.?.ID2D1RenderTarget;
            // START DRAW
            var ps: win32.PAINTSTRUCT = undefined;
            _ = win32.BeginPaint(window.hwnd.?, &ps);
            rt.BeginDraw();

            // DRAW BODY
            rt.Clear(&D2D1.ColorFU32(.{.rgb = D2D1.SkyBlue}));
            // TODO: abstract the rectangle this shape belongs to out.
            const rect: win32.D2D_RECT_F = .{
                .left   = @floatFromInt(wRect.area.tl.x),
                .top    = @floatFromInt(wRect.area.tl.y),
                .right  = @floatFromInt(wRect.area.br.x),
                .bottom = @floatFromInt(wRect.area.br.y),
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

///////////////////////////////////////////////////////////////////////////////
//                               IMPLEMENTATION                              //
///////////////////////////////////////////////////////////////////////////////

// fn (ui.WidgetManager.Event, *ui.window.Window__struct_30323, ?*anyopaque) error{InitFailed,RepaintFailed,UnknownError}!void',
pub fn wNode(self: *WRect) WNode {
    return WNode {
        .drawArea = self.area,
        .ctx = @ptrCast(@alignCast(self)),
        .vtable = &.{
            .handleMsg = handleMsg,
            .release = noop,
            // .repaint = repaint,
        },
    };
}

fn handleMsg(node: *WNode, m: Event, window: *Window) WNode.WidgetError!void {
    var self: *WRect = @ptrCast(@alignCast(node.ctx));
    std.log.debug("WRect ({*}) received event: {}", .{self, m.message});
    switch (m.message) {
        .Init => {
            self.init(window) catch return error.InitFailed;
        },
        .Deinit => {
            self.deinit();
        },
        .Repaint => {
            self.paint(window) catch return error.RepaintFailed;
        },
        else => {},
    }
}

fn init(self: *WRect, window: *Window) !void {
    return self.ctx.init(window);
}

fn deinit(self: *WRect) void {
    return self.ctx.deinit();
}

fn paint(self: *WRect, window: *Window) !void {
    return self.ctx.paint(self, window);
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
