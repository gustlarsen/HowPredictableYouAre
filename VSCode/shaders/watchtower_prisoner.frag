#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;

uniform sampler2D uBackground;
uniform sampler2D uPrincess;

out vec4 fragColor;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float dustLayer(vec2 uv, float scale, float speed, float time) {
  vec2 st = uv * scale;
  st.y += time * speed;
  st.x += sin(time * 0.45 + st.y * 1.7) * 0.18;
  vec2 id = floor(st);
  vec2 gv = fract(st) - 0.5;
  float h = hash21(id);
  if (h < 0.74) {
    return 0.0;
  }
  vec2 offset = vec2(hash21(id + 13.7) - 0.5, hash21(id + 29.3) - 0.5) * 0.65;
  float d = length(gv - offset);
  float size = mix(0.035, 0.085, hash21(id + 7.1));
  float twinkle = 0.55 + 0.45 * sin(time * (1.5 + h * 2.2) + h * 6.2831);
  return smoothstep(size, 0.0, d) * twinkle;
}

void main() {
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = FlutterFragCoord().xy / res;

  float viewAspect = res.x / res.y;
  vec2 centered = uv - 0.5;

  // Radial distance inside spyglass lens (0 at center, 1 at inscribed circle edge)
  vec2 circleSpace = centered * 2.0;
  float r = length(circleSpace);
  float r2 = r * r;

  // Mild edge optical barrel curvature for telescope lens feel
  vec2 curvedUv = 0.5 + centered * (1.0 + 0.055 * r2);

  // Aspect-cover mapping onto the 9:16 (576x1024) dungeon scene
  const float texAspect = 0.5625;
  vec2 sceneUv = curvedUv;
  if (viewAspect > texAspect) {
    float scaleY = texAspect / viewAspect;
    sceneUv.y = (curvedUv.y - 0.5) * scaleY + 0.535;
  } else {
    float scaleX = viewAspect / texAspect;
    sceneUv.x = (curvedUv.x - 0.5) * scaleX + 0.5;
  }

  // Subtle edge chromatic dispersion on the background near lens rim
  vec2 caShift = centered * (0.0042 * smoothstep(0.32, 1.0, r2));
  vec3 bgCol;
  bgCol.r = texture(uBackground, clamp(sceneUv + caShift, 0.001, 0.999)).r;
  bgCol.g = texture(uBackground, clamp(sceneUv, 0.001, 0.999)).g;
  bgCol.b = texture(uBackground, clamp(sceneUv - caShift, 0.001, 0.999)).b;

  // Warm flickering torch light in right corridor (0.955, 0.435)
  float flicker = 0.88
    + 0.08 * sin(uTime * 7.3)
    + 0.05 * sin(uTime * 11.9 + 1.3)
    + 0.03 * cos(uTime * 19.7 + 0.4);
  vec2 torchDelta = (sceneUv - vec2(0.955, 0.435)) * vec2(texAspect, 1.0);
  float torchGlow = exp(-dot(torchDelta, torchDelta) / 0.018);
  vec2 corridorDelta = (sceneUv - vec2(0.86, 0.48)) * vec2(texAspect, 1.0);
  float corridorBounce = exp(-length(corridorDelta) / 0.22);
  bgCol += vec3(1.0, 0.56, 0.18) * (torchGlow * 0.28 + corridorBounce * 0.065) * (flicker - 0.76);

  // Window volumetric sunbeam cone mask (originating at 0.485, 0.34)
  float rayCone = smoothstep(0.30, 0.37, sceneUv.y) * smoothstep(0.77, 0.48, sceneUv.y);
  float coneHalfW = 0.075 + max(0.0, sceneUv.y - 0.34) * 0.42;
  float rayHoriz = 1.0 - smoothstep(coneHalfW * 0.45, coneHalfW, abs(sceneUv.x - 0.485));
  float beamMask = rayCone * rayHoriz;
  float beamShimmer = 0.96 + 0.04 * sin(uTime * 0.9 + sceneUv.x * 12.0);
  bgCol += vec3(0.78, 0.90, 1.0) * beamMask * 0.035 * beamShimmer;

  // Grounded contact shadow beneath the Princess's boots on stone floor
  vec2 shMain = (sceneUv - vec2(0.478, 0.744)) / vec2(0.052, 0.014);
  float contactShadow = exp(-dot(shMain, shMain) * 1.4);
  vec2 shBack = (sceneUv - vec2(0.512, 0.728)) / vec2(0.030, 0.010);
  contactShadow = max(contactShadow, exp(-dot(shBack, shBack) * 1.6) * 0.75);
  vec2 shCast = (sceneUv - vec2(0.452, 0.750)) / vec2(0.075, 0.022);
  float castShadow = exp(-dot(shCast, shCast) * 1.3) * 0.35;
  bgCol *= (1.0 - clamp(contactShadow * 0.62 + castShadow, 0.0, 0.72));

  // Composite animated Princess standing beneath the barred window sunbeams
  const float fgScale = 0.425;
  vec2 fgOrigin = vec2(0.485 - 0.5 * fgScale, 0.745 - 0.955 * fgScale);
  vec2 fgUv = (sceneUv - fgOrigin) / fgScale;

  vec3 compCol = bgCol;
  float breath = sin(uTime * 1.65) * 0.5 + 0.5;

  if (fgUv.x > 0.16 && fgUv.x < 0.84 && fgUv.y > 0.06 && fgUv.y < 0.985) {
    // 1. Subtle Corset / Bust Breathing (~3.8s cycle)
    vec2 bustL = vec2(0.385, 0.335);
    vec2 bustR = vec2(0.505, 0.342);
    vec2 dLa = vec2((fgUv.x - bustL.x) * texAspect, fgUv.y - bustL.y);
    vec2 dRa = vec2((fgUv.x - bustR.x) * texAspect, fgUv.y - bustR.y);
    float gL = exp(-dot(dLa, dLa) / 0.0014);
    float gR = exp(-dot(dRa, dRa) / 0.0014);
    float bustGate = smoothstep(0.275, 0.305, fgUv.y)
                   * smoothstep(0.425, 0.380, fgUv.y)
                   * smoothstep(0.305, 0.345, fgUv.x)
                   * smoothstep(0.600, 0.555, fgUv.x);
    vec2 expandDispA = (dLa * gL + dRa * gR) * (0.055 * breath * bustGate);
    vec2 ribDispA = vec2(0.0, -0.0022 * breath * bustGate * clamp(gL + gR, 0.0, 1.0));
    vec2 breathDisp = vec2((expandDispA.x + ribDispA.x) / texAspect, expandDispA.y + ribDispA.y);

    // 2. Gentle Head Tilt (~5.2s cycle, +/- 1.8 deg around neck base pivot)
    float tiltAngle = sin(uTime * 1.2) * 0.032;
    vec2 neckPivot = vec2(0.505, 0.252);
    float headMask = (1.0 - smoothstep(0.205, 0.252, fgUv.y))
                   * smoothstep(0.330, 0.400, fgUv.x)
                   * smoothstep(0.700, 0.630, fgUv.x);
    float theta = -tiltAngle * headMask;
    vec2 relHead = vec2((fgUv.x - neckPivot.x) * texAspect, fgUv.y - neckPivot.y);
    float ch = cos(theta);
    float sh = sin(theta);
    vec2 rotHead = vec2(relHead.x * ch - relHead.y * sh, relHead.x * sh + relHead.y * ch);
    vec2 headUv = neckPivot + vec2(rotHead.x / texAspect, rotHead.y);
    vec2 headDisp = fgUv - headUv;

    // 3. Flowing Side Hair Sway (secondary motion on left & right hanging curls)
    vec2 hairDL = (fgUv - vec2(0.322, 0.335)) / vec2(0.058, 0.085);
    float hairMaskL = exp(-dot(hairDL, hairDL) * 1.5)
                    * smoothstep(0.372, 0.332, fgUv.x)
                    * smoothstep(0.225, 0.265, fgUv.y)
                    * smoothstep(0.415, 0.370, fgUv.y);
    vec2 hairDR = (fgUv - vec2(0.710, 0.325)) / vec2(0.088, 0.110);
    float hairMaskR = exp(-dot(hairDR, hairDR) * 1.3)
                    * smoothstep(0.632, 0.678, fgUv.x)
                    * smoothstep(0.205, 0.250, fgUv.y)
                    * smoothstep(0.440, 0.390, fgUv.y);
    float phaseL = uTime * 1.45 - fgUv.y * 4.5;
    float phaseR = uTime * 1.45 - fgUv.y * 4.5 + 0.85;
    vec2 hairDisp = vec2(sin(phaseL) * 0.0042, cos(phaseL) * 0.0012) * hairMaskL
                  + vec2(sin(phaseR) * 0.0048, cos(phaseR) * 0.0014) * hairMaskR;

    // Inverse UV sampling
    vec2 sampleUv = fgUv - (breathDisp + headDisp + hairDisp);
    if (sampleUv.x > 0.003 && sampleUv.x < 0.997 && sampleUv.y > 0.003 && sampleUv.y < 0.997) {
      vec4 fg = texture(uPrincess, sampleUv);
      if (fg.a > 0.004) {
        vec3 fgRgb = clamp(fg.rgb / fg.a, 0.0, 1.0);

        // Silhouette edge normals for environmental rim lighting
        float eps = 0.0025;
        float aL = texture(uPrincess, sampleUv - vec2(eps, 0.0)).a;
        float aR = texture(uPrincess, sampleUv + vec2(eps, 0.0)).a;
        float aU = texture(uPrincess, sampleUv - vec2(0.0, eps)).a;
        float aD = texture(uPrincess, sampleUv + vec2(0.0, eps)).a;

        // Ambient dungeon shading so princess sits naturally in the stone cell
        fgRgb *= mix(0.86, 0.97, smoothstep(0.92, 0.18, fgUv.y));

        // Cool top-down daylight rim & soft fill (#CFE8FF) from barred window
        float topRim = clamp(aD - aU, 0.0, 1.0) * smoothstep(0.85, 0.12, fgUv.y);
        float topFill = smoothstep(0.62, 0.10, fgUv.y) * 0.075;
        fgRgb += vec3(0.812, 0.910, 1.0) * (topRim * 0.28 + topFill);

        // Faint warm flickering torch bounce (#FF9E40) from right corridor bars
        float rightRim = clamp(aL - aR, 0.0, 1.0) * smoothstep(0.25, 0.65, fgUv.x);
        float rightBounce = smoothstep(0.45, 0.78, fgUv.x) * 0.035;
        fgRgb += vec3(1.0, 0.620, 0.251) * (rightRim * 0.22 + rightBounce) * flicker;

        // Subtle specular glint on silver tiara & pearl necklace synced with breathing
        float lum = dot(fgRgb, vec3(0.299, 0.587, 0.114));
        float tiaraZone = smoothstep(0.39, 0.43, fgUv.x) * smoothstep(0.61, 0.57, fgUv.x)
                        * smoothstep(0.08, 0.10, fgUv.y) * smoothstep(0.16, 0.135, fgUv.y);
        float pearlZone = smoothstep(0.45, 0.47, fgUv.x) * smoothstep(0.58, 0.55, fgUv.x)
                        * smoothstep(0.245, 0.255, fgUv.y) * smoothstep(0.295, 0.280, fgUv.y);
        float glintHighlight = smoothstep(0.60, 0.92, lum) * (tiaraZone + pearlZone);
        float glintWave = pow(breath, 2.0) * (0.65 + 0.35 * sin(fgUv.x * 38.0 - uTime * 1.65));
        fgRgb += vec3(0.90, 0.96, 1.0) * glintHighlight * glintWave * 0.26;

        compCol = mix(bgCol, clamp(fgRgb, 0.0, 1.0), fg.a);
      }
    }
  }

  // Floating dust motes drifting slowly through the window's volumetric sunbeams
  float dust1 = dustLayer(sceneUv, 26.0, 0.022, uTime);
  float dust2 = dustLayer(sceneUv + vec2(0.37, 0.19), 40.0, 0.015, uTime);
  float dustTotal = (dust1 * 0.85 + dust2 * 0.55) * beamMask;
  compCol += vec3(0.88, 0.95, 1.0) * dustTotal * 0.42;

  // Telescope / Spyglass circular vignette & subtle optical glass rim tint
  float vignette = 1.0 - smoothstep(0.62, 1.03, r) * 0.85;
  compCol *= vignette;
  float lensRimGlow = smoothstep(0.76, 0.93, r) * (1.0 - smoothstep(0.93, 1.02, r));
  compCol += vec3(0.05, 0.22, 0.30) * lensRimGlow * 0.32;

  fragColor = vec4(clamp(compCol, 0.0, 1.0), 1.0);
}
