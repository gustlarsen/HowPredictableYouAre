#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIsFullScreen;
uniform float uIsCrying;

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

float sdSegmentAspect(vec2 p, vec2 a, vec2 b, float aspect, out float segT) {
  vec2 pa = (p - a) * vec2(aspect, 1.0);
  vec2 ba = (b - a) * vec2(aspect, 1.0);
  segT = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
  return length(pa - ba * segT);
}

void evalPoly3(
    vec2 p,
    vec2 p0,
    vec2 p1,
    vec2 p2,
    vec2 p3,
    float aspect,
    out float minDist,
    out float pathT,
    out vec2 tangentDir) {
  float t0, t1, t2;
  float d0 = sdSegmentAspect(p, p0, p1, aspect, t0);
  float d1 = sdSegmentAspect(p, p1, p2, aspect, t1);
  float d2 = sdSegmentAspect(p, p2, p3, aspect, t2);

  minDist = d0;
  pathT = t0 / 3.0;
  tangentDir = normalize((p1 - p0) * vec2(aspect, 1.0));

  if (d1 < minDist) {
    minDist = d1;
    pathT = (1.0 + t1) / 3.0;
    tangentDir = normalize((p2 - p1) * vec2(aspect, 1.0));
  }
  if (d2 < minDist) {
    minDist = d2;
    pathT = (2.0 + t2) / 3.0;
    tangentDir = normalize((p3 - p2) * vec2(aspect, 1.0));
  }
}

vec2 samplePoly3(vec2 p0, vec2 p1, vec2 p2, vec2 p3, float t) {
  float u = clamp(t, 0.0, 1.0) * 3.0;
  if (u < 1.0) return mix(p0, p1, u);
  if (u < 2.0) return mix(p1, p2, u - 1.0);
  return mix(p2, p3, u - 2.0);
}

vec3 evalTearDrop(
    vec2 p,
    vec2 center,
    float radius,
    float stretch,
    float aspect,
    out vec2 refractDir) {
  vec2 d = (p - center) * vec2(aspect, 1.0);
  float tail = clamp(-d.y / max(radius * stretch, 1e-5), 0.0, 1.0);
  d.x /= mix(1.0, 0.34, tail * tail);
  vec2 dNorm = d;
  if (dNorm.y < 0.0) {
    dNorm.y /= max(stretch, 1.0);
  }
  float dist = length(dNorm);
  float body = 1.0 - smoothstep(radius * 0.45, radius, dist);
  refractDir = (dist > 1e-5) ? (dNorm / dist) * body : vec2(0.0);

  vec2 gPos = center + vec2(-0.22 * radius / aspect, -0.14 * radius);
  float gDist = length((p - gPos) * vec2(aspect, 1.0));
  float glint = 1.0 - smoothstep(radius * 0.14, radius * 0.46, gDist);

  vec2 cPos = center + vec2(0.08 * radius / aspect, 0.36 * radius);
  float cDist = length((p - cPos) * vec2(aspect, 1.0));
  float caustic = (1.0 - smoothstep(radius * 0.16, radius * 0.56, cDist)) * body;

  return vec3(body, glint, caustic);
}

// Sweetheart scalloped lace neckline curve of the purple corset in crying-sprite UV space.
// Used to naturally wick/absorb chest moisture right at the lace edge so tears never cross fabric.
float laceNecklineY(float x) {
  float dx = x - 0.4765;
  float sideSpan = (dx < 0.0) ? 0.072 : 0.074;
  float t = clamp(abs(dx) / sideSpan, 0.0, 1.0);
  return 0.4865 - 0.0315 * pow(max(t, 1e-5), 0.88);
}

