// Append chunk 2: helpers and login
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'server.js');
let content = fs.readFileSync(OUT, 'utf8');
let append = '';

append += `\n// ---------- Helpers ----------\n`;
append += `const clean = v => (typeof v === 'string' ? v.trim() : '');\n`;
append += `function requireOfficer(req, res, next) {\n`;
append += `  if (!req.session.officer) return res.status(401).json({ error: 'Please log in first.' });\n`;
append += `  next();\n`;
append += `}\n`;
append += `function requireDuty(req, res, next) {\n`;
append += `  if (!req.session.duty) return res.status(409).json({ error: 'Set your duty location first.' });\n`;
append += `  next();\n`;
append += `}\n`;
append += `function requireAdmin(req, res, next) {\n`;
append += `  if (!req.session.isAdmin) return res.status(401).json({ error: 'Admin login required.' });\n`;
append += `  next();\n`;
append += `}\n`;
append += `async function getPool(res) {\n`;
append += `  const pool = await poolPromise;\n`;
append += `  if (!pool) res.status(500).json({ error: 'Database is not connected. Check the terminal.' });\n`;
append += `  return pool;\n`;
append += `}\n`;
append += `function fail(res, err) {\n`;
append += `  console.error(err);\n`;
append += `  res.status(500).json({ error: 'Database error: ' + err.message });\n`;
append += `}\n`;
append += `\n`;

fs.appendFileSync(OUT, append, 'utf8');
console.log('Chunk 2 appended:', append.length, 'bytes');
