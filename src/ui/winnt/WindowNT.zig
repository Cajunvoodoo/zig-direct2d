const std = @import("std");
const builtin = @import("builtin");
const win32 = @import("win32").everything;
const windowlongptr = @import("win32").windowlongptr;
const WidgetManager = @import("../WidgetManager.zig");
const msg = @import("../message.zig");
const area = @import("../area.zig");
const D2D1 = @import("D2D1.zig");
const window = @import("../window.zig");

const Window = @This();
const native_os = builtin.os.tag;
const FAILED = win32.FAILED;

comptime {
    if (native_os != .windows) {
        @compileError("WindowNT.zig can only be built for Windows targets.");
    }
}

///////////////////////////////////////////////////////////////////////////////
//                                   FIELDS                                  //
///////////////////////////////////////////////////////////////////////////////

// These fields are shared across all implementations.
// evtWriter: WidgetManager.Event.Writer,
widgetManager: WidgetManager,

// These fields are Windows-specific. All are initialized in `Create()`.
hwnd: ?win32.HWND                            = null,
pFactory: ?*win32.ID2D1Factory               = null,
pRenderTarget: ?*win32.ID2D1HwndRenderTarget = null,
pWriteFactory: ?*win32.IDWriteFactory        = null,
paintStruct: win32.PAINTSTRUCT               = undefined, // For BeginPaint and EndPaint

///////////////////////////////////////////////////////////////////////////////
//                              WINDOWS-SPECIFIC                             //
///////////////////////////////////////////////////////////////////////////////

fn WindowProc(
    hwnd: win32.HWND,
    uMsg: u32,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) callconv(.winapi) win32.LRESULT {
    var pThis: ?*Window = null;
    if (uMsg == win32.WM_NCCREATE) {
        const pCreate: *win32.CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lParam)));
        pThis = @as(*Window, @ptrCast(@alignCast(pCreate.lpCreateParams)));
        _ = windowlongptr.SetWindowLongPtr(hwnd, win32.GWL_USERDATA, @bitCast(@intFromPtr(pThis)));
        pThis.?.hwnd = hwnd;
    } else {
        // Get the pThis stored in the window data from earlier (lpParam).
        pThis = @ptrFromInt(@as(usize, @bitCast(windowlongptr.GetWindowLongPtr(hwnd, win32.GWL_USERDATA))));
    }
    if (pThis) |this| {
        return this.HandleMessage(uMsg, wParam, lParam);
    } else {
        return win32.DefWindowProcW(hwnd, uMsg, wParam, lParam);
    }
}

fn HandleMessage(
    self: *Window,
    uMsg: u32,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) win32.LRESULT {
    // We must re-interpret win32 uMsg events as SomeMessages
    const message: ?msg.Message = switch (uMsg) {
        win32.WM_CREATE => blk: {
            self.InitResources() catch return -1; // Fail CreateWindowEx.
            const hCursor = win32.LoadCursorW(null, win32.IDC_HAND);
            _ = win32.SetCursor(hCursor);
            break :blk msg.Message.Init;
        },
        win32.WM_DESTROY => blk: {
            defer win32.PostQuitMessage(0);
            break :blk msg.Message.Deinit;
        },
        win32.WM_PAINT => msg.Message.Repaint,
        win32.WM_SIZE => blk: {
            // This message happens after the resizing action is complete (see WM_SIZING for constant updates).
            const width: u16 = @bitCast(win32.xFromLparam(lParam));
            const height: u16 = @bitCast(win32.yFromLparam(lParam));
            const bounds = area.Bounded{
                .width = width,
                .height = height,
            };
            break :blk msg.Message{ .Resize = bounds };
        },
        win32.WM_LBUTTONDOWN => blk: {
            const x: u16 = @bitCast(win32.xFromLparam(lParam));
            const y: u16 = @bitCast(win32.yFromLparam(lParam));
            const pos = area.Pos{
                .x = x,
                .y = y,
            };
            break :blk msg.Message{ .Mouse1DownAbs = pos };
        },
        else => null,
    };
    if (message) |m| {
        const event = WidgetManager.Event{
            .message = m,
            .source = .root,
        };
        self.widgetManager.evt_writer.writeEvt(event) catch return -1;
        const evtWriterPtr = &self.widgetManager.evt_writer.interface;
        evtWriterPtr.flush() catch return -1;
        // self.evtWriter.interface.flush() catch return -1;
    } else {
        return win32.DefWindowProcW(self.hwnd.?, uMsg, wParam, lParam);
    }
    // REVIEW: This is run if we handled the message already.
    return win32.DefWindowProcW(self.hwnd.?, uMsg, wParam, lParam);
}

