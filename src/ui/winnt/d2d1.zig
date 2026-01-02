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
