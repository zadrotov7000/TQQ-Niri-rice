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
layout(binding = 2) uniform sampler2D maskSource;

// Feather the lasso in the vertex stage (only 128x72 mesh vertices).
float featheredMask(vec2 uv) {
    vec2 d = vec2(42.0) / max(viewportSize, vec2(1.0));
    float sum = texture(maskSource, uv).a * 0.40;
    sum += texture(maskSource, uv + vec2( d.x, 0.0)).a * 0.10;
    sum += texture(maskSource, uv + vec2(-d.x, 0.0)).a * 0.10;
    sum += texture(maskSource, uv + vec2(0.0,  d.y)).a * 0.10;
    sum += texture(maskSource, uv + vec2(0.0, -d.y)).a * 0.10;
    sum += texture(maskSource, uv + vec2( d.x,  d.y)).a * 0.05;
    sum += texture(maskSource, uv + vec2(-d.x,  d.y)).a * 0.05;
    sum += texture(maskSource, uv + vec2( d.x, -d.y)).a * 0.05;
    sum += texture(maskSource, uv + vec2(-d.x, -d.y)).a * 0.05;
    return smoothstep(0.015, 0.90, sum);
}

void main() {
    vec2 uv = qt_MultiTexCoord0;
    vec2 pixelPosition = uv * viewportSize;
    float mask = featheredMask(uv);

    float distanceFromGrip = length(pixelPosition - dragOrigin);
    float radial = 1.0 - smoothstep(0.0, max(influenceRadius, 1.0), distanceFromGrip);
    // Gradual falloff avoids hard seams at the lasso edge.
    float springFalloff = 0.88 * radial * radial * (3.0 - 2.0 * radial);

    vec4 position = qt_Vertex;
    position.xy += displacement * springFalloff * mask;

    // Gentle ripple perpendicular to the pulling direction.
    float moveDistance = length(displacement);
    vec2 perpendicular = moveDistance > 0.01
        ? vec2(-displacement.y, displacement.x) / moveDistance
        : vec2(0.0, 1.0);
    float wave = sin(distanceFromGrip * 0.037 - ripplePhase)
        * 1.8 * clamp(rippleStrength, 0.0, 1.0) * radial * mask;
    position.xy += perpendicular * wave;

    gl_Position = qt_Matrix * position;
    qt_TexCoord0 = uv;
}
