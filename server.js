const express = require('express');
const session = require('express-session');
const path = require('path');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { sql, poolPromise } = require('./db');

const app = express();
const PORT = 3000;

// Admin login. Defaults to 0000 / 0000 unless overridden by environment variables.
const ADMIN_ID = process.env.ADMIN_ID || '0000';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '0000';
const SESSION_SECRET = process.env.SESSION_SECRET || crypto.randomBytes(32).toString('hex');

// Demerit points per offence (must match the options in add-violation.html)
const DEMERIT_POINTS = { speeding: 4, red_light: 3, lane_departure: 3, dui: 10, belt: 2 };
const DEMERIT_LIMIT = 24;
// Fine added to the vehicle's pending balance (LKR) per offence
const FINE_AMOUNTS = { speeding: 2500, red_light: 2500, lane_departure: 2000, dui: 25000, belt: 1000 };

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
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

// ---------- Officer login and session ----------
app.post('/api/login', async (req, res) => {
  const badgeId = clean(req.body.badgeId);
  const password = typeof req.body.password === 'string' ? req.body.password : '';
  if (!badgeId || !password) return res.status(400).json({ error: 'Badge ID and password are required.' });

  const pool = await getPool(res);
  if (!pool) return;
  try {
    const result = await pool.request()
      .input('badgeId', sql.VarChar, badgeId)
      .query('SELECT BadgeID, FullName, Division, PasswordHash FROM Officers WHERE BadgeID = @badgeId');

    const officer = result.recordset[0];
    const ok = officer && await bcrypt.compare(password, officer.PasswordHash).catch(() => false);
    if (!ok) return res.status(401).json({ error: 'Invalid Badge ID or password.' });

    req.session.officer = { badgeId: officer.BadgeID, fullName: officer.FullName, division: officer.Division };
    req.session.duty = null;
    res.json({ ok: true });
  } catch (err) { fail(res, err); }
});

app.post('/api/logout', (req, res) => {
  req.session.destroy(() => res.json({ ok: true }));
});

app.get('/api/session', (req, res) => {
  res.json({
    officer: req.session.officer || null,
    duty: req.session.duty || null,
    isAdmin: !!req.session.isAdmin
  });
});

// ---------- Duty location ----------
app.post('/api/duty', requireOfficer, async (req, res) => {
  const dutyLocation = clean(req.body.dutyLocation);
  const gpsCoords = clean(req.body.gpsCoords);
  const nearbyOfficer = clean(req.body.nearbyOfficer);

  if (!dutyLocation || !nearbyOfficer) {
    return res.status(400).json({ error: 'Duty location and nearby officer are required.' });
  }
  if (nearbyOfficer === req.session.officer.badgeId) {
    return res.status(400).json({ error: 'The nearby officer must be a different officer.' });
  }

  const pool = await getPool(res);
  if (!pool) return;
  try {
    const found = await pool.request()
      .input('badgeId', sql.VarChar, nearbyOfficer)
      .query('SELECT 1 AS ok FROM Officers WHERE BadgeID = @badgeId');

    if (!found.recordset.length) {
      return res.status(400).json({ error: `Officer ${nearbyOfficer} is not registered.` });
    }

    req.session.duty = { dutyLocation, gpsCoords, nearbyOfficer };
    res.json({ ok: true });
  } catch (err) { fail(res, err); }
});

// ---------- Admin ----------
app.post('/api/admin/login', (req, res) => {
  if (clean(req.body.adminId) !== ADMIN_ID || req.body.adminPass !== ADMIN_PASSWORD) {
    return res.status(401).json({ error: 'Invalid admin ID or password.' });
  }
  req.session.isAdmin = true;
  res.json({ ok: true });
});

app.get('/api/officers', requireAdmin, async (req, res) => {
  const pool = await getPool(res);
  if (!pool) return;
  try {
    const result = await pool.request().query(
      'SELECT BadgeID, FullName, Division, CreatedAt FROM Officers ORDER BY CreatedAt DESC'
    );
    res.json(result.recordset);
  } catch (err) { fail(res, err); }
});

