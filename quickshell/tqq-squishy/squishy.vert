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
};
layout(binding = 2) uniform sampler2D maskSource;
void main()
{
    vec2 uv = qt_MultiTexCoord0;
    float selected = texture(maskSource, uv).a;
    vec2 pixelPosition = uv * viewportSize;
    float distanceFromGrip = length(pixelPosition - dragOrigin);
    float radial = 1.0 - smoothstep(0.0, max(influenceRadius, 1.0), distanceFromGrip);
    float gripWeight = mix(0.22, 1.0, radial);
    vec4 position = qt_Vertex;
    position.xy += displacement * gripWeight * selected;
    float stretch = clamp(length(displacement) / max(viewportSize.y, 1.0), 0.0, 1.25);
    float ripple = sin(distanceFromGrip * 0.024 - stretch * 5.0) * stretch * 10.0 * radial * selected;
    position.y += ripple;
    gl_Position = qt_Matrix * position;
    qt_TexCoord0 = uv;
}