// Physically believable clear water micro-bead sitting on bare skin:
// returns vec3(body, meniscusShadow, specGlint) and outputs refraction normal.
vec3 evalSkinMicroBead(
    vec2 p,
    vec2 center,
    float radius,
    float stretch,
    float squashX,
    float aspect,
    out vec2 refractDir) {
  vec2 d = vec2((p.x - center.x) * aspect / max(squashX, 0.5), p.y - center.y);
  float tail = clamp(-d.y / max(radius * stretch, 1e-5), 0.0, 1.0);
  d.x /= mix(1.0, 0.42, tail * tail);
  vec2 dNorm = d;
  if (dNorm.y < 0.0) {
    dNorm.y /= max(stretch, 1.0);
  }
  float dist = length(dNorm);
  float body = 1.0 - smoothstep(radius * 0.38, radius, dist);

  // Soft lower-right contact shadow / meniscus rim so transparent water reads cleanly on bright skin
  vec2 sd = vec2(
    (p.x - (center.x + 0.15 * radius / aspect)) * aspect / max(squashX, 0.5),
    p.y - (center.y + 0.26 * radius)
  );
  float sDist = length(sd);
  float dropShadow = (1.0 - smoothstep(radius * 0.42, radius * 1.18, sDist)) * (1.0 - body * 0.52);

  vec2 nDir = (dist > 1e-5) ? (dNorm / dist) : vec2(0.0);
  refractDir = nDir * body;

  float rimEdge = smoothstep(radius * 0.44, radius * 0.92, dist) * body;
  float meniscus = clamp(
    rimEdge * 0.68 * max(0.0, nDir.y * 0.72 + nDir.x * 0.38 + 0.28) + dropShadow * 0.55,
    0.0,
    1.0
  );

  // Pinpoint upper-left skylight catchlight + delicate lower caustic focus
  vec2 gPos = center + vec2(-0.23 * radius / aspect, -0.17 * radius);
  float gDist = length((p - gPos) * vec2(aspect, 1.0));
  float glint = (1.0 - smoothstep(radius * 0.08, radius * 0.40, gDist)) * body;

  vec2 kPos = center + vec2(0.06 * radius / aspect, 0.28 * radius);
  float kDist = length((p - kPos) * vec2(aspect, 1.0));
  float caustic = (1.0 - smoothstep(radius * 0.12, radius * 0.48, kDist)) * body * 0.45;

  return vec3(body, meniscus, clamp(glint + caustic, 0.0, 1.0));
}

// Evaluates one synchronized post-impact chest micro-droplet and its delicate evaporating
// moisture trail curving organically along bare upper-bust skin toward the cleavage/lace edge.
void evalChestStream(
    vec2 p,
    float cycle,
    float touchStart,
    float trickEnd,
    float beadRadius,
    float phaseOff,
    vec2 p0,
    vec2 p1,
    vec2 p2,
    vec2 p3,
    float aspect,
    float time,
    inout float chestWet,
    inout float chestMeniscus,
    inout float chestSpec,
    inout vec2 chestRefract) {
  if (cycle < touchStart || cycle > trickEnd) return;

  float prog = clamp((cycle - touchStart) / max(trickEnd - touchStart, 1e-4), 0.0, 1.0);
  // Single continuous droplet: settles briefly on skin, then glides along the curved contour
  float slideP = clamp((prog - 0.08) / 0.92, 0.0, 1.0);
  float beadT = pow(max(slideP, 1e-5), 1.25);
  float beadFade = smoothstep(0.0, 0.07, prog) * smoothstep(1.0, 0.78, prog);

  float settleBell = smoothstep(0.0, 0.06, prog) * (1.0 - smoothstep(0.08, 0.22, prog));
  float squashX = mix(0.92, 1.18, settleBell);
  float stretch = mix(1.48, 1.04, settleBell);
  float curR = beadRadius * mix(1.05, 0.74, beadT);

  vec2 bPos = samplePoly3(p0, p1, p2, p3, beadT);
  bPos.x += sin(beadT * 9.0 + phaseOff) * 0.0007 * sin(beadT * 3.14159);

  vec2 bRef;
  vec3 bead = evalSkinMicroBead(p, bPos, curR, stretch, squashX, aspect, bRef);
  chestWet = max(chestWet, bead.x * beadFade * 0.82);
  chestMeniscus = max(chestMeniscus, bead.y * beadFade * 0.88);
  chestSpec = max(chestSpec, bead.z * beadFade * 0.76);
  chestRefract += bRef * beadFade * 0.85;

  // Delicate, whisper-thin translucent wet trail lingering only behind the gliding micro-bead
  if (slideP > 0.01) {
    float dPath, tPath;
    vec2 tDir;
    evalPoly3(p, p0, p1, p2, p3, aspect, dPath, tPath, tDir);
    if (tPath <= beadT + 0.02) {
      float lag = max(0.0, beadT - tPath);
      float trailEnv = exp(-lag * 3.2) * smoothstep(beadT + 0.012, beadT - 0.012, tPath);
      float trailFade = smoothstep(0.0, 0.06, tPath)
                      * smoothstep(1.0, 0.76, tPath)
                      * smoothstep(1.0, 0.78, prog);
      float width = mix(0.0018, 0.0009, clamp(lag * 1.4, 0.0, 1.0));
      float trailMask = (1.0 - smoothstep(0.00035, width, dPath)) * trailEnv * trailFade;
      float shimmer = 0.48 + 0.52 * (0.5 + 0.5 * sin(tPath * 22.0 - time * 2.1 + phaseOff));
      chestWet = max(chestWet, trailMask * 0.46);
      chestMeniscus = max(chestMeniscus, trailMask * 0.34);
      chestSpec = max(chestSpec, trailMask * shimmer * 0.34);
      chestRefract += tDir * trailMask * 0.32;
    }
  }
}

