#!/usr/bin/env python3
"""
Preprocesses the Bare Metal Robot Archmage Chassis into:
  1. VSCode/assets/images/watchtower/robot_archmage_naked_frame.png (512x512 RGBA)
  2. 7 perfectly aligned progressive assembly stage sprites (512x512 RGBA):
     - archmage_stage_1_leg1.png
     - archmage_stage_2_legs.png
     - archmage_stage_3_waist.png
     - archmage_stage_4_torso.png
     - archmage_stage_5_arm1.png
     - archmage_stage_6_arms.png
     - archmage_stage_7_head.png
  3. 7 perfectly aligned isolated part sprites for snap-in micro-animations (512x512 RGBA):
     - archmage_part_1_leg1.png .. archmage_part_7_head.png
  4. 7 matching workbench parts piles (512x512 RGBA) with soft contact shadows:
     - archmage_pile_week_0.png .. archmage_pile_week_6.png
"""

import math
import os
from collections import deque
from PIL import Image, ImageDraw, ImageFilter

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_IMAGE = "/home/antigravity/robot_archmage_naked_frame.jpeg"
OUT_DIR = os.path.join(REPO_ROOT, "VSCode", "assets", "images", "watchtower")


def remove_white_background_flood_fill(src_rgb: Image.Image) -> Image.Image:
    """
    Edge-connected flood-fill background removal on the full-resolution image
    with smooth anti-aliased edge feathering and white-halo decontamination.
    """
    rgba = src_rgb.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()

    def is_bg_candidate(r: int, g: int, b: int) -> bool:
        mx = max(r, g, b)
        mn = min(r, g, b)
        # Near-white low-saturation background pixels (accounts for slight JPEG compression)
        return mn >= 228 and (mx - mn) <= 22

    bg = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    # Seed from all 4 borders
    for x in range(w):
        for y in (0, h - 1):
            r, g, b, _ = px[x, y]
            if is_bg_candidate(r, g, b) and not bg[y][x]:
                bg[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            r, g, b, _ = px[x, y]
            if is_bg_candidate(r, g, b) and not bg[y][x]:
                bg[y][x] = True
                q.append((x, y))

    # 4-connected BFS flood fill
    while q:
        cx, cy = q.popleft()
        if cx > 0 and not bg[cy][cx - 1]:
            r, g, b, _ = px[cx - 1, cy]
            if is_bg_candidate(r, g, b):
                bg[cy][cx - 1] = True
                q.append((cx - 1, cy))
        if cx + 1 < w and not bg[cy][cx + 1]:
            r, g, b, _ = px[cx + 1, cy]
            if is_bg_candidate(r, g, b):
                bg[cy][cx + 1] = True
                q.append((cx + 1, cy))
        if cy > 0 and not bg[cy - 1][cx]:
            r, g, b, _ = px[cx, cy - 1]
            if is_bg_candidate(r, g, b):
                bg[cy - 1][cx] = True
                q.append((cx, cy - 1))
        if cy + 1 < h and not bg[cy + 1][cx]:
            r, g, b, _ = px[cx, cy + 1]
            if is_bg_candidate(r, g, b):
                bg[cy + 1][cx] = True
                q.append((cx, cy + 1))

    # Compute 2-pixel border distance into foreground for smooth AA & halo decontamination
    # dist_to_bg == 0 -> background; 1 -> immediate outer edge; 2 -> 1px inner edge
    dist = [[99] * w for _ in range(h)]
    edge_q: deque[tuple[int, int]] = deque()
    for y in range(h):
        for x in range(w):
            if bg[y][x]:
                dist[y][x] = 0
                # Check if adjacent to foreground
                if (
                    (x > 0 and not bg[y][x - 1])
                    or (x + 1 < w and not bg[y][x + 1])
                    or (y > 0 and not bg[y - 1][x])
                    or (y + 1 < h and not bg[y + 1][x])
                ):
                    edge_q.append((x, y))

    while edge_q:
        cx, cy = edge_q.popleft()
        d = dist[cy][cx]
        if d >= 3:
            continue
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and dist[ny][nx] > d + 1:
                dist[ny][nx] = d + 1
                edge_q.append((nx, ny))

    # Build alpha channel and decontaminate white fringe on boundary pixels
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_px = out.load()

    for y in range(h):
        for x in range(w):
            if bg[y][x]:
                continue
            r, g, b, _ = px[x, y]
            d = dist[y][x]
            if d == 1:
                # Edge pixel directly touching white background:
                # Since the sprite has crisp dark outlines (~15..60 luminance),
                # bright pixels on this 1px rim are white-blended anti-aliased pixels.
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                sat = max(r, g, b) - min(r, g, b)
                if lum > 110 and sat < 35:
                    # Estimate coverage against pure white background assuming dark outline (~24)
                    dark_ref = 24.0
                    alpha_f = max(0.0, min(1.0, (255.0 - lum) / (255.0 - dark_ref)))
                    # Smoothstep slightly for cleaner anti-aliasing
                    alpha_f = alpha_f * alpha_f * (3.0 - 2.0 * alpha_f)
                    alpha = int(round(alpha_f * 255))
                    if alpha <= 4:
                        continue
                    # Un-premultiply white halo
                    inv_a = 1.0 / max(alpha_f, 0.18)
                    nr = int(max(0, min(255, round((r - 255.0 * (1.0 - alpha_f)) * inv_a))))
                    ng = int(max(0, min(255, round((g - 255.0 * (1.0 - alpha_f)) * inv_a))))
                    nb = int(max(0, min(255, round((b - 255.0 * (1.0 - alpha_f)) * inv_a))))
                    out_px[x, y] = (nr, ng, nb, alpha)
                else:
                    out_px[x, y] = (r, g, b, 255)
            elif d == 2:
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                sat = max(r, g, b) - min(r, g, b)
                if lum > 205 and sat < 25:
                    # Light inner fringe: mildly attenuate alpha and pull away from white
                    alpha_f = max(0.25, min(1.0, (255.0 - lum) / 70.0))
                    alpha = int(round(alpha_f * 255))
                    nr = int(max(0, min(255, round((r - 255.0 * (1.0 - alpha_f)) / alpha_f))))
                    ng = int(max(0, min(255, round((g - 255.0 * (1.0 - alpha_f)) / alpha_f))))
                    nb = int(max(0, min(255, round((b - 255.0 * (1.0 - alpha_f)) / alpha_f))))
                    out_px[x, y] = (nr, ng, nb, alpha)
                else:
                    out_px[x, y] = (r, g, b, 255)
            else:
                out_px[x, y] = (r, g, b, 255)

    # Gentle 0.6px Gaussian anti-alias pass on the alpha channel only along edges
    r_ch, g_ch, b_ch, a_ch = out.split()
    a_blur = a_ch.filter(ImageFilter.GaussianBlur(radius=0.6))
    a_px = a_ch.load()
    ab_px = a_blur.load()
    for y in range(h):
        for x in range(w):
            if dist[y][x] <= 2:
                a_px[x, y] = min(a_px[x, y], ab_px[x, y]) if bg[y][x] else ab_px[x, y]

    return Image.merge("RGBA", (r_ch, g_ch, b_ch, a_ch))


def make_polygon_mask(size: tuple[int, int], poly_512: list[tuple[float, float]]) -> Image.Image:
    """
    Create a crisp antialiased mask at `size` (1024x1024) from polygon vertices
    defined in 512x512 coordinates.
    """
    w, h = size
    sx = w / 512.0
    sy = h / 512.0
    scaled = [(x * sx, y * sy) for x, y in poly_512]
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(scaled, fill=255)
    # 1px blur at 1024 -> 0.5px clean AA edge at 512
    return mask.filter(ImageFilter.GaussianBlur(radius=0.9))


def slice_components(full_1024: Image.Image) -> dict[str, Image.Image]:
    """
    Slices the 1024x1024 bare-metal chassis into 7 cleanly separated,
    non-overlapping anatomical components with mutually complementary boundaries
    (so union of all 7 parts reconstructs the full chassis with zero seam gaps).

    Coordinates are specified in 512x512 reference space:
      - right_leg: character's right leg (viewer's left, x=175..268, y=230..500)
      - left_leg:  character's left leg  (viewer's right, x=268..398, y=230..512)
      - waist:     pelvic/hip girdle     (x=220..312, y=206..276)
      - torso:     armored chest/abdomen (x=214..322, y=90..226)
      - left_arm:  character's left arm  (viewer's right, x=296..388, y=75..320)
      - right_arm: character's right arm (viewer's left,  x=150..228, y=75..320)
      - head:      armored skull & upper neck (x=228..304, y=15..106)
    """
    size = full_1024.size

    # Define non-overlapping partition polygons covering the full 512x512 canvas.
    # Shared seams use identical vertex pairs so there is zero gap or overlap!

    # Shared seam vertices (512x512 reference coordinates):
    # Neck seam (head / torso) — strictly between the two raised pauldrons:
    neck_l = (238, 92)
    neck_m = (264, 100)
    neck_r = (290, 92)

    # Viewer-left shoulder seam (right_arm / torso):
    rsh_top = (224, 92)
    rsh_rivet = (224, 126)
    rsh_pit = (218, 156)
    rsh_low = (206, 200)

    # Viewer-right shoulder seam (torso / left_arm):
    lsh_top = (302, 92)
    lsh_rivet = (298, 126)
    lsh_pit = (314, 156)
    lsh_low = (328, 200)

    # Waist / torso seam (follows bottom V of ribbed abs above pelvic plates):
    wst_l = (220, 210)
    wst_m = (264, 224)
    wst_r = (308, 210)

    # Pelvic / leg hip-socket seams (follow dark mechanical ball-joint grooves):
    rhip_out = (224, 232)
    rhip_in = (252, 270)
    crotch_mid = (265, 278)
    lhip_in = (278, 270)
    lhip_out = (306, 230)

    polys: dict[str, list[tuple[float, float]]] = {
        "head": [
            (230, 0),
            (298, 0),
            (298, 86),
            neck_r,
            neck_m,
            neck_l,
            (230, 86),
        ],
        "right_arm": [
            (0, 0),
            (230, 0),
            (230, 86),
            rsh_top,
            rsh_rivet,
            rsh_pit,
            rsh_low,
            (204, 325),
            (0, 325),
        ],
        "left_arm": [
            (298, 0),
            (512, 0),
            (512, 325),
            (340, 325),
            lsh_low,
            lsh_pit,
            lsh_rivet,
            lsh_top,
            (298, 86),
        ],
        "torso": [
            (230, 86),
            neck_l,
            neck_m,
            neck_r,
            (298, 86),
            lsh_top,
            lsh_rivet,
            lsh_pit,
            lsh_low,
            wst_r,
            wst_m,
            wst_l,
            rsh_low,
            rsh_pit,
            rsh_rivet,
            rsh_top,
        ],
        "waist": [
            wst_l,
            wst_m,
            wst_r,
            lhip_out,
            lhip_in,
            crotch_mid,
            rhip_in,
            rhip_out,
        ],
        "right_leg": [
            (0, 325),
            (204, 325),
            (206, 200),
            wst_l,
            rhip_out,
            rhip_in,
            crotch_mid,
            (268, 512),
            (0, 512),
        ],
        "left_leg": [
            crotch_mid,
            lhip_in,
            lhip_out,
            wst_r,
            (328, 200),
            (334, 325),
            (512, 325),
            (512, 512),
            (268, 512),
        ],
    }

    # Rasterize mutually complementary masks so all parts recombine seamlessly
    raw_masks: dict[str, Image.Image] = {}
    for name, poly in polys.items():
        raw_masks[name] = make_polygon_mask(size, poly)

    w, h = size
    names = list(polys.keys())
    mask_pxs = {n: raw_masks[n].load() for n in names}
    src_px = full_1024.load()

    parts: dict[str, Image.Image] = {
        n: Image.new("RGBA", size, (0, 0, 0, 0)) for n in names
    }
    part_pxs = {n: parts[n].load() for n in names}

    for y in range(h):
        for x in range(w):
            r, g, b, a = src_px[x, y]
            if a == 0:
                continue
            weights = [mask_pxs[n][x, y] for n in names]
            total_w = sum(weights)
            if total_w == 0:
                continue
            for n, wt in zip(names, weights):
                if wt > 0:
                    pa = int(round(a * wt / total_w))
                    if pa > 0:
                        part_pxs[n][x, y] = (r, g, b, pa)

    return parts


def compose_stage_1024(
    full_1024: Image.Image,
    parts: dict[str, Image.Image],
    included: list[str],
) -> Image.Image:
    """
    Composes an assembly stage by summing alpha-normalized masks of `included`
    parts directly from `full_1024`, ensuring 100% seamless joins between
    assembled parts with zero seam lines or alpha cracks.
    """
    w, h = full_1024.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_px = out.load()
    src_px = full_1024.load()
    inc_pxs = [parts[n].load() for n in included]

    for y in range(h):
        for x in range(w):
            r, g, b, a = src_px[x, y]
            if a == 0:
                continue
            sum_a = 0
            for p_px in inc_pxs:
                sum_a += p_px[x, y][3]
            if sum_a > 0:
                out_px[x, y] = (r, g, b, min(a, sum_a))
    return out


def trim_crop(img: Image.Image) -> Image.Image:
    bbox = img.getbbox()
    if not bbox:
        return img
    return img.crop(bbox)


def add_drop_shadow(
    canvas: Image.Image,
    piece: Image.Image,
    paste_x: int,
    paste_y: int,
    shadow_offset: tuple[int, int] = (5, 9),
    blur_radius: float = 7.0,
    shadow_alpha: float = 0.56,
) -> None:
    """Composites a soft dark contact shadow followed by `piece` onto `canvas`."""
    alpha = piece.split()[3]
    sh_a = alpha.point(lambda v: int(round(v * shadow_alpha)))
    pad = int(blur_radius * 3) + 4
    sh_w = piece.width + pad * 2
    sh_h = piece.height + pad * 2
    shadow_layer = Image.new("RGBA", (sh_w, sh_h), (0, 0, 0, 0))
    black = Image.new("RGBA", piece.size, (8, 5, 10, 255))
    black.putalpha(sh_a)
    shadow_layer.paste(black, (pad, pad))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=blur_radius))

    # Composite shadow onto full-size temp layer to handle edge clipping cleanly
    full_shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    full_shadow.paste(
        shadow_layer,
        (paste_x + shadow_offset[0] - pad, paste_y + shadow_offset[1] - pad),
    )
    canvas.alpha_composite(full_shadow)

    full_piece = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    full_piece.paste(piece, (paste_x, paste_y))
    canvas.alpha_composite(full_piece)


