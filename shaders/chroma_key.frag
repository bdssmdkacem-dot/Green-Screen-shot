#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uThreshold;
uniform float uSoftness;
uniform sampler2D uTexture;
out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 c = texture(uTexture, uv);

  float maxRG = max(c.r, c.g);
  float greenDominance = c.g - max(c.r, c.b);
  float chroma = smoothstep(uThreshold - uSoftness, uThreshold + uSoftness, greenDominance);

  // Preserve dark neutral objects and remove saturated green.
  float saturation = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
  float greenMask = chroma * smoothstep(0.08, 0.28, saturation);

  // Slight edge softness to reduce green spill around hair/object boundaries.
  float alpha = 1.0 - greenMask;
  vec3 spillCorrected = c.rgb;
  spillCorrected.g = min(spillCorrected.g, max(spillCorrected.r, spillCorrected.b) + 0.10);

  fragColor = vec4(spillCorrected, alpha);
}