fn InitResources(self: *Window) !void {
    // pFactory
    if (FAILED(win32.D2D1CreateFactory(
        win32.D2D1_FACTORY_TYPE_SINGLE_THREADED,
        win32.IID_ID2D1Factory,
        null,
        @ptrCast(&self.pFactory),
    ))) {
        return error.D2D1CreateFactoryFailed;
    }
    // pRenderTarget
    var rc: win32.RECT = undefined;
    _ = win32.GetClientRect(self.hwnd.?, &rc);
    const size = win32.D2D_SIZE_U{ .width = @intCast(rc.right - rc.left), .height = @intCast(rc.bottom - rc.top) };
    if (FAILED(self.pFactory.?.CreateHwndRenderTarget(
        &D2D1.RenderTargetProperties(),
        &D2D1.HwndRenderTargetProperties(self.hwnd.?, size),
        @ptrCast(&self.pRenderTarget),
    ))) {
        return error.D2D1CreateHwndRenderTargetFailed;
    }

    // pWriteFactory
    if (FAILED(win32.DWriteCreateFactory(
        win32.DWRITE_FACTORY_TYPE_SHARED,
        win32.IID_IDWriteFactory,
        @ptrCast(&self.pWriteFactory),
    ))) {
        return error.DWriteCreateFactoryFailed;
    }
}

///////////////////////////////////////////////////////////////////////////////
//                            LIBRARY DEFINITIONS                            //
///////////////////////////////////////////////////////////////////////////////

pub fn resize(self: *Window, desired_size: area.Bounded) void {
  if (self.pRenderTarget) |renderTarget| {
      var rc: win32.RECT = undefined;
      _ = win32.GetClientRect(self.hwnd.?, &rc);

      const size = win32.D2D_SIZE_U{ .width = desired_size.width, .height = desired_size.height };

      _ = renderTarget.Resize(&size);
      _ = win32.InvalidateRect(self.hwnd.?, null, win32.FALSE);
  }
}

/// Clear the window. Chiefly used by the root widget (that means
/// don't touch!). You shouldn't need to use this.
/// TODO: clear should accept some form of color for the background, and
///       the root widget should be able to hold this color.
pub fn clear(self: *Window) void {
    const rt = &self.pRenderTarget.?.ID2D1RenderTarget;
    rt.Clear(&D2D1.ColorFU32(.{.rgb = D2D1.SkyBlue}));
}

/// Begin painting. This may be a no-op on some systems, however it is
/// required that this be called before painting, otherwise an error is
/// raised (if violation is detected).
pub fn beginPaint(self: *Window) void {
    // TODO: tell root widget to track if painting has begun, may need
    //       field shared among all window implementations
    std.debug.assert(self.hwnd != null);
    _ = win32.BeginPaint(self.hwnd.?, &self.paintStruct);
}

pub fn endPaint(self: *Window) void {
    std.debug.assert(self.hwnd != null);
    _ = win32.EndPaint(self.hwnd.?, &self.paintStruct);
    // TODO: check return values from BeginPaint and EndPaint
}

pub fn create(self: *Window, windowName: [*:0]const u8, options: window.Options) window.Error!void {
    // FIXME: this is awful.
    var windowNameUtf16: [256:0]u16 = undefined;
    std.debug.assert(std.mem.span(windowName).len <= 256);
    const length = std.unicode.utf8ToUtf16Le(windowNameUtf16[0..], std.mem.span(windowName)) catch return error.Unknown;
    windowNameUtf16[length] = 0;

    const wc = win32.WNDCLASSW{
        .style = .{},
        .lpfnWndProc = WindowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = win32.GetModuleHandleW(null),
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = win32.L("Placeholder"), // win32 lib needs to update for this to not be a placeholder/be null.
        // .lpszMenuName = "Placeholder", // win32 lib needs to update for this to not be a placeholder/be null.
        .lpszClassName = &windowNameUtf16, // XXX: Class name is conceptually different than Window name
    };

    var dwStyle = win32.WS_OVERLAPPEDWINDOW;
    dwStyle.VISIBLE = 1;
    const dwExStyle: win32.WINDOW_EX_STYLE = .{};

    _ = win32.RegisterClassW(&wc);

    self.hwnd = win32.CreateWindowExW(
        dwExStyle,
        &windowNameUtf16,                   // Class name
        &windowNameUtf16,                   // Window name
        dwStyle,                      // dwStyle
        @intCast(options.x),                    // X
        @intCast(options.y),                    // Y
        @intCast(options.width),                // nWidth
        @intCast(options.height),               // nHeight
        null,                         // hWndParent BUG: child windows should set this properly
        null,                         // hMenu
        win32.GetModuleHandleW(null), // hInstance
        @ptrCast(self),               // lpParam
    ) orelse return error.WindowCreationFailed;
}

/// Release a COM object.
pub fn SafeRelease(ppT: anytype) void {
    if (ppT.*) |t| {
        _ = t.IUnknown.Release();
        ppT.* = null;
    }
}
