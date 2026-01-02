//! This example is ported from : https://github.com/microsoft/Windows-classic-samples/blob/master/Samples/Win7Samples/begin/LearnWin32/Direct2DCircle/cpp/main.cpp
pub const UNICODE = true;

const std = @import("std");
const win32 = @import("win32").everything;
const L = win32.L;
const FAILED = win32.FAILED;
const SUCCEEDED = win32.SUCCEEDED;
const HRESULT = win32.HRESULT;
const HINSTANCE = win32.HINSTANCE;
const HWND = win32.HWND;
const MSG = win32.MSG;
const WPARAM = win32.WPARAM;
const LPARAM = win32.LPARAM;
const LRESULT = win32.LRESULT;
const RECT = win32.RECT;
const D2D_SIZE_U = win32.D2D_SIZE_U;
const D2D_SIZE_F = win32.D2D_SIZE_F;
const SafeReslease = win32.SafeRelease;

const basewin = @import("basewin.zig");
const BaseWindow = basewin.BaseWindow;
const dbgwin = @import("dbgwin.zig");
const DebugWindow = dbgwin.DebugWindow;

fn SafeRelease(ppT: anytype) void {
    if (ppT.*) |t| {
        _ = t.IUnknown.Release();
        ppT.* = null;
    }
}

