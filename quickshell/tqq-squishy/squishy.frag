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
layout(binding = 2) uniform sampler2D maskSource;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 original = texture(source, uv);
    float painted = texture(maskSource, uv).a;

    // Hard guarantee: every pixel that was not painted is untouched.
    if (painted <= 0.001) {
        fragColor = original * qt_Opacity;
        return;
    }

    vec2 screenPosition = uv * max(viewportSize, vec2(1.0));
    float gripDistance = length(screenPosition - dragOrigin);
    float radial = 1.0 - smoothstep(0.0, max(influenceRadius, 1.0), gripDistance);
    float softened = radial * radial * (3.0 - 2.0 * radial);

    // Inverse texture lookup keeps the underlying unpainted wallpaper fixed.
    vec2 pull = displacement * softened;
    float pullLength = length(displacement);
    vec2 perpendicular = pullLength > 0.001
        ? vec2(-displacement.y, displacement.x) / pullLength
        : vec2(0.0, 1.0);
    float ripple = sin(gripDistance * 0.037 - ripplePhase)
        * 1.4 * clamp(rippleStrength, 0.0, 0.5) * softened;
    vec2 warpedUv = clamp(
        uv - (pull + perpendicular * ripple) / max(viewportSize, vec2(1.0)),
        vec2(0.0), vec2(1.0)
    );

    vec4 deformed = texture(source, warpedUv);
    // Paint coverage also antialiases the edge of a brush stroke.
    float coverage = smoothstep(0.0, 1.0, painted) * softened;
    fragColor = mix(original, deformed, coverage) * qt_Opacity;
}
