#!/usr/bin/env python3
# OCR service dependency check
import sys
print("Python:", sys.version.split()[0])

try:
    import PIL
    print("PIL:", PIL.__version__)
except ImportError as e:
    print("PIL: NOT INSTALLED", e)

try:
    import pytesseract
    print("pytesseract: OK")
except ImportError as e:
    print("pytesseract: NOT INSTALLED", e)

try:
    import fastapi
    print("fastapi:", fastapi.__version__)
except ImportError as e:
    print("fastapi: NOT INSTALLED", e)

try:
    import uvicorn
    print("uvicorn: OK")
except ImportError as e:
    print("uvicorn: NOT INSTALLED", e)

try:
    import pydantic
    print("pydantic:", pydantic.VERSION if hasattr(pydantic, 'VERSION') else '2.x')
except ImportError as e:
    print("pydantic: NOT INSTALLED", e)

try:
    import multipart
    print("python-multipart: OK")
except ImportError as e:
    print("python-multipart: NOT INSTALLED", e)
