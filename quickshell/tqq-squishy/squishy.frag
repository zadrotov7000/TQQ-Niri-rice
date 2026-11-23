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
    float ripplePhase;
    float rippleStrength;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    // The whole wallpaper stays visible. The mesh warps only lasso vertices.
    fragColor = texture(source, qt_TexCoord0) * qt_Opacity;
}
