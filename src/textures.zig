const std = @import("std");
const sdl3 = @import("sdl3");

pub const BlueBall = Texture.load("./textures/blue_ball.pam");
pub const BlueHeart = Texture.load("./textures/blue_heart.pam");

pub const RedHeart = Texture.load("./textures/red_heart.pam");
pub const RedBall = Texture.load("./textures/red_ball.pam");

const Texture = struct {
    w: usize,
    h: usize,
    max_byte_value: u8,
    /// Number of bytes per pixel
    depth: usize,
    format: sdl3.pixels.Format,
    data: []const u8,

    /// Uploads texture data to gpu mem
    pub fn upload(self: *const @This(), renderer: sdl3.render.Renderer) !sdl3.render.Texture {
        const tex = try sdl3.render.Texture.init(renderer, self.format, .static, self.w, self.h);
        try tex.update(null, @ptrCast(self.data), self.w * self.depth);
        return tex;
    }

    fn load(comptime path: []const u8) @This() {
        const texbin: []const u8 = @embedFile(path);

        // Parse header
        const image = pam.parse(texbin) catch |e| {
            std.debug.panic("Failed to parse pam file: {}\n", .{e});
        };

        return .{
            .w = image.width,
            .h = image.height,
            .max_byte_value = image.maxval,
            .depth = image.depth,
            .format = image.tupltype.sdl(),
            .data = image.data,
        };
    }
};

const PamParseError = error{
    MissingHeaderValue,
    UnsupportedFileFormat,
    UnknownHeader,
    HeaderValueNotFound,
    HeaderFoundTwice,
    UnknowntuplType,
} || std.fmt.ParseIntError;

/// All the tupl types for the pam file format
const TuplType = enum {
    /// Special grey scale.
    /// maxval: 1, depth: 1
    BLACKANDWHITE,

    /// 2 bytes per pixel or MAXVAL > 255
    /// maxval: 2..65535 depth 1
    GRAYSCALE,

    /// 6 bytes per pixel for MAXVAL > 255
    /// maxval: 1..65535 depth 3
    RGB,

    /// 2 bytes per pixel
    /// maxval: 1 depth 2
    BLACKANDWHITE_ALPHA,

    /// 4 bytes per pixel for MAXVAL > 255
    /// maxval: 2..65535 depth 2
    GRAYSCALE_ALPHA,

    /// 8 bytes per pixel for MAXVAL > 255
    /// maxval: 1..65535 depth 4
    RGB_ALPHA,

    pub inline fn sdl(self: @This()) sdl3.pixels.Format {
        const f = sdl3.pixels.Format;
        return switch (self) {
            .BLACKANDWHITE, .GRAYSCALE_ALPHA, .BLACKANDWHITE_ALPHA, .GRAYSCALE => @panic("This bad boy does not have an equivalent sdl3 texture format."),
            .RGB => f.array_rgb_24,
            .RGB_ALPHA => f.array_rgba_32,
        };
    }
};

const PamImage = struct {
    width: usize,
    height: usize,
    depth: usize,
    maxval: u16,
    tupltype: TuplType,
    data: []const u8,
};

