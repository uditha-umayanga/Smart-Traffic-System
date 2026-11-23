import os
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
import re
import cv2
import torch
import easyocr

BASE = os.path.dirname(os.path.abspath(__file__))

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

reader = easyocr.Reader(["en"], gpu=False)

ALLOWED = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"
TO_DIGIT = str.maketrans("OQDIZSBGT", "000125867")
TO_LETTER = str.maketrans("0125846", "OIZSBAG")

# CAB-1234 | AB-1234 | 250-1234 | WP-KA-5678 | SP-QL-9904
PLATE_RE = re.compile(r"^(?:[A-Z]{2}-)?(?:[A-Z]{2,3}|\d{2,3})-\d{4}$")
LENIENT_RE = re.compile(r"^[A-Z0-9-]{1,8}-\d{4}$")

PROVINCES = {"WP", "CP", "SP", "NP", "EP", "NW", "NC", "UP", "SG"}


def clean(text: str) -> str:
    """Sri Lankan Emblem (I/1) saha Province letters (WP, CP, SP...) ain karala main plate eka (e.g. KB-1502, CAB-1234) denawa."""
    t = re.sub(r"[^A-Z0-9]", "", text.upper())
    if len(t) < 5:
        return ""
    digits = t[-4:].translate(TO_DIGIT)          # last 4 hamadama digits
    prefix = t[:-4]
    if prefix.isdigit():                          # old format 250-1234
        return f"{prefix}-{digits}"

    prefix = prefix.translate(TO_LETTER)          # letters walata mixed digits fix

    # 1. Vam kelaware Sri Lanka rajya lanchana (Emblem) nisa ena 'I' ho 'L' ain karanawa
    if len(prefix) >= 4 and prefix[0] in {"I", "L", "1"}:
        prefix = prefix[1:]

    # 2. Mulata province code (WP, SP, CP, NP, EP, NW, NC, UP, SG) ekak aawoth eka ain karanawa
    if len(prefix) >= 4 and prefix[:2] in PROVINCES:
        prefix = prefix[2:]

    # 3. Agata province code ekak aawoth eka ain karanawa
    if len(prefix) >= 4 and prefix[-2:] in PROVINCES:
        prefix = prefix[:-2]

    # 4. Prefix eke akuru 3k ho eeta wada thiyenawanam (e.g. "CPKB", "PKB", "CAB", "BHG"):
    # Sri Lankan 3-letter series patan ganne 'B' ho 'C' akuren witharai.
    # Anthima akuru 3 'B' ho 'C' walin patan nogannawanam (e.g. "PKB"), anthima akuru 2 ("KB") witharak gannawa!
    if len(prefix) >= 3:
        if prefix[-3] in {"B", "C"}:
            prefix = prefix[-3:]
        else:
            prefix = prefix[-2:]

    return f"{prefix}-{digits}"


def _normalize_size(crop, target_w=420):
    """RAM crash (DefaultCPUAllocator) nathi wenna image size eka normalize karanawa."""
    h, w = crop.shape[:2]
    if w == 0 or h == 0:
        return crop
    scale = target_w / float(w)
    scale = max(0.35, min(2.0, scale))
    new_w = max(60, int(w * scale))
    new_h = max(30, int(h * scale))
    interp = cv2.INTER_CUBIC if scale > 1.0 else cv2.INTER_AREA
    return cv2.resize(crop, (new_w, new_h), interpolation=interp)


def _variants(crop):
    norm_crop = _normalize_size(crop, target_w=420)
    gray = cv2.cvtColor(norm_crop, cv2.COLOR_BGR2GRAY)
    yield "gray", gray

    smooth = cv2.GaussianBlur(gray, (3, 3), 0)
    yield "smooth", smooth

    clahe = cv2.createCLAHE(2.0, (8, 8)).apply(smooth)
    yield "clahe", clahe

    _, otsu = cv2.threshold(smooth, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    closed = cv2.morphologyEx(otsu, cv2.MORPH_OPEN, kernel)
    yield "otsu", closed


def _tokens(img):
    toks = []
    with torch.no_grad():
        results = reader.readtext(img, allowlist=ALLOWED, paragraph=False)
    for box, text, conf in results:
        xs = [p[0] for p in box]
        ys = [p[1] for p in box]
        clean_t = re.sub(r"[^A-Z0-9]", "", text.upper())
        if not clean_t:
            continue
        toks.append({
            "text": clean_t,
            "conf": float(conf),
            "x": min(xs),
            "y": min(ys),
            "h": max(ys) - min(ys),
            "cy": (min(ys) + max(ys)) / 2
        })
    return toks


def _order(toks, two_line):
    """Reading order: Two-line plates waladi Province + Top letters + Bottom digits hariyata pelagassanawa."""
    if not toks:
        return []
    H = max(t["h"] for t in toks)
    cys = [t["cy"] for t in toks]

    if two_line and (max(cys) - min(cys)) > 0.65 * H:
        digit_toks = [t for t in toks if t["text"].translate(TO_DIGIT).isdigit() and len(t["text"]) >= 3]
        if digit_toks:
            bottom_y = min(t["cy"] for t in digit_toks) - 0.25 * H
            top = sorted([t for t in toks if t["cy"] < bottom_y], key=lambda t: t["x"])
            bottom = sorted([t for t in toks if t["cy"] >= bottom_y], key=lambda t: t["x"])
            return top + bottom

        mid = (max(cys) + min(cys)) / 2
        top = sorted([t for t in toks if t["cy"] < mid], key=lambda t: t["x"])
        bottom = sorted([t for t in toks if t["cy"] >= mid], key=lambda t: t["x"])
        return top + bottom

    return sorted(toks, key=lambda t: t["x"])


def _drop_tiny(toks):
    """Podi province akuru (SP, WP) saha podi category akuru (D, P) ain karala pradhana loku akuru/ilakkam witharak gannawa."""
    if not toks:
        return toks
    H = max(t["h"] for t in toks)
    out = []
    for t in toks:
        if t["h"] < 0.72 * H:
            continue
        out.append(t)
    return out


def _ocr(crop):
    h, w = crop.shape[:2]
    two_line = (w / max(h, 1)) < 2.2
    votes = {}   # text -> [count, max_score]

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

        if score > 0:
            if text not in votes:
                votes[text] = [0, 0.0]
            votes[text][0] += 1
            votes[text][1] = max(votes[text][1], score)

    if not votes:
        return ("", 0.0)

    best_text, (count, max_score) = max(votes.items(), key=lambda kv: (kv[1][0], kv[1][1]))
    return (best_text, max_score)


def read_plate(image_bgr):
    """Returns (plate_text | None, confidence, bbox | None)"""
    crops = []
    if detector is not None:
        with torch.no_grad():
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

    if best[0] is None:
        h, w = image_bgr.shape[:2]
        text, conf = _ocr(image_bgr)
        if text:
            best = (text, conf, (0, 0, w, h))
    print(f"[plate_reader] result: {best[0]} ({best[1]:.2f})")
    return best