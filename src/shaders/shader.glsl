//------------------------------------------------------------------------------
//  Shader code for texcube-sapp sample.
//
//  NOTE: This source file also uses the '#pragma sokol' form of the
//  custom tags.
//------------------------------------------------------------------------------
#pragma sokol @header const m = @import("../math.zig")
#pragma sokol @ctype mat4 m.Mat4

#pragma sokol @vs vs
layout(binding=0) uniform vs_params {
    mat4 mvp;
};

in vec2 pos;
in vec4 color0;
in vec2 texcoord0;

out vec4 color;
out vec2 tex_coord;

void main() {
    gl_Position = mvp * vec4(pos, 0.0, 1.0);
    color = color0;
    tex_coord = texcoord0;
}
#pragma sokol @end

#pragma sokol @fs fs
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

in vec4 color;
in vec2 tex_coord;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex, smp), tex_coord) * color;
}
#pragma sokol @end

#pragma sokol @program default vs fs