const pam = struct {
    /// We only support the P7 pam file format.
    /// A typical file looks like:
    ///
    /// ```
    /// P7
    /// WIDTH 32
    /// HEIGHT 32
    /// DEPTH 4
    /// MAXVAL 255
    /// TUPLTYPE RGB_ALPHA
    /// ``w`
    fn parse(header: []const u8) PamParseError!PamImage {
        var spliterator = std.mem.splitScalar(u8, header, '\n');

        {
            const ft = spliterator.next() orelse return error.MissingHeaderValue;
            if (!std.mem.eql(u8, ft, "P7")) return error.UnsupportedFileFormat;
        }

        var width: ?usize = null;
        const width_key = "WIDTH ";

        var height: ?usize = null;
        const height_key = "HEIGHT ";

        var depth: ?usize = null;
        const depth_key = "DEPTH ";

        var maxval: ?u16 = null;
        const maxval_key = "MAXVAL ";

        var tupltype: ?TuplType = null;
        const tupltype_key = "TUPLTYPE ";

        while (spliterator.next()) |s| {
            // width
            if (std.mem.indexOf(u8, s, width_key)) |idx| {
                if (width != null) return error.HeaderFoundTwice;
                const buf = s[idx + width_key.len ..];
                width = std.fmt.parseInt(usize, buf, 10) catch |e| return e;
                continue;
            }

            // HEIGHT
            if (std.mem.indexOf(u8, s, height_key)) |idx| {
                if (height != null) return error.HeaderFoundTwice;
                const buf = s[idx + height_key.len ..];
                height = std.fmt.parseInt(usize, buf, 10) catch |e| return e;
                continue;
            }

            // DEPTH
            if (std.mem.indexOf(u8, s, depth_key)) |idx| {
                if (depth != null) return error.HeaderFoundTwice;
                const buf = s[idx + depth_key.len ..];
                depth = std.fmt.parseInt(usize, buf, 10) catch |e| return e;
                continue;
            }

            // MAXVAL
            if (std.mem.indexOf(u8, s, maxval_key)) |idx| {
                if (maxval != null) return error.HeaderFoundTwice;
                const buf = s[idx + maxval_key.len ..];
                maxval = std.fmt.parseInt(u8, buf, 10) catch |e| return e;
                continue;
            }

            // tuplTYPE
            if (std.mem.indexOf(u8, s, tupltype_key)) |idx| {
                if (tupltype != null) return error.HeaderFoundTwice;
                const buf = s[idx + tupltype_key.len ..];
                tupltype = std.meta.stringToEnum(TuplType, buf) orelse return error.UnknowntuplType;
                continue;
            }

            if (std.mem.eql(u8, s, "ENDHDR")) break;

            return error.UnknownHeader;
        }

        return PamImage{
            .width = width orelse return error.HeaderValueNotFound,
            .height = height orelse return error.HeaderValueNotFound,
            .depth = depth orelse return error.HeaderValueNotFound,
            .maxval = maxval orelse return error.HeaderValueNotFound,
            .tupltype = tupltype orelse return error.HeaderValueNotFound,
            .data = spliterator.rest(),
        };
    }
};

test "header parsing" {
    const bruh = struct {
        fn check(texbin: []const u8, expected: PamImage) void {
            const header_parse = pam.parse(texbin) catch |e| std.debug.panic("Failed to parse header: {}\n", .{e});

            std.debug.assert(header_parse.width == expected.width);
            std.debug.assert(header_parse.height == expected.height);
            std.debug.assert(header_parse.depth == expected.depth);
            std.debug.assert(header_parse.maxval == expected.maxval);
            std.debug.assert(header_parse.tupltype == expected.tupltype);
            std.debug.assert(std.mem.eql(u8, header_parse.data, expected.data));
        }
    };

    var header: []const u8 = undefined;
    var expected: PamImage = undefined;

    {
        header =
            \\P7
            \\WIDTH 32
            \\HEIGHT 32
            \\DEPTH 4
            \\MAXVAL 255
            \\TUPLTYPE RGB_ALPHA
            \\ENDHDR
            \\fppfjaplsflasAPL
        ;

        expected = PamImage{
            .width = 32,
            .height = 32,
            .depth = 4,
            .maxval = 255,
            .tupltype = .RGB_ALPHA,
            .data = "fppfjaplsflasAPL",
        };
        bruh.check(header, expected);
    }
    {
        header =
            \\P7
            \\WIDTH 13
            \\HEIGHT 11
            \\DEPTH 4
            \\MAXVAL 15
            \\TUPLTYPE RGB_ALPHA
            \\ENDHDR
            \\fppfjaplsflasAPL
        ;

        expected = PamImage{
            .width = 13,
            .height = 11,
            .depth = 4,
            .maxval = 15,
            .tupltype = .RGB_ALPHA,
            .data = "fppfjaplsflasAPL",
        };
        bruh.check(header, expected);
    }

    {
        header =
            \\P7
            \\WIDTH 32
            \\HEIGHT 32
            \\DEPTH 4
            \\MAXVAL 255
            \\TUPLTYPE RGB_ALPHA
            \\ENDHDR
            \\fppfjaplsflasAPL
        ;

        expected = PamImage{
            .width = 32,
            .height = 32,
            .depth = 4,
            .maxval = 255,
            .tupltype = .RGB_ALPHA,
            .data = "fppfjaplsflasAPL",
        };
        bruh.check(header, expected);
    }
    {
        header =
            \\P7
            \\WIDTH 13
            \\HEIGHT 11
            \\DEPTH 4
            \\MAXVAL 255
            \\TUPLTYPE RGB_ALPHA
            \\ENDHDR
            \\fppfjaplsflasAPL
        ;

        expected = PamImage{
            .width = 13,
            .height = 11,
            .depth = 4,
            .maxval = 255,
            .tupltype = .RGB_ALPHA,
            .data = "fppfjaplsflasAPL",
        };
        bruh.check(header, expected);
    }
}
