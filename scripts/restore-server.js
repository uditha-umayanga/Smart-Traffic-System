// Check server.js structure and restore missing /api/scan endpoint
const fs = require('fs');
const path = require('path');

const serverPath = path.join(__dirname, '..', 'server.js');
let content = fs.existsSync(serverPath) ? fs.readFileSync(serverPath, 'utf8') : '';

console.log('server.js exists:', fs.existsSync(serverPath));
console.log('server.js size:', fs.existsSync(serverPath) ? fs.statSync(serverPath).size : 0);
console.log('has /api/scan:', content.includes('/api/scan'));
console.log('has OCR endpoint:', content.includes('OCR plate-scan endpoint'));
console.log('has app.listen:', content.includes('app.listen'));

if (!content.includes('/api/scan')) {
  console.log('\n=== /api/scan endpoint is MISSING - restoring ===');
  const scanEndpoint = `
// ---------- ANPR OCR plate-scan endpoint ----------
// POST /api/scan - accepts a base64-encoded image or multipart/form-data file,
// sends it to the ANPR OCR microservice, and returns the detected plate.
app.post('/api/scan', requireOfficer, async (req, res) => {
  const pool = await getPool(res);
  if (!pool) return;

  try {
    // Read image: accept JSON body { image_base64 } OR multipart/form-data field "image"
    let raw;
    if (req.body && req.body.image_base64) {
      raw = Buffer.from(req.body.image_base64, 'base64');
    } else if (req.files && req.files.image) {
      // express-formidable: req.files.image is { type, name, path, data }
      const f = req.files.image;
      raw = Buffer.isBuffer(f.data) ? f.data : fs.readFileSync(f.path);
    } else {
      return res.status(400).json({ error: 'No image provided. Send JSON { image_base64: ... } or multipart/form-data with field "image".' });
    }

    if (raw.length === 0) {
      return res.status(400).json({ error: 'Empty image payload.' });
    }

    // Call ANPR OCR microservice
    const OCR_HOST = process.env.OCR_HOST || 'localhost';
    const OCR_PORT = process.env.OCR_PORT || '8765';
    const OCR_URL = \`http://$\{OCR_HOST}:$\{OCR_PORT}/scan\`;
    const OCR_TIMEOUT = 15000;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), OCR_TIMEOUT);

    const ocrRes = await fetch(OCR_URL, {
      method: 'POST',
      headers: req.headers['content-type'] === 'multipart/form-data' ? {} : { 'Content-Type': 'application/json' },
      body: req.body && req.body.image_base64 ? JSON.stringify({ image_base64: req.body.image_base64 }) : raw,
      signal: controller.signal,
    });
    clearTimeout(timer);

    if (!ocrRes.ok) {
      const ocrErr = await ocrRes.json().catch(() => ({ detail: 'OCR service returned error' }));
      return res.status(502).json({ error: 'OCR service error', detail: ocrErr.detail || ocrRes.statusText });
    }

    const ocrData = await ocrRes.json();
    res.json({ plate: ocrData.plate, confidence: ocrData.confidence, raw: ocrData.raw });
  } catch (err) {
    if (err.name === 'AbortError') {
      return res.status(504).json({ error: 'OCR service timeout' });
    }
    fail(res, err);
  }
});

`;

  // Insert after the requireOfficer middleware definitions (before the vehicles route)
  const insertAfter = '// ---------- Driver and vehicle lookups ----------';
  if (content.includes(insertAfter)) {
    content = content.replace(insertAfter, insertAfter + scanEndpoint);
    fs.writeFileSync(serverPath, content, 'utf8');
    console.log('OCR endpoint restored at line:', content.split('\n').indexOf(insertAfter) + 1);
  } else {
    console.log('ERROR: insert anchor not found');
  }
} else {
  console.log('OCR endpoint already present');
}
