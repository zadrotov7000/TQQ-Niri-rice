#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 viewportSize;
    vec2 dragOrigin;
    vec2 displacement;
    float influenceRadius;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D maskSource;
void main()
{
    vec4 color = texture(source, qt_TexCoord0);
    float mask = texture(maskSource, qt_TexCoord0).a;
    float edge = smoothstep(0.015, 0.72, mask);
    fragColor = vec4(color.rgb, color.a * edge * qt_Opacity);
}
