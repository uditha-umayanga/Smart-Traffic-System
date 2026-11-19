* **Terminal 1 (Python ANPR - Port 8000):**



cd D:\\Documents\\Projects\\Smart-Traffic-System\\anpr\_service

..\\anpr\_service\\venv\\Scripts\\Activate

python -m uvicorn app:app --host 0.0.0.0 --port 8000





* **Terminal 2 (Node.js Web Server - Port 3000):**



cd D:\\Documents\\Projects\\Smart-Traffic-System

npm start





* **Terminal 3 (Port Forwarding Tunnel - Port 3000 පමණයි):**



npx localtunnel --port 3000