const MainWindow = struct {
    base: BaseWindow(@This()) = .{},
    // Direct2d
    pFactory: ?*win32.ID2D1Factory = null,
    pRenderTarget: ?*win32.ID2D1HwndRenderTarget = null,
    pBrush: ?*win32.ID2D1SolidColorBrush = null,
    // DirectWrite
    pWriteFactory: ?*win32.IDWriteFactory = null,
    pTextFormat : ?*win32.IDWriteTextFormat = null,
    // Shapes
    ellipse: win32.D2D1_ELLIPSE = undefined,

    // Recalculate drawing layout when the size of the window changes.
    pub inline fn CalculateLayout(self: *MainWindow) void {
        if (self.pRenderTarget) |pRenderTarget| {
            // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            // TODO: this call is causing a segfault when we return from this function!!!
            //       I believe it is caused by this issue: https://github.com/ziglang/zig/issues/1481
            //       Zig unable to handle a return type of extern struct { x: f32, y: f32 } for WINAPI
            _ = pRenderTarget;
            // const size: D2D_SIZE_F = pRenderTarget.ID2D1RenderTarget.GetSize();
            const size = D2D_SIZE_F{ .width = 300, .height = 300 };
            const x: f32 = size.width / 2;
            const y: f32 = size.height / 2;
            const radius = @min(x, y);
            self.ellipse = D2D1.Ellipse(D2D1.Point2F(x, y), radius, radius);
        }
    }

    pub inline fn CreateGraphicsResources(self: *MainWindow) HRESULT {
        var hr = win32.S_OK;
        if (self.pRenderTarget == null) {
            var rc: RECT = undefined;
            _ = win32.GetClientRect(self.base.m_hwnd.?, &rc);

            const size = D2D_SIZE_U{
                .width = @intCast(rc.right - rc.left),
                .height = @intCast(rc.bottom - rc.top)
            };

            var target: *win32.ID2D1HwndRenderTarget = undefined;
            hr = self.pFactory.?.CreateHwndRenderTarget(
                &D2D1.RenderTargetProperties(),
                &D2D1.HwndRenderTargetProperties(self.base.m_hwnd.?, size),
                &target,
            );

            if (SUCCEEDED(hr)) {
                self.pRenderTarget = target;
                const color = D2D1.ColorF(.{ .r = 1, .g = 1, .b = 0 });
                var brush: *win32.ID2D1SolidColorBrush = undefined;
                hr = self.pRenderTarget.?.ID2D1RenderTarget.CreateSolidColorBrush(&color, null, &brush);

                if (SUCCEEDED(hr)) {
                    self.pBrush = brush;
                    self.CalculateLayout();
                }
            }
            var out: *win32.IDWriteTextFormat = undefined;
            hr = self.pWriteFactory.?.CreateTextFormat(
                L("Gabriola"),
                null,
                win32.DWRITE_FONT_WEIGHT_REGULAR,
                win32.DWRITE_FONT_STYLE_NORMAL,
                win32.DWRITE_FONT_STRETCH_NORMAL,
                48.0,
                L("en-us"),
                &out,
            );
            self.pTextFormat = out;
        }
        return hr;
    }

    pub inline fn DiscardGraphicsResources(self: *MainWindow) void {
        SafeRelease(&self.pRenderTarget);
        SafeRelease(&self.pBrush);
    }

    pub inline fn OnPaint(self: *MainWindow) void {
        var hr = self.CreateGraphicsResources();
        if (SUCCEEDED(hr)) {
            var ps: win32.PAINTSTRUCT = undefined;
            _ = win32.BeginPaint(self.base.m_hwnd.?, &ps);

            self.pRenderTarget.?.ID2D1RenderTarget.BeginDraw();

            self.pRenderTarget.?.ID2D1RenderTarget.Clear(&D2D1.ColorFU32(.{ .rgb = D2D1.SkyBlue }));
            // TODO: how do I get a COM interface type to convert to a base type without
            //       an explicit cast like this?
            self.pRenderTarget.?.ID2D1RenderTarget.FillEllipse(&self.ellipse, &self.pBrush.?.ID2D1Brush);
            self.pRenderTarget.?.ID2D1RenderTarget.DrawText(
                L("This is some text UwU"),
                21,
                self.pTextFormat,
                &.{.left = 160, .top = 300, .right = 500, .bottom = 500},
                @ptrCast(self.pBrush),
                .{},
                .NATURAL);

            hr = self.pRenderTarget.?.ID2D1RenderTarget.EndDraw(null, null);
            if (FAILED(hr) or hr == win32.D2DERR_RECREATE_TARGET) {
                self.DiscardGraphicsResources();
            }
            _ = win32.EndPaint(self.base.m_hwnd.?, &ps);

            // var i: u16 = 0;
            // while(i < 10) : ({
            //     i += 1;
            //     hr = self.pRenderTarget.?.ID2D1RenderTarget.EndDraw(null, null);
            //     if (FAILED(hr)) {
            //         self.DiscardGraphicsResources();
            //         _ = win32.EndPaint(self.base.m_hwnd.?, &ps);
            //         std.log.err("Failed to EndDraw: {s}", .{@tagName(win32.GetLastError())});
            //         break;
            //     }
            //     if (hr == win32.D2DERR_RECREATE_TARGET) {
            //         self.DiscardGraphicsResources();
            //     }
            //     _ = win32.EndPaint(self.base.m_hwnd.?, &ps);
            // }) {
            //     _ = win32.BeginPaint(self.base.m_hwnd.?, &ps);
            //     self.pRenderTarget.?.ID2D1RenderTarget.BeginDraw();

            //     self.pRenderTarget.?.ID2D1RenderTarget.Clear(&D2D1.ColorFU32(.{ .rgb = D2D1.SkyBlue }));
            //     self.pRenderTarget.?.ID2D1RenderTarget.FillEllipse(&self.ellipse, &self.pBrush.?.ID2D1Brush);
            //     self.pRenderTarget.?.ID2D1RenderTarget.DrawText(L("This is some text UwU"), 21, null, null, null, .{}, .NATURAL);

            //     self.ellipse.point = D2D1.Point2F(self.ellipse.point.x + 5, self.ellipse.point.y);
            // }
        }
    }

    pub inline fn Resize(self: *MainWindow) void {
        if (self.pRenderTarget) |renderTarget| {
            var rc: RECT = undefined;
            _ = win32.GetClientRect(self.base.m_hwnd.?, &rc);

            const size = D2D_SIZE_U{ .width = @intCast(rc.right), .height = @intCast(rc.bottom) };

            _ = renderTarget.Resize(&size);
            self.CalculateLayout();
            _ = win32.InvalidateRect(self.base.m_hwnd.?, null, win32.FALSE);
        }
    }

    pub fn ClassName() [*:0]const u16 {
        return L("Circle Window Class");
    }

    pub fn HandleMessage(self: *MainWindow, uMsg: u32, wParam: WPARAM, lParam: LPARAM) LRESULT {
        switch (uMsg) {
            win32.WM_CREATE => {
                // TODO: Should I need to case &self.pFactory to **anyopaque? Maybe
                //       D2D2CreateFactory probably doesn't have the correct type yet?
                if (FAILED(win32.D2D1CreateFactory(
                    win32.D2D1_FACTORY_TYPE_SINGLE_THREADED,
                    win32.IID_ID2D1Factory,
                    null,
                    @ptrCast(&self.pFactory),
                ))) {
                    return -1; // Fail CreateWindowEx.
                }

                if (FAILED(win32.DWriteCreateFactory(
                    win32.DWRITE_FACTORY_TYPE_SHARED,
                    win32.IID_IDWriteFactory,
                    @ptrCast(&self.pWriteFactory),
                ))) {
                    return -1; // Fail CreateWindowEx.
                }
                return 0;
            },
            win32.WM_TIMER | win32.WM_DESTROY => {
                self.DiscardGraphicsResources();
                SafeRelease(&self.pFactory);
                win32.PostQuitMessage(0);
                return 0;
            },
            win32.WM_PAINT => {
                self.OnPaint();
                return 0;
            },
            // Other messages not shown...
            win32.WM_SIZE => {
                self.Resize();
                return 0;
            },
            else => {},
        }
        return win32.DefWindowProcW(self.base.m_hwnd.?, uMsg, wParam, lParam);
    }
};

