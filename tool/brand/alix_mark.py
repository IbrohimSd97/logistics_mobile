"""ALIX logo belgisini chizish — barcha raster assetlar uchun yagona manba.

Geometriya brendbukdagi belgidan olingan (240 x 126 birlik, burchak radiusi 13):

    |####|#####|#####|######|@@@|@@@|      #  = charcoal panel
    |####|#####|#####|######|@@ | @@|      @  = orange panel
                              ^ oq tirqish  | = panellar orasidagi bo'shliq

Bo'shliqlar SHAFFOF qoldiriladi (knockout), shuning uchun belgi oq, krem va
to'q fonda bir xil to'g'ri ko'rinadi. Faqat to'liq oq fon kerak bo'lganda
`background` beriladi.
"""

from PIL import Image, ImageDraw

INK = (0x3A, 0x3A, 0x3A, 255)      # charcoal
ORANGE = (0xFF, 0x6A, 0x13, 255)   # ALIX orange
WHITE = (0xFF, 0xFF, 0xFF, 255)
ON_DARK = (0xF4, 0xF2, 0xEE, 255)  # to'q fondagi panellar rangi

# Belgining o'lchov birliklari (nisbatlar shu asosda hisoblanadi).
U_W, U_H = 240.0, 126.0
U_RADIUS = 13.0
U_GAPS = ((42, 48), (81, 87), (120, 126))  # vertikal bo'shliqlar
U_ORANGE_X = 177.0                          # orange panel shu yerdan boshlanadi
U_SLOT = (205.5, 24.0, 211.5, 102.0)        # oq tirqish: x0, y0, x1, y1

ASPECT = U_W / U_H  # ≈ 1.905


def draw_mark(width: int, supersample: int = 4, ink: tuple = INK) -> Image.Image:
    """Shaffof fonli belgi. Balandlik nisbatdan avtomatik hisoblanadi.

    `ink` — panellar rangi. To'q fonda ishlatilganda krem (`ON_DARK`) beriladi,
    aks holda charcoal panellar ko'rinmay qoladi.
    """
    height = round(width / ASPECT)
    s = supersample
    w, h = width * s, height * s
    k = w / U_W  # birlikdan pikselga

    def px(v: float) -> float:
        return v * k

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1) Butun belgi — yumaloq burchakli to'rtburchak (charcoal).
    draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=px(U_RADIUS), fill=ink)

    # 2) O'ng paneli orange: shakl maskasidan foydalanamiz, shunda o'ng
    #    burchaklar avtomatik yumaloq bo'lib qoladi.
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, w - 1, h - 1], radius=px(U_RADIUS), fill=255
    )
    right = Image.new("L", (w, h), 0)
    ImageDraw.Draw(right).rectangle([px(U_ORANGE_X), 0, w, h], fill=255)
    right = Image.composite(mask, Image.new("L", (w, h), 0), right)
    img.paste(Image.new("RGBA", (w, h), ORANGE), (0, 0), right)

    # 3) Panellar orasidagi bo'shliqlar — shaffof (knockout).
    #    Juda kichik o'lchamlarda bo'shliq bir pikseldan ham ingichka bo'lib
    #    ketadi, shuning uchun eng kamida 1 px qilib ushlab turamiz — aks holda
    #    belgi yaxlit to'rtburchakka aylanib qoladi.
    for x0, x1 in U_GAPS:
        left = px(x0)
        draw.rectangle([left, -1, max(px(x1) - 1, left + 1), h], fill=(0, 0, 0, 0))

    # 4) Orange panel ichidagi oq tirqish.
    sx0, sy0, sx1, sy1 = U_SLOT
    draw.rectangle(
        [px(sx0), px(sy0), max(px(sx1) - 1, px(sx0) + 1), max(px(sy1) - 1, px(sy0) + 1)],
        fill=WHITE,
    )

    return img.resize((width, height), Image.LANCZOS)


def mark_on_canvas(
    size: int,
    *,
    mark_ratio: float = 0.62,
    background=WHITE,
    radius_ratio: float = 0.0,
    ink: tuple = INK,
) -> Image.Image:
    """Belgi kvadrat kanvas markazida — ikonka va splash uchun.

    `mark_ratio` — belgi kengligining kanvasga nisbati.
    `radius_ratio` — kanvas burchaklari (0 = to'g'ri burchak, iOS shuni talab qiladi).
    """
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if background is not None:
        if radius_ratio > 0:
            plate = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            ImageDraw.Draw(plate).rounded_rectangle(
                [0, 0, size - 1, size - 1],
                radius=int(size * radius_ratio),
                fill=background,
            )
            canvas.alpha_composite(plate)
        else:
            canvas.alpha_composite(Image.new("RGBA", (size, size), background))

    mark = draw_mark(max(2, round(size * mark_ratio)), ink=ink)
    canvas.alpha_composite(
        mark, ((size - mark.width) // 2, (size - mark.height) // 2)
    )
    return canvas


def flatten(img: Image.Image, background=WHITE) -> Image.Image:
    """Alfa kanalini olib tashlaydi — App Store ikonkalari uchun shart."""
    base = Image.new("RGB", img.size, background[:3])
    base.paste(img, mask=img.split()[3])
    return base


def draw_monochrome(width: int, supersample: int = 4) -> Image.Image:
    """Bir rangli siluet — Android 13 "themed icon" uchun.

    Tizim bu tasvirni foydalanuvchi mavzusining rangiga bo'yaydi, shuning
    uchun faqat alfa kanali muhim: orange panel ham, oq tirqish ham yo'q.
    """
    height = round(width / ASPECT)
    s = supersample
    w, h = width * s, height * s
    k = w / U_W

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=U_RADIUS * k, fill=(0, 0, 0, 255))
    for x0, x1 in U_GAPS:
        left = x0 * k
        draw.rectangle([left, -1, max(x1 * k - 1, left + 1), h], fill=(0, 0, 0, 0))
    sx0, sy0, sx1, sy1 = U_SLOT
    draw.rectangle(
        [sx0 * k, sy0 * k, max(sx1 * k - 1, sx0 * k + 1), max(sy1 * k - 1, sy0 * k + 1)],
        fill=(0, 0, 0, 0),
    )
    return img.resize((width, height), Image.LANCZOS)
