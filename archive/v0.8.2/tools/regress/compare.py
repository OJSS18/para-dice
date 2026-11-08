"""compare.py <nameA> <nameB> : pixel-compare two runs from tools/regress/run.sh (run from tools/regress/out)."""
import os, sys
from PIL import Image, ImageChops

base = "."
a, b = (os.path.join(base, n) for n in sys.argv[1:3])
la = open(os.path.join(a, "log.txt")).read().splitlines()
lb = open(os.path.join(b, "log.txt")).read().splitlines()
print("checkpoints:", len(la), len(lb))
bad = 0
for x, y in zip(la, lb):
    if x != y:
        print("STATE DIFF\n  A:", x, "\n  B:", y); bad += 1
fa = sorted(os.listdir(os.path.join(a, "shots")))
fb = sorted(os.listdir(os.path.join(b, "shots")))
if fa != fb:
    print("SHOT LIST DIFFERS", len(fa), len(fb)); bad += 1
for f in fa:
    if f not in fb: continue
    ia = Image.open(os.path.join(a, "shots", f)).convert("RGBA")
    ib = Image.open(os.path.join(b, "shots", f)).convert("RGBA")
    box = ImageChops.difference(ia, ib).getbbox()
    if box:
        diff = ImageChops.difference(ia, ib).convert("L").point(lambda v: 255 if v else 0)
        n = sum(1 for v in diff.getdata() if v)
        print("PIXEL DIFF", f, "pixels:", n, "box:", box); bad += 1
print("RESULT:", "IDENTICAL" if bad == 0 else f"{bad} differences", f"({len(fa)} screenshots)")