def generate_parts_piles(parts_1024: dict[str, Image.Image]) -> dict[int, Image.Image]:
    """
    Programmatically composes the workbench parts piles for Weeks 0..6.
    Each part rests at a fixed workbench position, angle, scale, and stack order
    so parts vanish cleanly from their resting spot in the exact week they are
    welded onto the assembly rig (leaving Week 6 with only the unlit head on
    the workbench, and Week 7 empty).
    """
    # Installation order matching Weeks 1..7:
    install_order = [
        "right_leg",  # Week 1
        "left_leg",   # Week 2
        "waist",      # Week 3
        "torso",      # Week 4
        "left_arm",   # Week 5
        "right_arm",  # Week 6
        "head",       # Week 7
    ]

    # Prepare trimmed cutouts at 512-equivalent high detail
    trimmed = {k: trim_crop(v) for k, v in parts_1024.items()}

    # Fixed workbench layout on a 512x512 transparent canvas.
    # Spread naturally across the forge table (x ≈ 50..465, y ≈ 225..445) so
    # every single weekly removal is clearly visible in the spyglass.
    # Draw order: back-to-front (bottom of pile first, top pieces last).
    pile_layout: list[tuple[str, float, float, int, int]] = [
        # (part_name, scale_from_1024, rotation_deg_ccw, center_x_512, center_y_512)
        ("torso",     0.64, -14.0, 238, 308),  # Heavy armored chest resting back-center
        ("left_leg",  0.56,  72.0, 344, 340),  # Left leg angled clearly across right side
        ("right_leg", 0.56, -72.0, 146, 396),  # Right leg resting prominently front-left
        ("waist",     0.68,  20.0, 186, 356),  # Pelvic joint resting mid-left
        ("left_arm",  0.56,  44.0, 384, 382),  # Left arm angled far-right
        ("right_arm", 0.56, -34.0,  96, 336),  # Right arm angled far-left
        ("head",      0.82, -12.0, 274, 394),  # Unlit head resting prominently front-center!
    ]

    piles: dict[int, Image.Image] = {}
    for week in range(7):
        remaining = set(install_order[week:])
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))

        # Subtle workbench ambient grounding shadow underneath whatever parts remain
        ground_shadow = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        g_draw = ImageDraw.Draw(ground_shadow)
        if len(remaining) > 1:
            spread = 55 + 24 * len(remaining)
            g_draw.ellipse(
                (256 - spread, 372, 256 + spread, 444),
                fill=(6, 4, 8, 95),
            )
        else:
            # Just the head resting on the table
            g_draw.ellipse((212, 395, 318, 442), fill=(6, 4, 8, 105))
        ground_shadow = ground_shadow.filter(ImageFilter.GaussianBlur(radius=14))
        canvas.alpha_composite(ground_shadow)

        for part_name, scale, angle, cx, cy in pile_layout:
            if part_name not in remaining:
                continue
            crop = trimmed[part_name]
            nw = max(1, int(round(crop.width * scale)))
            nh = max(1, int(round(crop.height * scale)))
            resized = crop.resize((nw, nh), Image.Resampling.LANCZOS)
            rotated = resized.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
            px = cx - rotated.width // 2
            py = cy - rotated.height // 2
            add_drop_shadow(
                canvas,
                rotated,
                px,
                py,
                shadow_offset=(4, 8),
                blur_radius=6.0,
                shadow_alpha=0.58,
            )

        piles[week] = canvas

    return piles


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Loading source: {SOURCE_IMAGE}")
    src = Image.open(SOURCE_IMAGE)
    if src.size != (1024, 1024):
        src = src.resize((1024, 1024), Image.Resampling.LANCZOS)

    print("Running edge-connected flood-fill background removal with AA feathering...")
    full_1024 = remove_white_background_flood_fill(src)

    # Save 512x512 master bare-metal chassis
    full_512 = full_1024.resize((512, 512), Image.Resampling.LANCZOS)
    master_path = os.path.join(OUT_DIR, "robot_archmage_naked_frame.png")
    full_512.save(master_path, "PNG", optimize=True)
    print(f"Saved {master_path} ({full_512.size} {full_512.mode})")

    print("Slicing anatomical components at 1024x1024...")
    parts_1024 = slice_components(full_1024)

    stages_spec: list[tuple[int, str, str, list[str]]] = [
        (1, "archmage_stage_1_leg1.png",  "archmage_part_1_leg1.png",  ["right_leg"]),
        (2, "archmage_stage_2_legs.png",  "archmage_part_2_leg2.png",  ["right_leg", "left_leg"]),
        (3, "archmage_stage_3_waist.png", "archmage_part_3_waist.png", ["right_leg", "left_leg", "waist"]),
        (4, "archmage_stage_4_torso.png", "archmage_part_4_torso.png", ["right_leg", "left_leg", "waist", "torso"]),
        (5, "archmage_stage_5_arm1.png",  "archmage_part_5_arm1.png",  ["right_leg", "left_leg", "waist", "torso", "left_arm"]),
        (6, "archmage_stage_6_arms.png",  "archmage_part_6_arm2.png",  ["right_leg", "left_leg", "waist", "torso", "left_arm", "right_arm"]),
        (7, "archmage_stage_7_head.png",  "archmage_part_7_head.png",  ["right_leg", "left_leg", "waist", "torso", "left_arm", "right_arm", "head"]),
    ]

    for week, stage_filename, part_filename, included in stages_spec:
        if week == 7:
            stage_512 = full_512
        else:
            stage_1024 = compose_stage_1024(full_1024, parts_1024, included)
            stage_512 = stage_1024.resize((512, 512), Image.Resampling.LANCZOS)
        stage_path = os.path.join(OUT_DIR, stage_filename)
        stage_512.save(stage_path, "PNG", optimize=True)
        print(f"Saved {stage_path}")

        newly_added_key = included[-1]
        part_512 = parts_1024[newly_added_key].resize((512, 512), Image.Resampling.LANCZOS)
        part_path = os.path.join(OUT_DIR, part_filename)
        part_512.save(part_path, "PNG", optimize=True)
        print(f"Saved {part_path}")

    print("Composing workbench parts piles (Weeks 0..6)...")
    piles = generate_parts_piles(parts_1024)
    for week, pile_img in piles.items():
        pile_path = os.path.join(OUT_DIR, f"archmage_pile_week_{week}.png")
        pile_img.save(pile_path, "PNG", optimize=True)
        print(f"Saved {pile_path}")

    print("Done! All Robot Archmage assembly sprites generated cleanly.")


if __name__ == "__main__":
    main()
