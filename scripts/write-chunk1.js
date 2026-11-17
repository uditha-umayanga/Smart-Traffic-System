// Write server.js in chunks using a temp file
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'server.js');
let content = '';

// Chunk 1: imports and setup
content += `const express = require('express');\n`;
content += `const session = require('express-session');\n`;
content += `const path = require('path');\n`;
content += `const crypto = require('crypto');\n`;
content += `const fs = require('fs');\n`;
content += `const bcrypt = require('bcryptjs');\n`;
content += `const { sql, poolPromise } = require('./db');\n`;
content += `const formidable = require('express-formidable');\n`;
content += `\n`;
content += `const app = express();\n`;
content += `const PORT = 3000;\n`;
content += `\n`;
content += `// Admin login. Defaults to 0000 / 0000 unless overridden by environment variables.\n`;
content += `const ADMIN_ID = process.env.ADMIN_ID || '0000';\n`;
content += `const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '0000';\n`;
content += `const SESSION_SECRET = process.env.SESSION_SECRET || crypto.randomBytes(32).toString('hex');\n`;
content += `\n`;
content += `// Demerit points per offence (must match the options in add-violation.html)\n`;
content += `const DEMERIT_POINTS = { speeding: 4, red_light: 3, lane_departure: 3, dui: 10, belt: 2 };\n`;
content += `const DEMERIT_LIMIT = 24;\n`;
content += `\n`;
content += `app.use(express.urlencoded({ extended: true }));\n`;
content += `app.use(express.json());\n`;
content += `app.use(formidable({\n`;
content += `  maxFileSize: 20 * 1024 * 1024, // 20 MB max upload\n`;
content += `  multiples: false,\n`;
content += `}));\n`;
content += `app.use(session({\n`;
content += `  secret: SESSION_SECRET,\n`;
content += `  resave: false,\n`;
content += `  saveUninitialized: false,\n`;
content += `  cookie: { httpOnly: true, maxAge: 8 * 60 * 60 * 1000 } // 8-hour session\n`;
content += `}));\n`;
content += `app.use(express.static(path.join(__dirname, 'public')));\n`;
content += `\n`;
content += `app.get('/', (req, res) => res.redirect('/index.html'));\n`;
content += `\n`;

fs.writeFileSync(OUT, content, 'utf8');
console.log('Chunk 1 written:', content.length, 'bytes');
