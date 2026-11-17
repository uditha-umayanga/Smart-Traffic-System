const sql = require('mssql/msnodesqlv8');

// Each computer sets its own server in the DB_CONNECTION_STRING environment variable.
// Example (PowerShell):
// $env:DB_CONNECTION_STRING="Driver={ODBC Driver 17 for SQL Server};Server=YOUR_SERVER;Database=Smart_traffic_System;Trusted_Connection=yes;"
const connectionString =
  process.env.DB_CONNECTION_STRING ||
  'Driver={ODBC Driver 17 for SQL Server};Server=localhost;Database=Smart_traffic_System;Trusted_Connection=yes;';

const poolPromise = new sql.ConnectionPool({ connectionString })
  .connect()
  .then(pool => {
    console.log('Connected to SQL Server successfully!');
    return pool;
  })
  .catch(err => {
    console.error('Database connection failed:', err.message);
    console.error('Current server setting:', connectionString.match(/Server=([^;]*)/i)?.[1] || '(not found)');
    console.error('Set DB_CONNECTION_STRING with your own server name, and run Tables_webapp.sql.');
    return null;
  });

module.exports = {
  sql,
  poolPromise
};