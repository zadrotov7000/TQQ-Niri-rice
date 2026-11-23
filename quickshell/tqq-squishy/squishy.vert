#version 440

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

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

void main() {
    // The wallpaper stays geometrically still. Deformation is calculated
    // per fragment, so nothing outside the painted red brush mask can move.
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