pub export fn wWinMain(_: HINSTANCE, __: ?HINSTANCE, ___: [*:0]u16, nCmdShow: u32) callconv(.winapi) c_int {
    _ = __;
    _ = ___;

    // var foo = DebugWindow(MainWindow){
    //     .dbgbase = .{},
    // };
    // var foo = //DebugWindowBase(MainWindow, "dbgbase"){};
    // std.log.debug("{any}", .{foo});
    // Find the second monitor ////////////////////////////////////////////////

    var monitor_data: MonitorEnumData = MonitorEnumData {};

    _ = win32.EnumDisplayMonitors(
        null,
        null,
        MonitorEnumProc,
        @as(win32.LPARAM, @bitCast(@intFromPtr(&monitor_data))));
    // std.debug.print("Display found: {any}", .{monitor_data});

    const xpos, const ypos = blk: {
        if (monitor_data.secondMonitorRect) |rect| {
            break :blk .{rect.left + 50, rect.top + 50};
        }
        break :blk .{win32.CW_USEDEFAULT, win32.CW_USEDEFAULT};
    };

    // Create Main Window /////////////////////////////////////////////////////

    var win = MainWindow{};
    var window_style: win32.WINDOW_STYLE = win32.WS_OVERLAPPEDWINDOW;
    window_style.VISIBLE = 0;

    if (win32.TRUE != win.base.Create(L("Circle"), window_style, .{
        .x = xpos,
        .y = ypos,
        .nWidth = 1000,
        .nHeight = 500,
    })) {
        return 0;
    }

    _ = win32.ShowWindow(win.base.Window(), @bitCast(nCmdShow));
    // 2s timer for the window. We close the window when the timer fires.
    _ = win32.SetTimer(win.base.Window(), 0, 10000, null);

    // Run the message loop.

    var msg: MSG = undefined;
    while (0 != win32.GetMessageW(&msg, null, 0, 0)) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }

    return 0;
}

const MonitorEnumData = struct {
    count: u32 = 0,
    secondMonitorRect: ?RECT = null,
};

