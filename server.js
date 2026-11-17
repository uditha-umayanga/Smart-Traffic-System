const express = require('express');
const session = require('express-session');
const path = require('path');
const crypto = require('crypto');
const fs = require('fs');
const bcrypt = require('bcryptjs');
const { sql, poolPromise } = require('./db');
const formidable = require('express-formidable');

const app = express();
const PORT = 3000;

// Admin login. Defaults to 0000 / 0000 unless overridden by environment variables.
const ADMIN_ID = process.env.ADMIN_ID || '0000';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '0000';
const SESSION_SECRET = process.env.SESSION_SECRET || crypto.randomBytes(32).toString('hex');

// Demerit points per offence (must match the options in add-violation.html)
const DEMERIT_POINTS = { speeding: 4, red_light: 3, lane_departure: 3, dui: 10, belt: 2 };
const DEMERIT_LIMIT = 24;

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(formidable({
  maxFileSize: 20 * 1024 * 1024, // 20 MB max upload
  multiples: false,
}));
app.use(session({
  secret: SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: { httpOnly: true, maxAge: 8 * 60 * 60 * 1000 } // 8-hour session
}));
app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => res.redirect('/index.html'));


// ---------- Helpers ----------
const clean = v => (typeof v === 'string' ? v.trim() : '');
function requireOfficer(req, res, next) {
  if (!req.session.officer) return res.status(401).json({ error: 'Please log in first.' });
  next();
}
function requireDuty(req, res, next) {
  if (!req.session.duty) return res.status(409).json({ error: 'Set your duty location first.' });
  next();
}
function requireAdmin(req, res, next) {
  if (!req.session.isAdmin) return res.status(401).json({ error: 'Admin login required.' });
  next();
}
async function getPool(res) {
  const pool = await poolPromise;
  if (!pool) res.status(500).json({ error: 'Database is not connected. Check the terminal.' });
  return pool;
}
function fail(res, err) {
  console.error(err);
  res.status(500).json({ error: 'Database error: ' + err.message });
}


// ---------- Helpers ----------
const clean = v => (typeof v === 'string' ? v.trim() : '');
function requireOfficer(req, res, next) {
  if (!req.session.officer) return res.status(401).json({ error: 'Please log in first.' });
  next();
}
function requireDuty(req, res, next) {
  if (!req.session.duty) return res.status(409).json({ error: 'Set your duty location first.' });
  next();
}
function requireAdmin(req, res, next) {
  if (!req.session.isAdmin) return res.status(401).json({ error: 'Admin login required.' });
  next();
}
async function getPool(res) {
  const pool = await poolPromise;
  if (!pool) res.status(500).json({ error: 'Database is not connected. Check the terminal.' });
  return pool;
}
function fail(res, err) {
  console.error(err);
  res.status(500).json({ error: 'Database error: ' + err.message });
}

