// Verify mssql module structure and Tedious driver availability
const sql = require('mssql');
console.log('mssql module loaded');
console.log('Connection:', typeof sql.Connection);
console.log('ConnectionPool:', typeof sql.ConnectionPool);
console.log('Pool:', typeof sql.Pool);
console.log('types:', Object.keys(sql).join(', '));
console.log('default reusable connection:', typeof sql.DefaultReusables);
console.log('tedious present in lib:', !!require('mssql/lib/tedious'));
