"""
ANPR OCR Microservice
=======================
Serves plate-text extraction over HTTP (FastAPI).

Requests (POST /):
  - multipart/form-data
    - image (file binary)
  - OR JSON body:
    - image_base64 (str)

Responses:
  - 200 { "plate": "<detected text>", "confidence": <0..1>, "raw": "..." }
  - 500 with error detail when OCR cannot run or no plate is detected
"""
from __future__ import annotations

import logging
import os
import base64
from pathlib import Path
from typing import Optional

import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException
from pydantic import BaseModel

ROOT = Path(__file__).resolve().parent
MODEL_DIR = ROOT / "model"
MODEL_DIR.mkdir(exist_ok=True)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("anpr-ocr")

try:
    from rapidocr_onnxruntime import RapidOCR
    _HAS_RAPIDOCR = True
except Exception as exc:
    RapidOCR = None
    _HAS_RAPIDOCR = False
    logger.warning("rapidocr-onnxruntime unavailable: %s. Falling back to pytesseract.", exc)

try:
    import pytesseract
    from PIL import Image
except Exception as exc:
    pytesseract = None
    Image = None
    logger.warning("pytesseract/PIL unavailable: %s", exc)

app = FastAPI(title="ANPR OCR Service", version="1.0.0")


class ScanBody(BaseModel):
    image_base64: str


class ScanResult(BaseModel):
    plate: str
    confidence: float
    raw: Optional[str] = None


class ScanError(BaseModel):
    detail: str


def _decode_image(data: bytes) -> Optional[np.ndarray]:
    """Decode raw bytes to an OpenCV image (BGR). Returns None on failure."""
    try:
        arr = np.frombuffer(data, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        return img
    except Exception:
        return None


def _to_rgb_bgr(img_bgr: np.ndarray) -> np.ndarray:
    if img_bgr.ndim == 2:
        img_bgr = cv2.cvtColor(img_bgr, cv2.COLOR_GRAY2BGR)
    if img_bgr.shape[2] == 4:
        img_bgr = cv2.cvtColor(img_bgr, cv2.COLOR_BGRA2BGR)
    return img_bgr


def _ocr_with_rapidocr(img_bgr: np.ndarray) -> tuple[str, float, Optional[str]]:
    if RAPIDOCR is None:
        raise RuntimeError("No OCR backend available")
    results = RAPIDOCR(img_bgr)
    if not results:
        raise RuntimeError("No plate detected")
    texts, scores, _ = results
    best_idx = int(np.argmax(np.asarray(scores, dtype=np.float32))) if scores else 0
    plate_text = str(texts[best_idx]) if texts else ""
    confidence = float(scores[best_idx]) if scores else 0.0
    raw = "; ".join(f"{t} (conf {s:.2f})" for t, s in zip(texts, scores))
    if not plate_text.strip():
        raise RuntimeError("OCR extracted empty plate text")
    return plate_text, confidence, raw


def _ocr_with_pytesseract(img_bgr: np.ndarray) -> tuple[str, float, Optional[str]]:
    if pytesseract is None or Image is None:
        raise RuntimeError("No OCR backend available")
    pil = Image.fromarray(cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB))
    raw = pytesseract.image_to_string(
        pil,
        config="--psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-",
    )
    plate_text = raw.strip()
    if not plate_text:
        raise RuntimeError("No plate text detected")
    expected = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
    matched = sum(1 for ch in plate_text if ch in expected)
    confidence = matched / max(len(plate_text), 1)
    return plate_text, confidence, raw


# ============================================================================
# Application state
# ============================================================================
RAPIDOCR = RapidOCR() if _HAS_RAPIDOCR else None
BACKEND = os.getenv("ANPR_OCR_BACKEND", "rapidocr")


@app.post("/scan", response_model=ScanResult, responses={500: {"model": ScanError}})
async def scan_image(body: ScanBody | None = None, image: UploadFile = File(...)):
    """
    Extract the license-plate text from an uploaded image.

    Accepts multipart/form-data with a file field named ``image`` (or ``image_base64``
    in a JSON body). Returns the detected plate plus a confidence score so the UI
    can decide whether to auto-verify or fall back to manual entry.
    """
    if body is not None and body.image_base64:
        data = base64.b64decode(body.image_base64)
    else:
        if image is None:
            raise HTTPException(status_code=400, detail="No image provided (multipart or JSON)")
        data = await image.file.read()
        await image.file.close()

    if not data:
        raise HTTPException(status_code=400, detail="Empty image payload")

    img_bgr = _decode_image(data)
    if img_bgr is None:
        raise HTTPException(status_code=400, detail="Could not decode image payload")

    if BACKEND == "rapidocr":
        plate, confidence, raw = _ocr_with_rapidocr(_to_rgb_bgr(img_bgr))
    else:
        plate, confidence, raw = _ocr_with_pytesseract(_to_rgb_bgr(img_bgr))

    plate = plate.strip().upper()
    return {"plate": plate, "confidence": round(confidence, 4), "raw": raw}


@app.get("/health")
async def health():
    return {
        "service": "anpr-ocr",
        "backend": BACKEND,
        "rapidocr_available": _HAS_RAPIDOCR,
        "pytesseract_available": pytesseract is not None,
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("ANPR_OCR_PORT", "8765"))
    uvicorn.run(app, host="0.0.0.0", port=port)
