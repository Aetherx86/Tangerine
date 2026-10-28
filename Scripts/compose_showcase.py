#!/usr/bin/env python3
import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_showcase():
    W, H = 1280, 800
    canvas = Image.new("RGBA", (W, H), (14, 16, 22, 255))
    draw = ImageDraw.Draw(canvas)

    # 1. Background Luxury Gradient & Subtle Glow
    for y in range(H):
        t = y / float(H)
        r = int(18 * (1 - t) + 11 * t)
        g = int(21 * (1 - t) + 13 * t)
        b = int(29 * (1 - t) + 19 * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

    # Glow layers
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    # Warm amber glow top-left
    for r in range(450, 0, -25):
        alpha = int(22 * (1 - r / 450.0))
        glow_draw.ellipse([340 - r, 160 - r, 340 + r, 160 + r], fill=(255, 130, 20, alpha))
    
    # Cool violet-blue backlight top-right
    for r in range(400, 0, -25):
        alpha = int(18 * (1 - r / 400.0))
        glow_draw.ellipse([1050 - r, 190 - r, 1050 + r, 190 + r], fill=(85, 105, 235, alpha))

    canvas = Image.alpha_composite(canvas, glow)
    draw = ImageDraw.Draw(canvas)

    # Fonts
    font_title_bold = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 22)
    font_subtitle = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 12)
    font_card_title = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 14)
    font_badge = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 11)
    font_caption = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 11)
    font_caption_bold = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 11)
    font_pill_key = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 10)

    # Top Header
    app_icon_path = "Resources/AppIcon.png"
    if os.path.exists(app_icon_path):
        icon = Image.open(app_icon_path).convert("RGBA").resize((44, 44), Image.Resampling.LANCZOS)
        mask = Image.new("L", (44, 44), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.rounded_rectangle([0, 0, 44, 44], radius=10, fill=255)
        canvas.paste(icon, (24, 20), mask)

    draw.text((78, 20), "Tangerine", font=font_title_bold, fill=(255, 255, 255, 255))
    # Tangerine orange badge for "PRO RECREATION"
    draw.rounded_rectangle([190, 22, 314, 42], radius=6, fill=(255, 120, 0, 45), outline=(255, 130, 0, 180))
    draw.text((199, 25), "FULL RECREATION", font=font_pill_key, fill=(255, 175, 55, 255))

    draw.text((78, 46), "Native macOS Radial Drag-and-Drop Converter, File Tools & Metadata Suite", font=font_subtitle, fill=(145, 155, 175, 255))

    # Top Right Badges
    badges = [
        ("✦ Fully Unlocked (No Limits)", (255, 140, 20, 40), (255, 150, 40, 180), (255, 190, 80, 255)),
        ("⚡︎ 47/47 Tests Passed", (40, 160, 90, 40), (50, 180, 100, 180), (120, 240, 160, 255)),
        (" Native & 100% Offline", (50, 60, 80, 70), (120, 140, 180, 120), (210, 220, 240, 255)),
    ]
    cur_x = W - 24
    for text, fill_col, border_col, text_col in reversed(badges):
        bbox = font_badge.getbbox(text)
        bw = (bbox[2] - bbox[0]) + 18
        bh = 26
        bx = cur_x - bw
        draw.rounded_rectangle([bx, 28, bx + bw, 28 + bh], radius=13, fill=fill_col, outline=border_col)
        draw.text((bx + 9, 34), text, font=font_badge, fill=text_col)
        cur_x = bx - 10

    # Helper: draw glass card
    def draw_glass_card(rect, title, pill=None, pill_col=(255, 130, 0, 180)):
        x0, y0, x1, y1 = rect
        # Shadow
        card_shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cs_draw = ImageDraw.Draw(card_shadow)
        cs_draw.rounded_rectangle([x0, y0 + 3, x1, y1 + 3], radius=14, fill=(0, 0, 0, 75))
        card_shadow = card_shadow.filter(ImageFilter.GaussianBlur(8))
        nonlocal canvas
        canvas = Image.alpha_composite(canvas, card_shadow)
        nonlocal draw
        draw = ImageDraw.Draw(canvas)

        # Card body
        card_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cl_draw = ImageDraw.Draw(card_layer)
        cl_draw.rounded_rectangle([x0, y0, x1, y1], radius=14, fill=(22, 26, 36, 215), outline=(255, 255, 255, 28))
        canvas = Image.alpha_composite(canvas, card_layer)
        draw = ImageDraw.Draw(canvas)

        # Header inside card
        draw.text((x0 + 16, y0 + 14), title, font=font_card_title, fill=(255, 255, 255, 255))
        if pill:
            p_bbox = font_badge.getbbox(pill)
            pw = (p_bbox[2] - p_bbox[0]) + 16
            px = x1 - 16 - pw
            draw.rounded_rectangle([px, y0 + 12, px + pw, y0 + 32], radius=10, fill=(pill_col[0], pill_col[1], pill_col[2], 35), outline=pill_col)
            draw.text((px + 8, y0 + 16), pill, font=font_badge, fill=(pill_col[0], pill_col[1], pill_col[2], 255))

    # Helper to auto-crop transparent margins and resize keeping aspect
    def load_and_fit(path, max_w, max_h, alpha_thresh=15):
        im = Image.open(path).convert("RGBA")
        arr = im.split()[-1]
        bbox = arr.point(lambda p: 255 if p > alpha_thresh else 0).getbbox()
        if bbox:
            im = im.crop(bbox)
        scale = min(max_w / float(im.width), max_h / float(im.height))
        target_size = (int(im.width * scale), int(im.height * scale))
        return im.resize(target_size, Image.Resampling.LANCZOS)

    # -------------------------------------------------------------
    # CARD 1: Radial Drag & Drop Wheels (Top Left)
    # -------------------------------------------------------------
    c1_rect = (24, 84, 664, 404)
    draw_glass_card(c1_rect, "Radial Drag & Drop Quick-Actions", "⇧ Shift  •  ⌘ Command  •  ⌃ Control", (255, 140, 20, 220))

    # 3 Wheels
    wheels = [
        ("wheel_convert.png", "⇧ Shift : Convert", "PNG • WEBP • GIF • TIFF • HEIC"),
        ("wheel_tools.png", "⌘ Cmd : File Tools", "Crop • Compress • Metadata • Edit"),
        ("wheel_actions.png", "⌃ Ctrl : Actions", "Terminal • Copy • AirDrop • Move")
    ]
    wheel_w = 196
    wheel_h = 210
    start_x = c1_rect[0] + 16
    wheel_y = c1_rect[1] + 46

    for i, (fn, w_title, w_desc) in enumerate(wheels):
        path = f"/tmp/tangerine_screenshots/{fn}"
        if os.path.exists(path):
            w_img = load_and_fit(path, wheel_w, wheel_h, alpha_thresh=25)
            wx = start_x + i * 204 + (wheel_w - w_img.width) // 2
            wy = wheel_y + (wheel_h - w_img.height) // 2
            canvas.paste(w_img, (wx, wy), w_img)
            draw = ImageDraw.Draw(canvas)

        # Labels below wheel
        lbl_y = wheel_y + wheel_h + 8
        t_box = font_caption_bold.getbbox(w_title)
        tw = t_box[2] - t_box[0]
        tx = start_x + i * 204 + (wheel_w - tw) // 2
        draw.text((tx, lbl_y), w_title, font=font_caption_bold, fill=(255, 180, 50, 255))

        d_box = font_caption.getbbox(w_desc)
        dw = d_box[2] - d_box[0]
        dx = start_x + i * 204 + (wheel_w - dw) // 2
        draw.text((dx, lbl_y + 18), w_desc, font=font_caption, fill=(150, 160, 180, 255))

    # Footnote inside Card 1
    draw.text((c1_rect[0] + 18, c1_rect[3] - 24), "✦ Instant drag-triggered CGEventTap • Polar hit testing • Dynamic citrus hub feedback", font=font_caption, fill=(125, 135, 155, 255))

    # -------------------------------------------------------------
    # CARD 2: Interactive Crop & Size Selector (Bottom Left)
    # -------------------------------------------------------------
    c2_rect = (24, 418, 664, 780)
    draw_glass_card(c2_rect, "Interactive Crop & Size Selector", "Aspect Ratio Presets & Dimensions", (60, 180, 110, 220))

    editor_path = "/tmp/tangerine_screenshots/editor_crop.png"
    if os.path.exists(editor_path):
        # Place editor on left side of card
        e_img = load_and_fit(editor_path, 400, 302, alpha_thresh=20)
        ex = c2_rect[0] + 18
        ey = c2_rect[1] + 46 + (306 - e_img.height) // 2
        canvas.paste(e_img, (ex, ey), e_img)
        draw = ImageDraw.Draw(canvas)

        # Sidebar with feature highlights on the right of editor
        sx = ex + e_img.width + 16
        sy = c2_rect[1] + 52
        
        draw.text((sx, sy), "CROP & EDIT SUITE", font=font_pill_key, fill=(255, 165, 40, 255))
        sy += 20

        features = [
            ("✂️ Aspect Presets", "1:1 Square, 4:3, 16:9, 3:2, Freeform"),
            ("📐 Pixel Precision", "Custom W × H inputs (800 × 800 px)"),
            ("✏️ Redact & Annotate", "Black box privacy & yellow highlighter"),
            ("🎛️ Adjust & Color", "Brightness, Contrast, Saturation sliders"),
            ("🎨 Add Background", "Padding & solid/gradient backdrop fills"),
            ("💾 Direct Overwrite", "Save cropped copy or replace original")
        ]
        for f_title, f_sub in features:
            draw.text((sx, sy), f_title, font=font_caption_bold, fill=(240, 245, 255, 255))
            draw.text((sx, sy + 15), f_sub, font=font_caption, fill=(145, 155, 175, 255))
            sy += 36

    # -------------------------------------------------------------
    # CARD 3: Metadata Inspector & Editor (Top Right)
    # -------------------------------------------------------------
    c3_rect = (684, 84, 1256, 594)
    draw_glass_card(c3_rect, "Metadata Inspector & Editor", "ExifTool Engine (EXIF, IPTC, GPS)", (255, 120, 40, 220))

    meta_path = "/tmp/tangerine_screenshots/metadata_editor.png"
    if os.path.exists(meta_path):
        m_img = load_and_fit(meta_path, 544, 452, alpha_thresh=20)
        mx = c3_rect[0] + (572 - m_img.width) // 2
        my = c3_rect[1] + 44 + (456 - m_img.height) // 2
        canvas.paste(m_img, (mx, my), m_img)
        draw = ImageDraw.Draw(canvas)

    # -------------------------------------------------------------
    # CARD 4: Progress HUD & System Integration (Bottom Right)
    # -------------------------------------------------------------
    c4_rect = (684, 608, 1256, 780)
    draw_glass_card(c4_rect, "Progress HUD & macOS System Integration", "Full Integration", (120, 160, 255, 220))

    # Progress HUD
    hud_path = "/tmp/tangerine_screenshots/progress_hud.png"
    if os.path.exists(hud_path):
        hud_img = load_and_fit(hud_path, 290, 68, alpha_thresh=20)
        hx = c4_rect[0] + 16
        hy = c4_rect[1] + 44
        canvas.paste(hud_img, (hx, hy), hud_img)
        draw = ImageDraw.Draw(canvas)

    # Capabilities Checklist
    checks = [
        ("✓ Finder Copy (⌘V)", "Uses NSFilenamesPboardType for real Finder paste"),
        ("✓ Terminal Launcher", "Opens target folder in /usr/bin/open -a Terminal"),
        ("✓ Illegal Format Guard", "ConversionMatrix blocks invalid conversions (e.g. md -> jpg)"),
        ("✓ Zero Paywalls", "100% unrestricted full version with no 20-use limits")
    ]
    cx = c4_rect[0] + 322
    cy = c4_rect[1] + 44
    for title, desc in checks:
        draw.text((cx, cy), title, font=font_caption_bold, fill=(120, 230, 160, 255))
        draw.text((cx, cy + 14), desc, font=font_caption, fill=(150, 160, 180, 255))
        cy += 28

    # Bottom footer line in Card 4
    draw.line([(c4_rect[0] + 16, c4_rect[1] + 132), (c4_rect[2] - 16, c4_rect[1] + 132)], fill=(255, 255, 255, 20))
    draw.text((c4_rect[0] + 16, c4_rect[1] + 140), "Tangerine for macOS  •  Engineered with Swift 6, SwiftUI & Metal  •  100% Offline, Fast & Private", font=font_caption, fill=(135, 145, 165, 255))

    # Save final showcase
    out_path = "/Users/sushikim/Documents/Tangerine/tangerine_showcase_1280x800.png"
    final_rgb = canvas.convert("RGB")
    final_rgb.save(out_path, "PNG", quality=95)
    print(f"Showcase generated at: {out_path} ({final_rgb.size[0]}x{final_rgb.size[1]})")

if __name__ == "__main__":
    create_showcase()