fn MonitorEnumProc(hMonitor: ?win32.HMONITOR, __: ?win32.HDC, ___: ?*RECT, dwData: LPARAM) callconv(.winapi) win32.BOOL {
    _ = __;
    _ = ___;

    const data: *MonitorEnumData = @ptrFromInt(@as(usize, @bitCast(dwData)));
    var monitor_info: win32.MONITORINFO = .{
        .cbSize = @sizeOf(win32.MONITORINFO),
        .rcMonitor = undefined,
        .rcWork = undefined,
        .dwFlags = 0,
    };

    if (0 != win32.GetMonitorInfoW(hMonitor, &monitor_info)) {
        std.debug.print("Display found: count = {d}, info = {any}\n", .{data.count, monitor_info});
        if (monitor_info.dwFlags & win32.MONITORINFOF_PRIMARY == 0) {
            data.secondMonitorRect = monitor_info.rcMonitor;
            return win32.FALSE;
        }
    } else {
        const err = win32.GetLastError();
        std.debug.print("Could not get monitor info for monitor {d}: {s}\n", .{data.count, @tagName(err)});
    }

    data.count += 1;
    // std.debug.print("Display found: {any}\n", .{data});
    // std.debug.print("Display found: count = {d}, rect = {any}\n", .{data.count, lprcMonitor.?.*});

    // if (data.count == 2) {
    //     if (lprcMonitor) |monitor| {
    //         data.secondMonitorRect = monitor;
    //     }
    //     return win32.FALSE;
    // }

    return win32.TRUE;
}

// TODO: tthis D2D1 namespace is referenced in the C++ example but it doesn't exist in win32metadata
const D2D1 = struct {
    // TODO: SkyBlue is missing from win32metadata? file an issue?
    pub const SkyBlue = 0x87CEEB;

    // TODO: this is missing
    pub fn ColorF(o: struct { r: f32, g: f32, b: f32, a: f32 = 1 }) win32.D2D_COLOR_F {
        return .{ .r = o.r, .g = o.g, .b = o.b, .a = o.a };
    }

    // TODO: this is missing
    pub fn ColorFU32(o: struct { rgb: u32, a: f32 = 1 }) win32.D2D_COLOR_F {
        return .{
            .r = @as(f32, @floatFromInt((o.rgb >> 16) & 0xff)) / 255,
            .g = @as(f32, @floatFromInt((o.rgb >> 8) & 0xff)) / 255,
            .b = @as(f32, @floatFromInt((o.rgb >> 0) & 0xff)) / 255,
            .a = o.a,
        };
    }

    pub fn Point2F(x: f32, y: f32) win32.D2D_POINT_2F {
        return .{ .x = x, .y = y };
    }

    pub fn Ellipse(center: win32.D2D_POINT_2F, radiusX: f32, radiusY: f32) win32.D2D1_ELLIPSE {
        return .{
            .point = center,
            .radiusX = radiusX,
            .radiusY = radiusY,
        };
    }

    // TODO: this is missing
    pub fn RenderTargetProperties() win32.D2D1_RENDER_TARGET_PROPERTIES {
        return .{
            .type = win32.D2D1_RENDER_TARGET_TYPE_DEFAULT,
            .pixelFormat = PixelFormat(),
            .dpiX = 0,
            .dpiY = 0,
            .usage = win32.D2D1_RENDER_TARGET_USAGE_NONE,
            .minLevel = win32.D2D1_FEATURE_LEVEL_DEFAULT,
        };
    }

    // TODO: this is missing
    pub fn PixelFormat() win32.D2D1_PIXEL_FORMAT {
        return .{
            .format = win32.DXGI_FORMAT_UNKNOWN,
            .alphaMode = win32.D2D1_ALPHA_MODE_UNKNOWN,
        };
    }

    // TODO: this is missing
    pub fn HwndRenderTargetProperties(hwnd: HWND, size: D2D_SIZE_U) win32.D2D1_HWND_RENDER_TARGET_PROPERTIES {
        return .{
            .hwnd = hwnd,
            .pixelSize = size,
            .presentOptions = win32.D2D1_PRESENT_OPTIONS_NONE,
        };
    }
};

// const std = @import("std");

// const win32 = @import("zigwin32").everything;
// // const direct2d = win32.graphics.direct2d;
// // const ID2D1Factory = direct2d.ID2D1Factory;
// const ID2D1Factory = win32.ID2D1Factory;

// pub fn main() !void {
//     std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
//     const foo: ID2D1Factory = undefined;
//     _ = foo;
// }
