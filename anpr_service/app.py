import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from plate_reader import read_plate, detector

app = FastAPI(title="Plate recognition service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"ok": True, "yolo_model_loaded": detector is not None}


@app.post("/api/scan")
async def scan(image: UploadFile = File(...)):
    data = np.frombuffer(await image.read(), np.uint8)
    img = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(400, "Could not read the image. Send a JPG or PNG.")

    h, w = img.shape[:2]
    if max(h, w) > 1600:
        s = 1600 / max(h, w)
        img = cv2.resize(img, None, fx=s, fy=s)

    plate, conf, _ = read_plate(img)
    if not plate:
        return {"found": False, "message": "Could not find a number plate. Try a clearer photo."}
    return {"found": True, "plate": plate, "confidence": round(conf, 2)}
