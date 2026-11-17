# Windows launch script for the ANPR OCR microservice
# Run from the anpr_service directory: powershell.exe -File start_ocr.ps1
$ErrorActionPreference = "Stop"
$Env:ANPR_OCR_PORT = "8765"
$Env:PYTHONUNBUFFERED = "1"

& "C:/Users/MFIXPRO/AppData/Local/Python/bin/python.exe" "C:/Users/MFIXPRO/Documents/GitHub/Smart-Traffic-System/anpr_service/ocr_service.py"
