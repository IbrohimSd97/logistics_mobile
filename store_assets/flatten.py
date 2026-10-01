"""Store PNG'larini alfa-kanalsiz RGB ga o'tkazadi (App Store talabi).

    python3 store_assets/flatten.py
"""
import glob
import os

from PIL import Image

root = os.path.dirname(os.path.abspath(__file__))
for path in glob.glob(os.path.join(root, '**', '*.png'), recursive=True):
    img = Image.open(path)
    if img.mode != 'RGB':
        img.convert('RGB').save(path, optimize=True)
