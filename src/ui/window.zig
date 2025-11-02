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

    .windows => struct {
        // These fields are shared across all implementations.
        // evtWriter: WidgetManager.Event.Writer,
        widgetManager: WidgetManager,

        // These fields are Windows-specific. All are initialized in `Create`.
        hwnd: ?win32.HWND                            = null,
        pFactory: ?*win32.ID2D1Factory               = null,
        pRenderTarget: ?*win32.ID2D1HwndRenderTarget = null,
        pWriteFactory: ?*win32.IDWriteFactory        = null,

        const win32 = @import("win32").everything;
        const windowlongptr = @import("win32").windowlongptr;
        const FAILED = win32.FAILED;

        // Win32 boilerplate //////////////////////////////////////////////////

        fn WindowProc(hwnd: win32.HWND, uMsg: u32, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
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

        fn HandleMessage(self: *Window, uMsg: u32, wParam: win32.WPARAM, lParam: win32.LPARAM) win32.LRESULT {
            // We must re-interpret win32 uMsg events as SomeMessages
            const message: ?msg.Message = switch (uMsg) {
                win32.WM_CREATE  => blk: {
                    self.InitResources() catch return -1; // Fail CreateWindowEx.
                    break :blk msg.Message.Init;
                },
                win32.WM_DESTROY => blk: {
                    defer win32.PostQuitMessage(0);
                    break :blk msg.Message.Deinit;
                },
                win32.WM_PAINT   => msg.Message.Repaint,
                win32.WM_SIZE  => blk: {
                    // This message happens after the resizing action is complete (see WM_SIZING for constant updates).
                    const width: u16 = @bitCast(win32.xFromLparam(lParam));
                    const height: u16 = @bitCast(win32.yFromLparam(lParam));
                    const bounds = area.Bounded {
                        .width = width,
                        .height = height,
                    };
                    break :blk msg.Message {.Resize = bounds};
                },
                else => null,
            };
            if (message) |m| {
                const event = WidgetManager.Event {
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
            const size = win32.D2D_SIZE_U {
                .width = @intCast(rc.right - rc.left),
                .height = @intCast(rc.bottom - rc.top)
            };
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

        // Library code ///////////////////////////////////////////////////////

        pub fn resize(self: *Window, desired_size: area.Bounded) void {
          if (self.pRenderTarget) |renderTarget| {
              var rc: win32.RECT = undefined;
              _ = win32.GetClientRect(self.hwnd.?, &rc);

              const size = win32.D2D_SIZE_U{ .width = desired_size.width, .height = desired_size.height };

              _ = renderTarget.Resize(&size);
              _ = win32.InvalidateRect(self.hwnd.?, null, win32.FALSE);
          }
        }

        pub fn create(self: *Window, windowName: [*:0]const u8, options: Options) Error!void {
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
    },
    else => |platform| @compileError("Window not yet supported for platform '" ++ @tagName(platform) ++ "'"),
};

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

pub fn init(widgetManager: WidgetManager) Window {
    return Window {
        .widgetManager = widgetManager,
    };
}


// TODO: Move into a file specifically intended for Windows helpers.
pub const Windows = struct {
    /// Release a COM object.
    pub fn SafeRelease(ppT: anytype) void {
        if (ppT.*) |t| {
            _ = t.IUnknown.Release();
            ppT.* = null;
        }
    }
};

// TODO: move into a file specifically intended for Windows helpers.
pub const D2D1 = struct {
    const win32 = @import("win32").everything;

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
    pub fn HwndRenderTargetProperties(hwnd: win32.HWND, size: win32.D2D_SIZE_U) win32.D2D1_HWND_RENDER_TARGET_PROPERTIES {
        return .{
            .hwnd = hwnd,
            .pixelSize = size,
            .presentOptions = win32.D2D1_PRESENT_OPTIONS_NONE,
        };
    }
};
