#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIsFullScreen;

uniform sampler2D uBackground;
uniform sampler2D uPrincess;

out vec4 fragColor;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float dustLayer(vec2 uv, float scale, float speed, float driftAmp, float threshold, float time) {
  vec2 st = uv * scale;
  st.y += time * speed;
  st.x += sin(time * 0.42 + st.y * 1.65) * driftAmp;
  vec2 id = floor(st);
  vec2 gv = fract(st) - 0.5;
  float h = hash21(id);
  if (h < threshold) {
    return 0.0;
  }
  vec2 offset = vec2(hash21(id + 13.7) - 0.5, hash21(id + 29.3) - 0.5) * 0.65;
  float d = length(gv - offset);
  float size = mix(0.030, 0.082, hash21(id + 7.1));
  float twinkle = 0.50 + 0.50 * sin(time * (1.4 + h * 2.4) + h * 6.2831);
  return smoothstep(size, 0.0, d) * twinkle;
}

void main() {
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = FlutterFragCoord().xy / res;

  float isFull = clamp(uIsFullScreen, 0.0, 1.0);
  float viewAspect = res.x / res.y;
  vec2 centered = uv - 0.5;

  // Radial distance inside lens (0 at center, 1 at inscribed circle edge)
  vec2 circleSpace = centered * 2.0;
  float r = length(circleSpace);
  float r2 = r * r;

  // Authentic spyglass optical barrel curvature (gentle in circular lens, minimal in full screen)
  float curveStrength = mix(0.055, 0.010, isFull);
  vec2 curvedCentered = centered * (1.0 + curveStrength * r2);

  // Aspect-cover / full-frame mapping onto the 9:16 (576x1024) dungeon scene:
  // Original full-body framing in both circular spyglass (centered at y=0.535)
  // and full-screen exploration view (centered at y=0.50 edge-to-edge).
  const float texAspect = 0.5625;
  vec2 lensTarget = mix(vec2(0.50, 0.535), vec2(0.50, 0.50), isFull);

  vec2 sceneUv;
  if (viewAspect > texAspect) {
    float scaleY = texAspect / viewAspect;
    sceneUv = lensTarget + vec2(curvedCentered.x, curvedCentered.y * scaleY);
  } else {
    float scaleX = viewAspect / texAspect;
    sceneUv = lensTarget + vec2(curvedCentered.x * scaleX, curvedCentered.y);
  }

  // Subtle chromatic dispersion near outer lens glass edge
  float caStrength = mix(0.0044, 0.0018, isFull);
  vec2 caShift = centered * (caStrength * smoothstep(0.30, 1.0, r2));
  vec3 bgCol;
  bgCol.r = texture(uBackground, clamp(sceneUv + caShift, 0.001, 0.999)).r;
  bgCol.g = texture(uBackground, clamp(sceneUv, 0.001, 0.999)).g;
  bgCol.b = texture(uBackground, clamp(sceneUv - caShift, 0.001, 0.999)).b;

  // Organic multi-octave flickering torchlight from right corridor (0.955, 0.435)
  float flicker = 0.88
    + 0.075 * sin(uTime * 7.3)
    + 0.050 * sin(uTime * 11.9 + 1.3)
    + 0.032 * cos(uTime * 19.7 + 0.4)
    + 0.020 * sin(uTime * 3.1 + 2.1);
  float torchPulse = flicker - 0.76;

  vec2 torchDelta = (sceneUv - vec2(0.955, 0.435)) * vec2(texAspect, 1.0);
  float torchGlow = exp(-dot(torchDelta, torchDelta) / 0.016);
  vec2 corridorDelta = (sceneUv - vec2(0.84, 0.49)) * vec2(texAspect, 1.0);
  float corridorBounce = exp(-length(corridorDelta) / 0.25);
  // Warm bounce dancing across the cell bars, far stone wall, and right floor
  vec2 wallBounceDelta = (sceneUv - vec2(0.66, 0.56)) * vec2(texAspect, 1.0);
  float wallBounce = exp(-dot(wallBounceDelta, wallBounceDelta) / 0.14);
  bgCol += vec3(1.0, 0.55, 0.18) * (torchGlow * 0.30 + corridorBounce * 0.085 + wallBounce * 0.028) * torchPulse;

  // Animated volumetric god-rays / sunbeams filtering through the barred window (0.485, 0.34)
  vec2 winDir = sceneUv - vec2(0.485, 0.325);
  float rayAngle = atan(winDir.x, max(winDir.y, 0.001));
  float rayCone = smoothstep(0.295, 0.365, sceneUv.y) * smoothstep(0.79, 0.46, sceneUv.y);
  float coneHalfW = 0.075 + max(0.0, sceneUv.y - 0.335) * 0.43;
  float rayHoriz = 1.0 - smoothstep(coneHalfW * 0.42, coneHalfW, abs(sceneUv.x - 0.485));
  float beamMask = rayCone * rayHoriz;
  float barShafts = pow(0.5 + 0.5 * sin(rayAngle * 14.5 + sin(uTime * 0.35) * 0.35), 2.0);
  float cloudDrift = 0.84 + 0.16 * sin(uTime * 0.58 + rayAngle * 3.2);
  bgCol += vec3(0.76, 0.90, 1.0) * beamMask * (0.026 + 0.032 * barShafts) * cloudDrift;

  // Subtle damp-stone reflection shimmer on lower dungeon floor slabs (v > 0.64)
  float bgLum = dot(bgCol, vec3(0.299, 0.587, 0.114));
  float floorZone = smoothstep(0.63, 0.72, sceneUv.y) * smoothstep(0.98, 0.88, sceneUv.y)
                  * smoothstep(0.80, 0.62, sceneUv.x);
  float wetStoneMask = floorZone * smoothstep(0.26, 0.50, bgLum);
  float wetWave = 0.5 + 0.5 * sin(sceneUv.x * 28.0 + sceneUv.y * 18.0 - uTime * 1.1);
  bgCol += vec3(0.74, 0.88, 1.0) * wetStoneMask * (0.028 + 0.025 * wetWave) * cloudDrift;
  bgCol += vec3(1.0, 0.60, 0.24) * wetStoneMask * smoothstep(0.32, 0.68, sceneUv.x) * 0.040 * max(torchPulse, 0.0);

  // Grounded contact shadow & soft directional cast shadow beneath the Princess's boots
  vec2 shMain = (sceneUv - vec2(0.478, 0.744)) / vec2(0.052, 0.014);
  float contactShadow = exp(-dot(shMain, shMain) * 1.4);
  vec2 shBack = (sceneUv - vec2(0.512, 0.728)) / vec2(0.030, 0.010);
  contactShadow = max(contactShadow, exp(-dot(shBack, shBack) * 1.6) * 0.75);
  vec2 shCast = (sceneUv - vec2(0.452, 0.750)) / vec2(0.075, 0.022);
  float castShadow = exp(-dot(shCast, shCast) * 1.3) * 0.35;
  bgCol *= (1.0 - clamp(contactShadow * 0.62 + castShadow, 0.0, 0.72));

  // Composite animated Princess full-body on the stone floor in realistic proportion
  // to the bed, shackles, barred window, and corridor gate (original scale = 0.425)
  const float fgScale = 0.425;
  vec2 fgOrigin = vec2(0.485 - 0.5 * fgScale, 0.745 - 0.955 * fgScale);
  vec2 fgUv = (sceneUv - fgOrigin) / fgScale;

  vec3 compCol = bgCol;
  float breath = sin(uTime * 1.65) * 0.5 + 0.5;

  if (fgUv.x > 0.16 && fgUv.x < 0.84 && fgUv.y > 0.06 && fgUv.y < 0.985) {
    // 1. Living Posture Micro-Sway (~7.5s balance shift anchored at planted boots)
    float postureMask = smoothstep(0.88, 0.30, fgUv.y);
    float postureSway = sin(uTime * 0.84) * 0.0016 * postureMask;
    vec2 postureDisp = vec2(postureSway, -0.0005 * sin(uTime * 1.68) * postureMask);

    // 2. Subtle Corset / Bust Breathing (~3.8s cycle) + upward ribcage lift
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
    vec2 expandDispA = (dLa * gL + dRa * gR) * (0.056 * breath * bustGate);
    vec2 ribDispA = vec2(0.0, -0.0023 * breath * bustGate * clamp(gL + gR, 0.0, 1.0));
    vec2 breathDisp = vec2((expandDispA.x + ribDispA.x) / texAspect, expandDispA.y + ribDispA.y);

    // 3. Gentle Head Tilt (~5.2s cycle, +/- 1.8 deg around neck base pivot)
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

    // 4. Flowing Side Hair Sway (multi-harmonic draft on left & right hanging curls)
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
    float gustL = sin(phaseL) + 0.32 * sin(uTime * 2.35 - fgUv.y * 7.2 + 0.4);
    float gustR = sin(phaseR) + 0.32 * sin(uTime * 2.35 - fgUv.y * 7.2 + 1.3);
    vec2 hairDisp = vec2(gustL * 0.0038, cos(phaseL) * 0.0012) * hairMaskL
                  + vec2(gustR * 0.0044, cos(phaseR) * 0.0014) * hairMaskR;

    // 5. Subtle Draft Ripple on Satin Skirt Folds & Waist Ribbon Bow
    vec2 skirtD = (fgUv - vec2(0.495, 0.565)) / vec2(0.115, 0.072);
    float skirtMask = exp(-dot(skirtD, skirtD) * 1.4)
                    * smoothstep(0.460, 0.505, fgUv.y)
                    * smoothstep(0.658, 0.615, fgUv.y)
                    * smoothstep(0.340, 0.385, fgUv.x)
                    * smoothstep(0.655, 0.610, fgUv.x);
    float skirtWave = sin(uTime * 1.35 - fgUv.x * 11.0 + fgUv.y * 6.0);
    vec2 skirtDisp = vec2(skirtWave * 0.0016, cos(uTime * 1.35 + fgUv.x * 8.0) * 0.0005) * skirtMask;

    vec2 bowD = (fgUv - vec2(0.585, 0.405)) / vec2(0.032, 0.036);
    float bowMask = exp(-dot(bowD, bowD) * 1.6)
                  * smoothstep(0.555, 0.576, fgUv.x)
                  * smoothstep(0.365, 0.385, fgUv.y)
                  * smoothstep(0.445, 0.420, fgUv.y);
    vec2 bowDisp = vec2(sin(uTime * 1.7 + 0.5) * 0.0024, cos(uTime * 1.7) * 0.0010) * bowMask;

    // Combined continuous inverse UV sampling
    vec2 sampleUv = fgUv - (postureDisp + breathDisp + headDisp + hairDisp + skirtDisp + bowDisp);
    if (sampleUv.x > 0.003 && sampleUv.x < 0.997 && sampleUv.y > 0.003 && sampleUv.y < 0.997) {
      vec4 fg = texture(uPrincess, sampleUv);
      if (fg.a > 0.004) {
        vec3 fgRgb = clamp(fg.rgb / fg.a, 0.0, 1.0);

        // Silhouette edge normals for physical rim lighting
        float eps = 0.0025;
        float aL = texture(uPrincess, sampleUv - vec2(eps, 0.0)).a;
        float aR = texture(uPrincess, sampleUv + vec2(eps, 0.0)).a;
        float aU = texture(uPrincess, sampleUv - vec2(0.0, eps)).a;
        float aD = texture(uPrincess, sampleUv + vec2(0.0, eps)).a;

        // Ambient dungeon shading so princess sits naturally in the stone cell
        fgRgb *= mix(0.86, 0.97, smoothstep(0.92, 0.18, sampleUv.y));

        // Cool top-down daylight rim & soft fill (#CFE8FF) from barred window shafts
        float topRim = clamp(aD - aU, 0.0, 1.0) * smoothstep(0.85, 0.12, sampleUv.y);
        float topFill = smoothstep(0.62, 0.10, sampleUv.y) * (0.068 + 0.018 * cloudDrift);
        fgRgb += vec3(0.812, 0.910, 1.0) * (topRim * 0.30 + topFill);

        // Warm flickering torch bounce (#FF9E40) from right corridor dancing on her right contour
        float rightRim = clamp(aL - aR, 0.0, 1.0) * smoothstep(0.25, 0.65, sampleUv.x);
        float rightBounce = smoothstep(0.45, 0.78, sampleUv.x) * 0.042;
        fgRgb += vec3(1.0, 0.620, 0.251) * (rightRim * 0.26 + rightBounce) * flicker;

        // Delicate emerald iris catchlight shimmer in both eyes (0.4585,0.1976 & 0.5284,0.1940)
        vec2 eyeLUv = vec2(0.4585, 0.1976);
        vec2 eyeRUv = vec2(0.5284, 0.1940);
        float dEyeL = length((sampleUv - eyeLUv) * vec2(texAspect, 1.0));
        float dEyeR = length((sampleUv - eyeRUv) * vec2(texAspect, 1.0));
        float irisMask = smoothstep(0.011, 0.002, min(dEyeL, dEyeR))
                       * smoothstep(0.03, 0.12, fgRgb.g - fgRgb.r);
        float eyeSparkle = 0.65 + 0.35 * sin(uTime * 2.1 + 0.7);
        fgRgb += vec3(0.65, 1.0, 0.90) * irisMask * eyeSparkle * 0.28;

        // Specular glints on silver tiara, pearl earrings & pearl necklace synced with breathing
        float lum = dot(fgRgb, vec3(0.299, 0.587, 0.114));
        float tiaraZone = smoothstep(0.39, 0.43, sampleUv.x) * smoothstep(0.61, 0.57, sampleUv.x)
                        * smoothstep(0.08, 0.10, sampleUv.y) * smoothstep(0.16, 0.135, sampleUv.y);
        float pearlZone = smoothstep(0.45, 0.47, sampleUv.x) * smoothstep(0.58, 0.55, sampleUv.x)
                        * smoothstep(0.245, 0.255, sampleUv.y) * smoothstep(0.295, 0.280, sampleUv.y);
        float earL = exp(-dot((sampleUv - vec2(0.452, 0.228)) * vec2(texAspect, 1.0),
                              (sampleUv - vec2(0.452, 0.228)) * vec2(texAspect, 1.0)) / 0.00018);
        float earR = exp(-dot((sampleUv - vec2(0.570, 0.222)) * vec2(texAspect, 1.0),
                              (sampleUv - vec2(0.570, 0.222)) * vec2(texAspect, 1.0)) / 0.00018);
        float glintHighlight = smoothstep(0.58, 0.92, lum) * (tiaraZone + pearlZone + earL + earR);
        float glintWave = pow(breath, 1.6) * (0.60 + 0.40 * sin(sampleUv.x * 40.0 - uTime * 1.65));
        fgRgb += vec3(0.92, 0.97, 1.0) * glintHighlight * glintWave * 0.30;

        // Traveling satin highlight sheen across her lavender corset & dress folds
        float satinZone = smoothstep(0.29, 0.35, sampleUv.y) * smoothstep(0.67, 0.58, sampleUv.y)
                        * smoothstep(0.31, 0.38, sampleUv.x) * smoothstep(0.65, 0.58, sampleUv.x);
        float purpleSat = clamp(fgRgb.b - fgRgb.g * 0.72, 0.0, 1.0);
        float satinSheen = smoothstep(0.10, 0.28, purpleSat)
                         * smoothstep(0.42, 0.78, lum)
                         * satinZone;
        float sheenTravel = 0.5 + 0.5 * sin(sampleUv.y * 16.0 - uTime * 1.65 + sampleUv.x * 6.0);
        fgRgb += vec3(0.82, 0.88, 1.0) * satinSheen * sheenTravel * 0.11;

        compCol = mix(bgCol, clamp(fgRgb, 0.0, 1.0), fg.a);
      }
    }
  }

  // Multi-depth floating dust motes & warm torch embers drifting across the cell
  float dustNear = dustLayer(sceneUv, 19.0, 0.025, 0.20, 0.76, uTime);
  float dustMid = dustLayer(sceneUv + vec2(0.37, 0.19), 30.0, 0.018, 0.16, 0.74, uTime);
  float dustFar = dustLayer(sceneUv + vec2(0.61, 0.43), 46.0, 0.012, 0.12, 0.72, uTime);
  float beamDust = (dustNear * 0.90 + dustMid * 0.65 + dustFar * 0.42) * beamMask;
  compCol += vec3(0.88, 0.95, 1.0) * beamDust * 0.40;

  // Faint warm ember motes rising near right corridor iron bars
  float emberZone = smoothstep(0.68, 0.92, sceneUv.x) * smoothstep(0.75, 0.35, sceneUv.y);
  float embers = dustLayer(sceneUv + vec2(0.11, 0.71), 28.0, 0.036, 0.25, 0.86, uTime);
  compCol += vec3(1.0, 0.62, 0.22) * embers * emberZone * 0.45 * flicker;

  // Circular telescope vignette when in modal lens mode; subtle corner optical vignette in full-screen
  float circularVignette = 1.0 - smoothstep(0.62, 1.03, r) * 0.85;
  float lensRimGlow = smoothstep(0.76, 0.93, r) * (1.0 - smoothstep(0.93, 1.02, r));

  float cornerR = length(centered * vec2(1.15, 1.05));
  float cornerVignette = 1.0 - smoothstep(0.52, 0.95, cornerR) * 0.38;

  compCol *= mix(circularVignette, cornerVignette, isFull);
  compCol += vec3(0.05, 0.22, 0.30) * lensRimGlow * 0.32 * (1.0 - isFull);

  fragColor = vec4(clamp(compCol, 0.0, 1.0), 1.0);
}
