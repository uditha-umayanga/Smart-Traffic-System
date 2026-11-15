const express = require('express');
const path = require('path');
const bcrypt = require('bcryptjs');
const { sql, poolPromise } = require('./db');

const app = express();
const PORT = 3000;

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Redirect the root URL to the login page
app.get('/', (req, res) => res.redirect('/index.html'));

// Officer list for the register page
app.get('/api/officers', async (req, res) => {
  const pool = await poolPromise;
  if (!pool) return res.status(500).json({ error: 'Database is not connected. Check the terminal.' });

  try {
    const result = await pool.request().query(
      'SELECT BadgeID, FullName, Division, CreatedAt FROM Officers ORDER BY CreatedAt DESC'
    );
    res.json(result.recordset);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// 1. Officer registration
app.post('/register', async (req, res) => {
  const { fullName, nicNo, newBadgeId, division, newPass, confirmPass } = req.body;

  if (!fullName || !nicNo || !newBadgeId || !division || !newPass) {
    return res.status(400).send("<script>alert('All fields are required.'); history.back();</script>");
  }
  if (newPass !== confirmPass) {
    return res.status(400).send("<script>alert('Passwords do not match!'); history.back();</script>");
  }

  const pool = await poolPromise;
  if (!pool) return res.status(500).send('Database is not connected. Check the terminal for details.');

  try {
    const check = await pool.request()
      .input('badgeId', sql.VarChar, newBadgeId)
      .input('nicNo', sql.VarChar, nicNo)
      .query('SELECT 1 FROM Officers WHERE BadgeID = @badgeId OR NICNo = @nicNo');

    if (check.recordset.length > 0) {
      return res.status(409).send("<script>alert('Officer with this Badge ID or NIC already exists!'); history.back();</script>");
    }

    const passwordHash = await bcrypt.hash(newPass, 10);

    await pool.request()
      .input('badgeId', sql.VarChar, newBadgeId)
      .input('fullName', sql.VarChar, fullName)
      .input('nicNo', sql.VarChar, nicNo)
      .input('division', sql.VarChar, division)
      .input('passwordHash', sql.VarChar, passwordHash)
      .query(`INSERT INTO Officers (BadgeID, FullName, NICNo, Division, PasswordHash)
              VALUES (@badgeId, @fullName, @nicNo, @division, @passwordHash)`);

    res.send("<script>alert('Officer registered successfully! You can now log in.'); window.location.href='register.html';</script>");
  } catch (err) {
    console.error(err);
    res.status(500).send('Database Error: ' + err.message);
  }
});

// 2. Add violation
app.post('/save-violation', async (req, res) => {
  const { licNo, vehNo, violationType, recordedLocation, witnessOfficer, notes } = req.body;

  const points = { speeding: 4, red_light: 3, lane_departure: 3, dui: 10, belt: 2 };
  const demeritPoints = points[violationType] ?? 2;

  const pool = await poolPromise;
  if (!pool) return res.status(500).send('Database is not connected. Check the terminal for details.');

  const tx = new sql.Transaction(pool);

  try {
    await tx.begin();

    await new sql.Request(tx)
      .input('licNo', sql.VarChar, licNo)
      .query(`MERGE Drivers AS t
              USING (SELECT @licNo AS DriverID) AS s ON t.DriverID = s.DriverID
              WHEN NOT MATCHED THEN INSERT (DriverID, FullName) VALUES (s.DriverID, 'Unknown');`);

    await new sql.Request(tx)
      .input('vehNo', sql.VarChar, vehNo)
      .query(`MERGE Vehicles AS t
              USING (SELECT @vehNo AS RegistrationPlate) AS s ON t.RegistrationPlate = s.RegistrationPlate
              WHEN NOT MATCHED THEN INSERT (RegistrationPlate, MakeAndModel, RegisteredOwner, RevenueLicenseStatus, InsuranceStatus)
              VALUES (s.RegistrationPlate, 'Unknown', 'Unknown', 'Unknown', 'Unknown');`);

    await new sql.Request(tx)
      .input('licNo', sql.VarChar, licNo)
      .input('vehNo', sql.VarChar, vehNo)
      .input('violationType', sql.VarChar, violationType)
      .input('demeritPoints', sql.Int, demeritPoints)
      .input('recordedLocation', sql.VarChar, recordedLocation)
      .input('witnessOfficer', sql.VarChar, witnessOfficer)
      .input('notes', sql.VarChar(sql.MAX), notes)
      .query(`INSERT INTO Violations (DriverID, RegistrationPlate, ViolationType, DemeritPointsAdded,
                                      RecordedLocation, WitnessOfficerBadgeID, OfficerRemarks)
              VALUES (@licNo, @vehNo, @violationType, @demeritPoints,
                      @recordedLocation, @witnessOfficer, @notes);`);

    await new sql.Request(tx)
      .input('licNo', sql.VarChar, licNo)
      .input('demeritPoints', sql.Int, demeritPoints)
      .query(`UPDATE Drivers
              SET DemeritPoints = DemeritPoints + @demeritPoints,
                  RiskStatus = CASE WHEN DemeritPoints + @demeritPoints >= 24
                                    THEN 'HIGH RISK' ELSE 'NORMAL' END
              WHERE DriverID = @licNo;`);

    await tx.commit();
    res.send("<script>alert('Violation recorded successfully!'); window.location.href='add-violation.html';</script>");
  } catch (err) {
    try { await tx.rollback(); } catch (_) { /* transaction may not have started */ }
    console.error(err);
    res.status(500).send('Error: ' + err.message);
  }
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
  console.log(`Open http://localhost:${PORT}/index.html in your browser`);
});