void main() {
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = FlutterFragCoord().xy / res;

  float isFull = clamp(uIsFullScreen, 0.0, 1.0);
  float isCry = step(0.5, uIsCrying);
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

  // Grounded contact shadow & soft directional cast shadow beneath the Princess
  if (isCry < 0.5) {
    vec2 shMain = (sceneUv - vec2(0.478, 0.744)) / vec2(0.052, 0.014);
    float contactShadow = exp(-dot(shMain, shMain) * 1.4);
    vec2 shBack = (sceneUv - vec2(0.512, 0.728)) / vec2(0.030, 0.010);
    contactShadow = max(contactShadow, exp(-dot(shBack, shBack) * 1.6) * 0.75);
    vec2 shCast = (sceneUv - vec2(0.452, 0.750)) / vec2(0.075, 0.022);
    float castShadow = exp(-dot(shCast, shCast) * 1.3) * 0.35;
    bgCol *= (1.0 - clamp(contactShadow * 0.62 + castShadow, 0.0, 0.72));
  } else {
    // Kneeling pose grounded contact shadows beneath knees, boots, and planted left hand
    vec2 shKnees = (sceneUv - vec2(0.505, 0.746)) / vec2(0.088, 0.023);
    float contactShadow = exp(-dot(shKnees, shKnees) * 1.35);
    vec2 shBootL = (sceneUv - vec2(0.392, 0.733)) / vec2(0.045, 0.015);
    contactShadow = max(contactShadow, exp(-dot(shBootL, shBootL) * 1.45) * 0.82);
    vec2 shBootR = (sceneUv - vec2(0.640, 0.725)) / vec2(0.060, 0.018);
    contactShadow = max(contactShadow, exp(-dot(shBootR, shBootR) * 1.40) * 0.80);
    vec2 shCast = (sceneUv - vec2(0.472, 0.752)) / vec2(0.118, 0.032);
    float castShadow = exp(-dot(shCast, shCast) * 1.25) * 0.36;
    bgCol *= (1.0 - clamp(contactShadow * 0.64 + castShadow, 0.0, 0.74));
  }

  // Composite animated Princess on the stone floor in realistic proportion
  // to the bed, shackles, barred window, and corridor gate
  float fgScale = mix(0.425, 0.365, isCry);
  vec2 fgOrigin = mix(
    vec2(0.485 - 0.5 * 0.425, 0.745 - 0.955 * 0.425),
    vec2(0.520 - 0.495 * 0.365, 0.752 - 0.827 * 0.365),
    isCry
  );
  vec2 fgUv = (sceneUv - fgOrigin) / fgScale;

  vec3 compCol = bgCol;
  float breath = (isCry < 0.5)
    ? (sin(uTime * 1.65) * 0.5 + 0.5)
    : pow(0.5 + 0.5 * sin(uTime * 2.0944), 0.85); // ~3.0s emotional sobbing breath cycle

  bool inFgBounds = (isCry < 0.5)
    ? (fgUv.x > 0.16 && fgUv.x < 0.84 && fgUv.y > 0.06 && fgUv.y < 0.985)
    : (fgUv.x > 0.025 && fgUv.x < 0.975 && fgUv.y > 0.165 && fgUv.y < 0.850);

  if (inFgBounds) {
    vec2 sampleUv = fgUv;

    if (isCry < 0.5) {
      // --- STANDING PRINCESS ANIMATION (Pre-Scream) ---
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

      sampleUv = fgUv - (postureDisp + breathDisp + headDisp + hairDisp + skirtDisp + bowDisp);
    } else {
      // --- KNEELING CRYING PRINCESS ANIMATION (Post-Scream) ---
      // Delicate sobbing shudder micro-motion synced to emotional breath peak
      float shiver = sin(uTime * 19.5) * 0.55 + sin(uTime * 31.0 + 1.1) * 0.45;
      float sobTremor = shiver * (0.35 + 0.65 * pow(breath, 1.4));

      // 1. Kneeling Upper-Body Sobbing Sway (anchored at planted knees & boots)
      float torsoAnchor = smoothstep(0.67, 0.34, fgUv.y);
      vec2 shoulderDisp = vec2(
        0.00055 * sobTremor + 0.0011 * sin(uTime * 1.05),
        -0.0018 * breath - 0.00060 * sobTremor
      ) * torsoAnchor;

      // 2. Emotional Sobbing & Corset / Bust Breathing (~3.0s cycle)
      vec2 bustL = vec2(0.415, 0.490);
      vec2 bustR = vec2(0.545, 0.492);
      vec2 dLa = vec2((fgUv.x - bustL.x) * texAspect, fgUv.y - bustL.y);
      vec2 dRa = vec2((fgUv.x - bustR.x) * texAspect, fgUv.y - bustR.y);
      float gL = exp(-dot(dLa, dLa) / 0.0022);
      float gR = exp(-dot(dRa, dRa) / 0.0022);
      float bustGate = smoothstep(0.415, 0.455, fgUv.y)
                     * smoothstep(0.605, 0.545, fgUv.y)
                     * smoothstep(0.305, 0.360, fgUv.x)
                     * smoothstep(0.675, 0.620, fgUv.x);
      vec2 expandDispC = (dLa * gL + dRa * gR) * (0.062 * breath * bustGate);
      vec2 ribDispC = vec2(
        0.0,
        (-0.0028 * breath - 0.00055 * sobTremor) * bustGate * clamp(gL + gR, 0.0, 1.0)
      );
      vec2 breathDisp = vec2((expandDispC.x + ribDispC.x) / texAspect, expandDispC.y + ribDispC.y);

      // 3. Gentle Sorrowful Head Tilt & Tremor around neck pivot above pearl necklace
      float tiltAngle = -0.016 + sin(uTime * 1.15) * 0.022 + sobTremor * 0.0045;
      vec2 neckPivot = vec2(0.510, 0.376);
      float headMask = (1.0 - smoothstep(0.345, 0.378, fgUv.y))
                     * smoothstep(0.330, 0.395, fgUv.x)
                     * smoothstep(0.690, 0.625, fgUv.x);
      float theta = -tiltAngle * headMask;
      vec2 relHead = vec2((fgUv.x - neckPivot.x) * texAspect, fgUv.y - neckPivot.y);
      float ch = cos(theta);
      float sh = sin(theta);
      vec2 rotHead = vec2(relHead.x * ch - relHead.y * sh, relHead.x * sh + relHead.y * ch);
      vec2 headUv = neckPivot + vec2(rotHead.x / texAspect, rotHead.y);
      vec2 headDisp = (fgUv - headUv) + vec2(0.0, 0.0010 * breath) * headMask;

      // 4. Flowing Side Hair Pendulum Sway on hanging curls outside shoulders/arms
      vec2 hairDL = (fgUv - vec2(0.308, 0.485)) / vec2(0.068, 0.115);
      float hairMaskL = exp(-dot(hairDL, hairDL) * 1.25)
                      * smoothstep(0.354, 0.316, fgUv.x)
                      * smoothstep(0.355, 0.415, fgUv.y)
                      * smoothstep(0.605, 0.555, fgUv.y);
      vec2 hairDR = (fgUv - vec2(0.742, 0.478)) / vec2(0.088, 0.118);
      float hairMaskR = exp(-dot(hairDR, hairDR) * 1.20)
                      * smoothstep(0.686, 0.722, fgUv.x)
                      * smoothstep(0.350, 0.410, fgUv.y)
                      * smoothstep(0.610, 0.555, fgUv.y);
      float phaseL = uTime * 1.45 - fgUv.y * 4.2;
      float phaseR = uTime * 1.45 - fgUv.y * 4.2 + 0.85;
      float gustL = sin(phaseL) + 0.32 * sin(uTime * 2.35 - fgUv.y * 7.0 + 0.4);
      float gustR = sin(phaseR) + 0.32 * sin(uTime * 2.35 - fgUv.y * 7.0 + 1.3);
      vec2 hairDisp = vec2(gustL * 0.0040, cos(phaseL) * 0.0012) * hairMaskL
                    + vec2(gustR * 0.0044, cos(phaseR) * 0.0014) * hairMaskR;

      // 5. Subtle Draft Motion on Torn Dress Hem & Lace
      vec2 hemD = (fgUv - vec2(0.245, 0.745)) / vec2(0.095, 0.048);
      float hemMask = exp(-dot(hemD, hemD) * 1.4)
                    * smoothstep(0.675, 0.710, fgUv.y)
                    * smoothstep(0.815, 0.785, fgUv.y)
                    * smoothstep(0.115, 0.165, fgUv.x)
                    * smoothstep(0.395, 0.345, fgUv.x);
      float hemWave = sin(uTime * 1.40 - fgUv.x * 12.0 + fgUv.y * 6.5);
      vec2 hemDisp = vec2(hemWave * 0.0018, cos(uTime * 1.40 + fgUv.x * 8.0) * 0.0006) * hemMask;

      sampleUv = fgUv - (shoulderDisp + breathDisp + headDisp + hairDisp + hemDisp);
    }

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
        float shadeMinY = mix(0.92, 0.82, isCry);
        float shadeMaxY = mix(0.18, 0.22, isCry);
        fgRgb *= mix(0.86, 0.97, smoothstep(shadeMinY, shadeMaxY, sampleUv.y));

        // Cool top-down daylight rim & soft fill (#CFE8FF) from barred window shafts
        float topRim = clamp(aD - aU, 0.0, 1.0) * smoothstep(0.85, 0.12, sampleUv.y);
        float topFill = smoothstep(0.70, 0.14, sampleUv.y) * (0.068 + 0.018 * cloudDrift);
        fgRgb += vec3(0.812, 0.910, 1.0) * (topRim * 0.30 + topFill);

        // Warm flickering torch bounce (#FF9E40) from right corridor dancing on her right contour
        float rightRim = clamp(aL - aR, 0.0, 1.0) * smoothstep(0.25, 0.65, sampleUv.x);
        float rightBounce = smoothstep(0.45, 0.78, sampleUv.x) * 0.042;
        fgRgb += vec3(1.0, 0.620, 0.251) * (rightRim * 0.26 + rightBounce) * flicker;

        // Delicate emerald iris catchlight shimmer in both eyes
        vec2 eyeLUv = mix(vec2(0.4585, 0.1976), vec2(0.4583, 0.3164), isCry);
        vec2 eyeRUv = mix(vec2(0.5284, 0.1940), vec2(0.5451, 0.3125), isCry);
        float dEyeL = length((sampleUv - eyeLUv) * vec2(texAspect, 1.0));
        float dEyeR = length((sampleUv - eyeRUv) * vec2(texAspect, 1.0));
        float irisMask = smoothstep(0.013, 0.002, min(dEyeL, dEyeR))
                       * smoothstep(0.03, 0.12, fgRgb.g - fgRgb.r);
        float eyeSparkle = 0.65 + 0.35 * sin(uTime * 2.1 + 0.7);
        fgRgb += vec3(0.65, 1.0, 0.90) * irisMask * eyeSparkle * 0.28;

        // Specular glints on silver tiara, pearl earrings & pearl necklace synced with breathing
        float lum = dot(fgRgb, vec3(0.299, 0.587, 0.114));
        float tiaraZone = (isCry < 0.5)
          ? (smoothstep(0.39, 0.43, sampleUv.x) * smoothstep(0.61, 0.57, sampleUv.x)
           * smoothstep(0.08, 0.10, sampleUv.y) * smoothstep(0.16, 0.135, sampleUv.y))
          : (smoothstep(0.39, 0.43, sampleUv.x) * smoothstep(0.64, 0.59, sampleUv.x)
           * smoothstep(0.18, 0.20, sampleUv.y) * smoothstep(0.26, 0.235, sampleUv.y));
        float pearlZone = (isCry < 0.5)
          ? (smoothstep(0.45, 0.47, sampleUv.x) * smoothstep(0.58, 0.55, sampleUv.x)
           * smoothstep(0.245, 0.255, sampleUv.y) * smoothstep(0.295, 0.280, sampleUv.y))
          : (smoothstep(0.46, 0.48, sampleUv.x) * smoothstep(0.59, 0.56, sampleUv.x)
           * smoothstep(0.375, 0.390, sampleUv.y) * smoothstep(0.430, 0.412, sampleUv.y));
        vec2 earLPos = mix(vec2(0.452, 0.228), vec2(0.450, 0.349), isCry);
        vec2 earRPos = mix(vec2(0.570, 0.222), vec2(0.591, 0.344), isCry);
        float earL = exp(-dot((sampleUv - earLPos) * vec2(texAspect, 1.0),
                              (sampleUv - earLPos) * vec2(texAspect, 1.0)) / 0.00022);
        float earR = exp(-dot((sampleUv - earRPos) * vec2(texAspect, 1.0),
                              (sampleUv - earRPos) * vec2(texAspect, 1.0)) / 0.00022);
        float glintHighlight = smoothstep(0.58, 0.92, lum) * (tiaraZone + pearlZone + earL + earR);
        float glintWave = pow(breath, 1.6) * (0.60 + 0.40 * sin(sampleUv.x * 40.0 - uTime * 1.65));
        fgRgb += vec3(0.92, 0.97, 1.0) * glintHighlight * glintWave * 0.30;

        // Traveling satin highlight sheen across her lavender corset & dress folds
        float satinZone = (isCry < 0.5)
          ? (smoothstep(0.29, 0.35, sampleUv.y) * smoothstep(0.67, 0.58, sampleUv.y)
           * smoothstep(0.31, 0.38, sampleUv.x) * smoothstep(0.65, 0.58, sampleUv.x))
          : (smoothstep(0.45, 0.50, sampleUv.y) * smoothstep(0.78, 0.69, sampleUv.y)
           * smoothstep(0.16, 0.25, sampleUv.x) * smoothstep(0.73, 0.65, sampleUv.x));
        float purpleSat = clamp(fgRgb.b - fgRgb.g * 0.72, 0.0, 1.0);
        float satinSheen = smoothstep(0.10, 0.28, purpleSat)
                         * smoothstep(0.42, 0.78, lum)
                         * satinZone;
        float sheenTravel = 0.5 + 0.5 * sin(sampleUv.y * 16.0 - uTime * 1.65 + sampleUv.x * 6.0);
        fgRgb += vec3(0.82, 0.88, 1.0) * satinSheen * sheenTravel * 0.11;

        // --- PROCEDURAL GLSL CRYING TEAR ANIMATION (uIsCrying > 0.5) ---
        // Stage 1: Shimmering Cheek Tear Streams (eyes -> cheeks -> chin/jawline)
        // Stage 2: Gravity-Accelerated Free-Falling Droplets (face/chin -> bare upper chest)
        // Stage 3: Delicate Bare-Skin Chest Micro-Beads & Curved Cleavage Moisture Trails
        //          (curving organically into the cleavage and absorbing cleanly at the lace neckline)
        if (isCry > 0.5 &&
            sampleUv.x > 0.42 && sampleUv.x < 0.59 &&
            sampleUv.y > 0.30 && sampleUv.y < 0.505) {
          float tearWet = 0.0;
          float tearHighlight = 0.0;
          float tearCaustic = 0.0;
          vec2 tearRefract = vec2(0.0);

          // Stage 1A: Lower-eyelid watery tear pool glisten
          float lidL = length((sampleUv - vec2(0.458, 0.324)) * vec2(texAspect, 2.2));
          float lidR = length((sampleUv - vec2(0.545, 0.320)) * vec2(texAspect, 2.2));
          float lidPool = smoothstep(0.011, 0.002, min(lidL, lidR));
          tearHighlight += lidPool * (0.45 + 0.28 * sin(uTime * 3.2 + sampleUv.x * 80.0));

          // Stage 1B: Cheek Tear Streams (Eyelids -> Flushed Cheeks -> Chin/Jawline)
          float dCheekL, tCheekL;
          vec2 dirCheekL;
          evalPoly3(
            sampleUv,
            vec2(0.458, 0.324),
            vec2(0.454, 0.340),
            vec2(0.464, 0.354),
            vec2(0.474, 0.365),
            texAspect,
            dCheekL,
            tCheekL,
            dirCheekL
          );
          float streamL = (1.0 - smoothstep(0.0008, 0.0025, dCheekL));
          float flowWaveL = 0.42 + 0.58 * pow(0.5 + 0.5 * sin(tCheekL * 18.0 - uTime * 4.2), 2.0);
          tearWet += streamL * 0.72;
          tearHighlight += streamL * flowWaveL * 0.55;
          tearRefract += dirCheekL * streamL * 0.35;

          float dCheekR, tCheekR;
          vec2 dirCheekR;
          evalPoly3(
            sampleUv,
            vec2(0.545, 0.320),
            vec2(0.548, 0.336),
            vec2(0.538, 0.350),
            vec2(0.530, 0.360),
            texAspect,
            dCheekR,
            tCheekR,
            dirCheekR
          );
          float streamR = (1.0 - smoothstep(0.0008, 0.0025, dCheekR));
          float flowWaveR = 0.42 + 0.58 * pow(0.5 + 0.5 * sin(tCheekR * 18.0 - uTime * 3.9 + 1.4), 2.0);
          tearWet += streamR * 0.72;
          tearHighlight += streamR * flowWaveR * 0.55;
          tearRefract += dirCheekR * streamR * 0.35;

          // Sliding cheek tear beads
          vec2 beadPosL = samplePoly3(
            vec2(0.458, 0.324), vec2(0.454, 0.340), vec2(0.464, 0.354), vec2(0.474, 0.365),
            fract(uTime * 0.42)
          );
          vec2 beadPosR = samplePoly3(
            vec2(0.545, 0.320), vec2(0.548, 0.336), vec2(0.538, 0.350), vec2(0.530, 0.360),
            fract(uTime * 0.37 + 0.52)
          );
          vec2 refDummy;
          vec3 bL = evalTearDrop(sampleUv, beadPosL, 0.0038, 1.35, texAspect, refDummy);
          vec3 bR = evalTearDrop(sampleUv, beadPosR, 0.0038, 1.35, texAspect, refDummy);
          tearWet += bL.x + bR.x;
          tearHighlight += bL.y * 0.90 + bR.y * 0.90;
          tearCaustic += bL.z + bR.z;
          tearRefract += refDummy * 0.6;

          // Stage 2: Free-Falling Tear Droplets (Face/Chin -> Bare Upper Chest)
          // Drop A: Left Chin/Jaw -> Left Upper Bust Skin
          float cycA = fract(uTime / 2.45 + 0.10);
          vec2 dropStartA = vec2(0.474, 0.365);
          vec2 dropEndA = vec2(0.466, 0.447);
          if (cycA < 0.35) {
            float u = cycA / 0.35;
            vec2 posA = vec2(mix(dropStartA.x, dropEndA.x, u), mix(dropStartA.y, dropEndA.y, u * u));
            vec2 coordA = mix(fgUv, sampleUv, smoothstep(0.55, 1.0, u));
            float fadeA = smoothstep(1.0, 0.86, u);
            float rA = 0.0052 * smoothstep(0.0, 0.14, u);
            vec2 refA;
            vec3 tdA = evalTearDrop(coordA, posA, rA, mix(1.45, 2.25, u), texAspect, refA);
            tearWet += tdA.x * fadeA;
            tearHighlight += tdA.y * 1.15 * fadeA;
            tearCaustic += tdA.z * 0.95 * fadeA;
            tearRefract += refA * fadeA;
          }

          // Drop B: Chin Tip -> Upper Center Chest / Cleavage Top
          float cycB = fract(uTime / 2.85 + 0.44);
          vec2 dropStartB = vec2(0.502, 0.371);
          vec2 dropEndB = vec2(0.496, 0.445);
          if (cycB < 0.35) {
            float u = cycB / 0.35;
            vec2 posB = vec2(mix(dropStartB.x, dropEndB.x, u), mix(dropStartB.y, dropEndB.y, u * u));
            vec2 coordB = mix(fgUv, sampleUv, smoothstep(0.55, 1.0, u));
            float fadeB = smoothstep(1.0, 0.86, u);
            float rB = 0.0055 * smoothstep(0.0, 0.14, u);
            vec2 refB;
            vec3 tdB = evalTearDrop(coordB, posB, rB, mix(1.50, 2.35, u), texAspect, refB);
            tearWet += tdB.x * fadeB;
            tearHighlight += tdB.y * 1.20 * fadeB;
            tearCaustic += tdB.z * 0.95 * fadeB;
            tearRefract += refB * fadeB;
          }

          // Drop C: Right Cheek/Jaw -> Right Upper Bust Skin
          float cycC = fract(uTime / 3.15 + 0.76);
          vec2 dropStartC = vec2(0.530, 0.360);
          vec2 dropEndC = vec2(0.526, 0.443);
          if (cycC < 0.35) {
            float u = cycC / 0.35;
            vec2 posC = vec2(mix(dropStartC.x, dropEndC.x, u), mix(dropStartC.y, dropEndC.y, u * u));
            vec2 coordC = mix(fgUv, sampleUv, smoothstep(0.55, 1.0, u));
            float fadeC = smoothstep(1.0, 0.86, u);
            float rC = 0.0050 * smoothstep(0.0, 0.14, u);
            vec2 refC;
            vec3 tdC = evalTearDrop(coordC, posC, rC, mix(1.45, 2.25, u), texAspect, refC);
            tearWet += tdC.x * fadeC;
            tearHighlight += tdC.y * 1.15 * fadeC;
            tearCaustic += tdC.z * 0.95 * fadeC;
            tearRefract += refC * fadeC;
          }

          // Stage 3: Delicate Bare-Skin Chest Landing Micro-Beads & Organic Curved Cleavage Trails
          // Strictly confined to bare skin above the sweetheart lace neckline (never crosses fabric)
          float chestWet = 0.0;
          float chestMeniscus = 0.0;
          float chestSpec = 0.0;
          vec2 chestRefract = vec2(0.0);

          float laceY = laceNecklineY(sampleUv.x);
          float bareChestMask = smoothstep(laceY, laceY - 0.0085, sampleUv.y)
                              * smoothstep(0.425, 0.440, sampleUv.y)
                              * smoothstep(0.42, 0.44, sampleUv.x)
                              * smoothstep(0.56, 0.54, sampleUv.x);
          float skinGuard = smoothstep(0.05, 0.17, fgRgb.r - fgRgb.b);
          float chestGate = bareChestMask * skinGuard;

          if (chestGate > 0.001) {
            // Stream A: Left upper bust -> curves gently inward into cleavage V-dip -> absorbs at lace
            evalChestStream(
              sampleUv, cycA, 0.33, 0.93, 0.0036, 0.0,
              dropEndA, vec2(0.471, 0.458), vec2(0.475, 0.471), vec2(0.476, 0.484),
              texAspect, uTime,
              chestWet, chestMeniscus, chestSpec, chestRefract
            );

            // Stream B: Top of cleavage -> follows natural cleavage crease -> absorbs at V-dip lace
            evalChestStream(
              sampleUv, cycB, 0.33, 0.95, 0.0038, 1.3,
              dropEndB, vec2(0.487, 0.456), vec2(0.480, 0.470), vec2(0.4775, 0.485),
              texAspect, uTime,
              chestWet, chestMeniscus, chestSpec, chestRefract
            );

            // Stream C: Right upper bust -> curves gently inward along inner slope -> absorbs at right lace
            evalChestStream(
              sampleUv, cycC, 0.33, 0.89, 0.0034, 2.5,
              dropEndC, vec2(0.522, 0.451), vec2(0.516, 0.458), vec2(0.508, 0.4645),
              texAspect, uTime,
              chestWet, chestMeniscus, chestSpec, chestRefract
            );

            // Whisper-subtle persistent damp sheen catching light inside the cleavage valley
            float dClev, tClev;
            vec2 dirClev;
            evalPoly3(
              sampleUv,
              dropEndB, vec2(0.487, 0.456), vec2(0.480, 0.470), vec2(0.4775, 0.485),
              texAspect, dClev, tClev, dirClev
            );
            float clevSheen = (1.0 - smoothstep(0.0004, 0.0022, dClev))
                            * smoothstep(0.08, 0.32, tClev)
                            * smoothstep(1.0, 0.76, tClev);
            float clevPulse = 0.55 + 0.45 * sin(tClev * 16.0 - uTime * 1.5);
            chestWet = max(chestWet, clevSheen * 0.24);
            chestSpec = max(chestSpec, clevSheen * clevPulse * 0.16);

            chestWet *= chestGate;
            chestMeniscus *= chestGate;
            chestSpec *= chestGate;
            chestRefract *= chestGate;
          }

          // Composite Stage 1 & 2 (face & falling drops): water refraction + crisp dungeon catchlights
          float wetAmt = clamp(tearWet, 0.0, 1.0);
          if (wetAmt > 0.01) {
            vec2 refUv = clamp(sampleUv - tearRefract * vec2(0.0024 / texAspect, 0.0024), 0.003, 0.997);
            vec4 refFg = texture(uPrincess, refUv);
            if (refFg.a > 0.05) {
              vec3 refCol = clamp(refFg.rgb / refFg.a, 0.0, 1.0);
              fgRgb = mix(fgRgb, refCol * vec3(0.95, 0.99, 1.03), wetAmt * 0.55);
            }
          }
          // Crisp cool white-cyan tear specular (#E8F8FF) + subtle warm right-side torch glint
          vec3 coolTearSpec = vec3(0.910, 0.973, 1.0);
          vec3 warmTorchGlint = vec3(1.0, 0.82, 0.58) * (0.28 * flicker * smoothstep(0.45, 0.56, sampleUv.x));
          fgRgb += coolTearSpec * clamp(tearHighlight, 0.0, 1.35) * 0.78;
          fgRgb += (coolTearSpec * 0.72 + warmTorchGlint) * clamp(tearCaustic, 0.0, 1.0) * 0.65;

          // Composite Stage 3 (bare-skin chest water): refraction + warm meniscus rim depth + soft glisten
          if (chestWet > 0.005 || chestMeniscus > 0.005 || chestSpec > 0.005) {
            if (chestWet > 0.01) {
              vec2 cRefUv = clamp(sampleUv - chestRefract * vec2(0.0022 / texAspect, 0.0022), 0.003, 0.997);
              vec4 cRefFg = texture(uPrincess, cRefUv);
              if (cRefFg.a > 0.05) {
                vec3 cRefCol = clamp(cRefFg.rgb / cRefFg.a, 0.0, 1.0);
                fgRgb = mix(fgRgb, cRefCol * vec3(0.97, 0.99, 1.02), chestWet * 0.48);
              }
            }
            // Delicate warm meniscus shading gives clear-water volume on bright peach skin
            fgRgb = mix(fgRgb, fgRgb * vec3(0.82, 0.76, 0.74), chestMeniscus * 0.48);
            // Restrained skin-harmonized pinpoint specular glisten (never blows out to neon white)
            float skinLum = dot(fgRgb, vec3(0.299, 0.587, 0.114));
            float specScale = mix(0.60, 0.36, smoothstep(0.75, 0.96, skinLum));
            vec3 chestSpecTint = mix(vec3(1.0, 0.94, 0.90), coolTearSpec, 0.55) + warmTorchGlint * 0.62;
            fgRgb += chestSpecTint * chestSpec * specScale;
          }
        }

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
