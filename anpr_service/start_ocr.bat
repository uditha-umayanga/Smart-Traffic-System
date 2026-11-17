# Batch launch script for the ANPR OCR microservice
# Run from the anpr_service directory: .\start_ocr.bat
@echo off
setlocal
set ANPR_OCR_PORT=8765
set PYTHONUNBUFFERED=1
"C:\Users\MFIXPRO\AppData\Local\Python\bin\python.exe" "C:\Users\MFIXPRO\Documents\GitHub\Smart-Traffic-System\anpr_service\ocr_service.py"
