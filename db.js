const sql = require('mssql');

// Each computer sets its own server in the DB_CONNECTION_STRING environment variable.
// Format (Tedious): Server=localhost,1433;Database=Smart_traffic_System;Trusted_Connection=yes;TrustServerCertificate=true
const connectionString =
  process.env.DB_CONNECTION_STRING ||
  'Server=localhost,1433;Database=Smart_traffic_System;Trusted_Connection=yes;TrustServerCertificate=true';

const poolPromise = sql
  .connect(connectionString)
  .then(pool => {
    console.log('Connected to SQL Server successfully!');
    return pool;
  })
  .catch(err => {
    console.error('Database connection failed:', err.message);
    console.error('Current server setting:', connectionString);
    console.error('Set DB_CONNECTION_STRING with your own server name, and run Tables_webapp.sql.');
    return null;
  });

module.exports = {
  sql,
  poolPromise
};
