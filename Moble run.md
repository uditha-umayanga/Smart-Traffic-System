* **Terminal 1 (Python ANPR - Port 8000):**


cd anpr_service

.\venv\Scripts\Activate

python -m uvicorn app:app --host 0.0.0.0 --port 8000





* **Terminal 2 (Node.js Web Server - Port 3000):**


npm start




* **Terminal 3 (Port Forwarding Tunnel - Port 3000 පමණයි):**


npx localtunnel --port 3000

