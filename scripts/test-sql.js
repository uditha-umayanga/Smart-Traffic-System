// Test SQL Server connection options (TCP, named instance)
const sql = require('mssql');

const tests = [
  {
    name: 'TCP localhost:1433 (default)',
    conn: { server: 'localhost', port: 1433, database: 'Smart_traffic_System', options: { trustedConnection: true, encrypt: false } },
  },
  {
    name: 'Named instance SQLEXPRESS via TDS',
    conn: { server: 'localhost', database: 'Smart_traffic_System', options: { trustedConnection: true, encrypt: false, instanceName: 'SQLEXPRESS' } },
  },
];

async function runTests() {
  for (const t of tests) {
    try {
      console.log(`\n=== ${t.name} ===`);
      const pool = await sql.connect(t.conn);
      console.log('✅ Connected');
      const r = await pool.request().query('SELECT DB_NAME() AS db, @@SERVERNAME AS srv');
      console.log(JSON.stringify(r.recordset, null, 2));
      await pool.close();
    } catch (e) {
      console.log('❌ ' + e.message.substring(0, 200));
    }
  }
  process.exit(0);
}

runTests().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