app.post('/api/officers', requireAdmin, async (req, res) => {
  const fullName = clean(req.body.fullName);
  const nicNo = clean(req.body.nicNo);
  const badgeId = clean(req.body.newBadgeId);
  const division = clean(req.body.division);
  const newPass = typeof req.body.newPass === 'string' ? req.body.newPass : '';
  const confirmPass = typeof req.body.confirmPass === 'string' ? req.body.confirmPass : '';

  if (!fullName || !nicNo || !badgeId || !division || !newPass) {
    return res.status(400).json({ error: 'All fields are required.' });
  }
  if (newPass !== confirmPass) {
    return res.status(400).json({ error: 'Passwords do not match.' });
  }

  const pool = await getPool(res);
  if (!pool) return;
  try {
    const exists = await pool.request()
      .input('badgeId', sql.VarChar, badgeId)
      .input('nicNo', sql.VarChar, nicNo)
      .query('SELECT 1 AS ok FROM Officers WHERE BadgeID = @badgeId OR NICNo = @nicNo');

    if (exists.recordset.length) {
      return res.status(409).json({ error: 'An officer with this Badge ID or NIC already exists.' });
    }

    const passwordHash = await bcrypt.hash(newPass, 10);
    await pool.request()
      .input('badgeId', sql.VarChar, badgeId)
      .input('fullName', sql.VarChar, fullName)
      .input('nicNo', sql.VarChar, nicNo)
      .input('division', sql.VarChar, division)
      .input('passwordHash', sql.VarChar, passwordHash)
      .query(`INSERT INTO Officers (BadgeID, FullName, NICNo, Division, PasswordHash)
              VALUES (@badgeId, @fullName, @nicNo, @division, @passwordHash)`);

    res.json({ ok: true });
  } catch (err) { fail(res, err); }
});

// ---------- Driver and vehicle lookups ----------
app.get('/api/drivers/:id', requireOfficer, async (req, res) => {
  const id = clean(req.params.id);
  const pool = await getPool(res);
  if (!pool) return;
  try {
    const driver = await pool.request()
      .input('id', sql.VarChar, id)
      .query('SELECT DriverID, FullName, DemeritPoints, RiskStatus FROM Drivers WHERE DriverID = @id');

    if (!driver.recordset.length) {
      return res.status(404).json({ error: 'No driver found with this licence number.' });
    }

    const violations = await pool.request()
      .input('id', sql.VarChar, id)
      .query(`SELECT ViolationDate, ViolationType, RecordedLocation, DemeritPointsAdded, FineStatus, RegistrationPlate
              FROM Violations WHERE DriverID = @id ORDER BY ViolationDate DESC`);

    res.json({ driver: driver.recordset[0], violations: violations.recordset });
  } catch (err) { fail(res, err); }
});

app.get('/api/vehicles/:plate', requireOfficer, async (req, res) => {
  const pool = await getPool(res);
  if (!pool) return;
  try {
    // Ignores spaces, dashes and letter case, so "WP CAA-7892" and "wpcaa7892" match
    const vehicle = await pool.request()
      .input('plate', sql.VarChar, clean(req.params.plate))
      .query(`SELECT RegistrationPlate, MakeAndModel, RegisteredOwner, RevenueLicenseStatus,
                     InsuranceStatus, PendingFineBalance
              FROM Vehicles
              WHERE REPLACE(REPLACE(UPPER(RegistrationPlate), ' ', ''), '-', '')
                  = REPLACE(REPLACE(UPPER(@plate), ' ', ''), '-', '')`);

    if (!vehicle.recordset.length) {
      return res.status(404).json({ error: 'No vehicle found with this registration plate.' });
    }

    const plate = vehicle.recordset[0].RegistrationPlate;
    const unpaid = await pool.request()
      .input('plate', sql.VarChar, plate)
      .query(`SELECT COUNT(*) AS n FROM Violations
              WHERE RegistrationPlate = @plate AND FineStatus = 'Unpaid'`);

    res.json({ vehicle: vehicle.recordset[0], unpaidSummons: unpaid.recordset[0].n });
  } catch (err) { fail(res, err); }
});

