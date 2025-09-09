const sokol = @import("sokol");

pub const rgba = struct {
    r: u8,
    b: u8,
    g: u8,
    a: u8 = 255,

    pub fn from(color: u32) @This() {
        const r = @as(u8, @truncate(color >> 24));
        const g = @as(u8, @truncate(color >> 16));
        const b = @as(u8, @truncate(color >> 8));
        const a = @as(u8, @truncate(color));
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub inline fn sdl(self: @This()) sokol.pixels.FColor {
        const m: f32 = comptime 1.0 / 255.0;
        return .{
            .r = @as(f32, @floatFromInt(self.r)) * m,
            .b = @as(f32, @floatFromInt(self.b)) * m,
            .g = @as(f32, @floatFromInt(self.g)) * m,
            .a = @as(f32, @floatFromInt(self.a)) * m,
        };
    }
};

pub const kanagawa_wave = Palette{
    .black = .from(0x090618ff), //   #090618
    .red = .from(0xc34043ff), //     #c34043
    .green = .from(0x76946aff), //   #76946a
    .yellow = .from(0xc0a36eff), //  #c0a36e
    .blue = .from(0x7e9cd8ff), //    #7e9cd8
    .magenta = .from(0x957fb8ff), // #957fb8
    .cyan = .from(0x6a9589ff), //    #6a9589
    .white = .from(0xc8c093ff), //   #c8c093
};

pub const catppuccin_latte = Palette{
    .black = .from(0xdce0e8ff), //   #dce0e8
    .red = .from(0xd20f39ff), //     #d20f39
    .green = .from(0x40a02bff), //   #40a02b
    .yellow = .from(0xdf8e1dff), //  #df8e1d
    .blue = .from(0x1e66f5ff), //    #1e66f5
    .magenta = .from(0xea76cbff), // #ea76cb
    .cyan = .from(0x209fb5ff), //    #209fb5
    .white = .from(0x4c4f69ff), //   #4c4f69
};

pub const catppuccin_frappe = Palette{
    .black = .from(0x232634ff), //   #232634
    .red = .from(0xe78284ff), //     #e78284
    .green = .from(0xa6d189ff), //   #a6d189
    .yellow = .from(0xe5c890ff), //  #e5c890
    .blue = .from(0x8caaeeff), //    #8caaee
    .magenta = .from(0xca9ee6ff), // #ca9ee6
    .cyan = .from(0x85c1dcff), //    #85c1dc
    .white = .from(0xc6d0f5ff), //   #c6d0f5
};

pub const catppuccin_macchiato = Palette{
    .black = .from(0x181926ff), //   #181926
    .red = .from(0xed8796ff), //     #ed8796
    .green = .from(0xa6da95ff), //   #a6da95
    .yellow = .from(0xeed49fff), //  #eed49f
    .blue = .from(0x8aadf4ff), //    #8aadf4
    .magenta = .from(0xc6a0f6ff), // #c6a0f6
    .cyan = .from(0x7dc4e4ff), //    #7dc4e4
    .white = .from(0xcad3f5ff), //   #cad3f5
};

pub const catppuccin_mocha = Palette{
    .black = .from(0x11111bff), //   #11111b
    .red = .from(0xf38ba8ff), //     #f38ba8
    .green = .from(0xa6e3a1ff), //   #a6e3a1
    .yellow = .from(0xf9e2afff), //  #f9e2af
    .blue = .from(0x89b4faff), //    #89b4fa
    .magenta = .from(0xcba6f7ff), // #cba6f7
    .cyan = .from(0x74c7ecff), //    #74c7ec
    .white = .from(0xcdd6f4ff), //   #cdd6f4
};

const Palette = struct {
    black: rgba,
    red: rgba,
    green: rgba,
    yellow: rgba,
    blue: rgba,
    magenta: rgba,
    cyan: rgba,
    white: rgba,
};
