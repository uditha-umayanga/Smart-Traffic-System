import os
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
import re
import cv2
import easyocr

BASE = os.path.dirname(os.path.abspath(__file__))

# Ape trained model eka (plate_detector.pt). Wena name ekak nam PLATE_MODEL env variable eken denna puluwan.
MODEL_CANDIDATES = [
    os.environ.get("PLATE_MODEL", ""),
    os.path.join(BASE, "plate_detector.pt"),
    os.path.join(BASE, "best.pt"),
]
detector = None
for path in MODEL_CANDIDATES:
    if path and os.path.exists(path):
        from ultralytics import YOLO
        detector = YOLO(path)
        print(f"[plate_reader] YOLO model loaded: {path}")
        break
if detector is None:
    print("[plate_reader] WARNING: plate_detector.pt hoyaganna beri una. Full-image OCR witharai wada karanne.")

reader = easyocr.Reader(["en"], gpu=False)   # NVIDIA GPU thiyenawanam True karanna

ALLOWED = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"
TO_DIGIT = str.maketrans("OQDIZSBGT", "000125867")
TO_LETTER = str.maketrans("0125846", "OIZSBAG")

# CAB-1234 | AB-1234 | 250-1234 | WP-KA-5678
PLATE_RE = re.compile(r"^(?:[A-Z]{2}-)?(?:[A-Z]{2,3}|\d{2,3})-\d{4}$")
LENIENT_RE = re.compile(r"^[A-Z0-9-]{1,8}-\d{4}$")


PROVINCES = {"WP", "CP", "SP", "NP", "EP", "NW", "NC", "UP", "SG"}

def clean(text: str) -> str:
    """OCR text eka Sri Lankan format ekata hadanawa (O<->0, I<->1 wage errors fix)."""
    t = re.sub(r"[^A-Z0-9]", "", text.upper())
    if len(t) < 5:
        return ""
    digits = t[-4:].translate(TO_DIGIT)          # last 4 hamadama digits
    prefix = t[:-4]
    if prefix.isdigit():                          # old format 250-1234
        return f"{prefix}-{digits}"
    prefix = prefix.translate(TO_LETTER)          # letters walata mixed digits fix
    if len(prefix) in (4, 5):                     # WPKG -> WP-KG or QLSP -> SP-QL
        if prefix[-2:] in PROVINCES and prefix[:2] not in PROVINCES:
            prefix = f"{prefix[-2:]}-{prefix[:-2]}"
        elif prefix[:2] in PROVINCES:
            prefix = f"{prefix[:2]}-{prefix[2:]}"
        else:
            prefix = f"{prefix[:2]}-{prefix[2:]}"
    return f"{prefix}-{digits}"


def _variants(crop):
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    yield "gray", gray
    yield "clahe", cv2.createCLAHE(2.0, (8, 8)).apply(gray)
    yield "thresh", cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                          cv2.THRESH_BINARY, 31, 10)


def _tokens(img):
    toks = []
    for box, text, conf in reader.readtext(img, allowlist=ALLOWED):
        xs = [p[0] for p in box]
        ys = [p[1] for p in box]
        toks.append({"text": text, "conf": float(conf), "x": min(xs), "h": max(ys) - min(ys),
                     "cy": (min(ys) + max(ys)) / 2})
    return toks


def _order(toks, two_line):
    """Reading order. Tek line plate ekak nam x walin witharai (loku/podi akuru y wenas nisa)."""
    if not toks:
        return []
    H = max(t["h"] for t in toks)
    cys = [t["cy"] for t in toks]
    if two_line and (max(cys) - min(cys)) > 0.8 * H:      # line 2k thiyena plate (bike / three-wheeler)
        mid = (max(cys) + min(cys)) / 2
        top = sorted([t for t in toks if t["cy"] < mid], key=lambda t: t["x"])
        bottom = sorted([t for t in toks if t["cy"] >= mid], key=lambda t: t["x"])
        return top + bottom
    return sorted(toks, key=lambda t: t["x"])


def _drop_tiny(toks):
    """Plate eke maddhe thiyena podi akuru (e.g. WP KG-P 7129 eke podi P) ain karanawa."""
    if not toks:
        return toks
    H = max(t["h"] for t in toks)
    out = []
    for i, t in enumerate(toks):
        alnum = re.sub(r"[^A-Z0-9]", "", t["text"].upper())
        if i > 0 and t["h"] < 0.55 * H and len(alnum) <= 1:
            continue
        out.append(t)
    return out


def _ocr(crop):
    h, w = crop.shape[:2]
    two_line = (w / max(h, 1)) < 2.2
    best = ("", 0.0)
    for name, img in _variants(crop):
        toks = _drop_tiny(_order(_tokens(img), two_line))
        if not toks:
            continue
        raw = "".join(t["text"] for t in toks)
        conf = sum(t["conf"] for t in toks) / len(toks)
        text = clean(raw)
        strict = bool(text and PLATE_RE.match(text))
        lenient = bool(text and LENIENT_RE.match(text))
        score = conf if strict else (conf * 0.6 if lenient else 0.0)
        print(f"[ocr:{name}] raw='{raw}' -> '{text}' conf={conf:.2f} strict={strict} lenient={lenient}")
        if score > best[1]:
            best = (text, score)
    return best


def read_plate(image_bgr):
    """Returns (plate_text | None, confidence, bbox | None)"""
    crops = []
    if detector is not None:
        boxes = detector(image_bgr, conf=0.4, verbose=False)[0].boxes.xyxy
        print(f"[plate_reader] YOLO plates found: {len(boxes)}")
        for box in boxes:
            x1, y1, x2, y2 = map(int, box)
            pad = 6
            crops.append(((x1, y1, x2, y2),
                          image_bgr[max(0, y1 - pad):y2 + pad, max(0, x1 - pad):x2 + pad]))

    best = (None, 0.0, None)
    for bbox, crop in crops:
        if crop.size == 0:
            continue
        text, conf = _ocr(crop)
        if text and conf > best[1]:
            best = (text, conf, bbox)

    # Model eka plate hoyagaththe naththam / OCR fail unoth: full image eka try karanawa
    if best[0] is None:
        h, w = image_bgr.shape[:2]
        text, conf = _ocr(image_bgr)
        if text:
            best = (text, conf, (0, 0, w, h))
    print(f"[plate_reader] result: {best[0]} ({best[1]:.2f})")
    return best