// ---------- Add violation ----------
app.post('/save-violation', requireOfficer, requireDuty, async (req, res) => {
  const typedLic = clean(req.body.licNo);
  const typedVeh = clean(req.body.vehNo);
  const violationType = clean(req.body.violationType);
  const notes = clean(req.body.notes);
  const duty = req.session.duty;

  if (!typedLic || !typedVeh) {
    return res.status(400).json({ error: 'Driver licence and vehicle plate are required.' });
  }
  if (!Object.prototype.hasOwnProperty.call(DEMERIT_POINTS, violationType)) {
    return res.status(400).json({ error: 'Please select a valid traffic violation.' });
  }
  const points = DEMERIT_POINTS[violationType];

  const pool = await getPool(res);
  if (!pool) return;

  try {
    // Driver: use the existing record, or create a new one from the typed licence number
    const driver = await pool.request()
      .input('licNo', sql.VarChar, typedLic)
      .query('SELECT DriverID FROM Drivers WHERE DriverID = @licNo');
    const newDriver = !driver.recordset.length;
    const licNo = newDriver ? typedLic.toUpperCase() : driver.recordset[0].DriverID;

    // Vehicle: must already be in the registry (violations are issued after an ANPR plate scan)
    const vehicle = await pool.request()
      .input('vehNo', sql.VarChar, typedVeh)
      .query(`SELECT RegistrationPlate, RegisteredOwner FROM Vehicles
              WHERE REPLACE(REPLACE(UPPER(RegistrationPlate), ' ', ''), '-', '')
                  = REPLACE(REPLACE(UPPER(@vehNo), ' ', ''), '-', '')`);
    if (!vehicle.recordset.length) {
      return res.status(404).json({ error: `Vehicle ${typedVeh} is not in the registry. Scan the plate in Vehicle ANPR first.` });
    }
    const plate = vehicle.recordset[0].RegistrationPlate;
    // A new licence number has no name yet, so the vehicle's registered owner is used
    const driverName = vehicle.recordset[0].RegisteredOwner || 'Unknown Driver';

    const witness = await pool.request()
      .input('badge', sql.VarChar, duty.nearbyOfficer)
      .query('SELECT 1 AS ok FROM Officers WHERE BadgeID = @badge');
    if (!witness.recordset.length) {
      return res.status(400).json({ error: `Witness officer ${duty.nearbyOfficer} is not registered.` });
    }

    const tx = new sql.Transaction(pool);
    await tx.begin();
    try {
      if (newDriver) {
        await new sql.Request(tx)
          .input('licNo', sql.VarChar, licNo)
          .input('name', sql.VarChar, driverName)
          .query(`INSERT INTO Drivers (DriverID, FullName, DemeritPoints, RiskStatus)
                  VALUES (@licNo, @name, 0, 'NORMAL');`);
      }

      await new sql.Request(tx)
        .input('licNo', sql.VarChar, licNo)
        .input('plate', sql.VarChar, plate)
        .input('violationType', sql.VarChar, violationType)
        .input('points', sql.Int, points)
        .input('location', sql.VarChar, duty.dutyLocation)
        .input('witness', sql.VarChar, duty.nearbyOfficer)
        .input('notes', sql.VarChar(sql.MAX), notes)
        .query(`INSERT INTO Violations (DriverID, RegistrationPlate, ViolationType, DemeritPointsAdded,
                                        RecordedLocation, WitnessOfficerBadgeID, OfficerRemarks)
                VALUES (@licNo, @plate, @violationType, @points, @location, @witness, @notes);`);

      await new sql.Request(tx)
        .input('licNo', sql.VarChar, licNo)
        .input('points', sql.Int, points)
        .input('limit', sql.Int, DEMERIT_LIMIT)
        .query(`UPDATE Drivers
                SET DemeritPoints = DemeritPoints + @points,
                    RiskStatus = CASE WHEN DemeritPoints + @points >= @limit
                                      THEN 'HIGH RISK' ELSE 'NORMAL' END
                WHERE DriverID = @licNo;`);

      await new sql.Request(tx)
        .input('plate', sql.VarChar, plate)
        .input('fine', sql.Decimal(10, 2), FINE_AMOUNTS[violationType])
        .query(`UPDATE Vehicles
                SET PendingFineBalance = ISNULL(PendingFineBalance, 0) + @fine
                WHERE RegistrationPlate = @plate;`);

      await tx.commit();
    } catch (innerErr) {
      try { await tx.rollback(); } catch (_) { /* transaction may not have started */ }
      throw innerErr;
    }

    res.json({ ok: true, plate, licNo, points, newDriver });
  } catch (err) { fail(res, err); }
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
  console.log(`Open http://localhost:${PORT}/index.html in your browser`);
});