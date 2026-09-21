"""ALIX brend assetlarini qayta generatsiya qiladi.

Ishga tushirish (loyiha ildizidan):

    python3 tool/brand/generate_assets.py

Nima yaratiladi:
  * assets/brand/            — ilova ichida ishlatiladigan master PNG'lar
  * android mipmap + adaptive icon + splash drawable'lari
  * iOS AppIcon.appiconset va LaunchImage.imageset
  * macOS AppIcon.appiconset
  * web favicon, PWA ikonkalari (oddiy + maskable)

Logotip geometriyasi `alix_mark.py` da — raster fayllar qo'lda tahrirlanmaydi,
brend o'zgarsa faqat o'sha fayl yangilanadi va shu skript qayta yuriladi.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from alix_mark import (  # noqa: E402
    ON_DARK,
    draw_mark,
    draw_monochrome,
    flatten,
    mark_on_canvas,
)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CREAM = (0xF4, 0xF2, 0xEE, 255)


def out(*parts: str) -> str:
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def save(img: Image.Image, *parts: str) -> None:
    path = out(*parts)
    img.save(path)
    print("  ", os.path.relpath(path, ROOT), img.size)


# ── Ilova ichidagi master fayllar ───────────────────────────────────────────
def brand_assets() -> None:
    print("assets/brand")
    save(draw_mark(1024), "assets", "brand", "alix_mark.png")
    save(mark_on_canvas(1024, radius_ratio=0.22), "assets", "brand", "alix_icon.png")


# ── Android ─────────────────────────────────────────────────────────────────
ANDROID_RES = ("android", "app", "src", "main", "res")
# Legacy launcher ikonkasi (Android 7 va undan pastda) — oq fon, kvadrat.
ANDROID_MIPMAP = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# Adaptive icon: 108dp kanvas, ko'rinadigan zona atigi 66dp — belgi kichikroq.
ANDROID_ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
# Splash logotipi: kengligi 160dp.
ANDROID_SPLASH = {"mdpi": 160, "hdpi": 240, "xhdpi": 320, "xxhdpi": 480, "xxxhdpi": 640}


def android() -> None:
    print("android")
    for dpi, size in ANDROID_MIPMAP.items():
        save(mark_on_canvas(size), *ANDROID_RES, f"mipmap-{dpi}", "ic_launcher.png")
    for dpi, size in ANDROID_ADAPTIVE.items():
        # 0.40 ≈ 43dp/108dp — 66dp xavfsiz zonadan chiqmaydi.
        save(
            mark_on_canvas(size, mark_ratio=0.40, background=None),
            *ANDROID_RES,
            f"drawable-{dpi}",
            "ic_launcher_foreground.png",
        )
    for dpi, size in ANDROID_ADAPTIVE.items():
        # Android 13+ "themed icon": tizim o'zi bo'yaydi, faqat siluet kerak.
        mono = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        shape = draw_monochrome(round(size * 0.40))
        mono.alpha_composite(
            shape, ((size - shape.width) // 2, (size - shape.height) // 2)
        )
        save(mono, *ANDROID_RES, f"drawable-{dpi}", "ic_launcher_monochrome.png")
    for dpi, width in ANDROID_SPLASH.items():
        save(draw_mark(width), *ANDROID_RES, f"drawable-{dpi}", "splash_logo.png")
        # To'q rejim uchun krem panelli variant — aks holda charcoal belgi
        # qora fonda ko'rinmaydi.
        save(
            draw_mark(width, ink=ON_DARK),
            *ANDROID_RES, f"drawable-night-{dpi}", "splash_logo.png",
        )
    # Android 12+ splash API'si ikonkani doira ichiga joylaydi: kanvas 108dp,
    # ko'rinadigan qismi ~66dp.
    for dpi, size in ANDROID_ADAPTIVE.items():
        save(
            mark_on_canvas(size, mark_ratio=0.40, background=None),
            *ANDROID_RES, f"drawable-{dpi}", "splash_icon.png",
        )
        save(
            mark_on_canvas(size, mark_ratio=0.40, background=None, ink=ON_DARK),
            *ANDROID_RES, f"drawable-night-{dpi}", "splash_icon.png",
        )


# ── iOS ─────────────────────────────────────────────────────────────────────
# App Store ikonkalarida alfa kanal BO'LMASLIGI kerak, burchaklar ham
# yumaloqlanmaydi — tizim o'zi kesadi.
IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}
IOS_LAUNCH = {"LaunchImage.png": 160, "LaunchImage@2x.png": 320, "LaunchImage@3x.png": 480}


def ios() -> None:
    print("ios")
    for name, size in IOS_ICONS.items():
        save(
            flatten(mark_on_canvas(size)),
            "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset", name,
        )
    for name, width in IOS_LAUNCH.items():
        save(
            draw_mark(width),
            "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset", name,
        )


# ── macOS ───────────────────────────────────────────────────────────────────
# macOS ikonkasi o'zi yumaloq plastinka bo'ladi va atrofida bo'sh joy qoladi.
MACOS_ICONS = [16, 32, 64, 128, 256, 512, 1024]


def macos() -> None:
    print("macos")
    for size in MACOS_ICONS:
        plate = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        inner = mark_on_canvas(
            round(size * 0.82), mark_ratio=0.62, radius_ratio=0.225
        )
        offset = (size - inner.width) // 2
        plate.alpha_composite(inner, (offset, offset))
        save(plate, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset",
             f"app_icon_{size}.png")


# ── Web ─────────────────────────────────────────────────────────────────────
def web() -> None:
    print("web")
    save(flatten(mark_on_canvas(32)), "web", "favicon.png")
    for size in (192, 512):
        save(mark_on_canvas(size), "web", "icons", f"Icon-{size}.png")
        # Maskable: tizim ikonkani kesishi mumkin, shuning uchun belgi kichikroq
        # va fon butun kvadratni to'ldiradi.
        save(
            mark_on_canvas(size, mark_ratio=0.46),
            "web", "icons", f"Icon-maskable-{size}.png",
        )


if __name__ == "__main__":
    brand_assets()
    android()
    ios()
    macos()
    web()
    print("\nTayyor.")
