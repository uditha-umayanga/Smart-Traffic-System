// DB connectivity diagnostic helper
const sql = require('mssql/msnodesqlv8');


const tests = [
  {
    name: 'ODBC Driver 17 via msnodesqlv8, server=localhost, Trusted_Connection',
    conn: {
      server: 'localhost',
      database: 'Smart_traffic_System',
      options: { trustedConnection: true, encrypt: false, instanceName: '' },
    },
  },
];

async function main() {
  let i = 0;
  for (const t of tests) {
    try {
      console.log(`\x1b[1m=== TEST ${i + 1}: ${t.name} ===\x1b[0m`);
      const pool = await sql.connect(t.conn);
      console.log('✅ Connected to SQL Server');
      const r = await pool.request().query('SELECT DB_NAME() AS db, @@SERVERNAME AS srv, @@VERSION AS v');
      console.log(JSON.stringify(r.recordset, null, 2));
      await pool.close();
    } catch (e) {
      console.log('❌ ' + e.message.substring(0, 300));
    }
    i++;
  }
  process.exit(0);
}

main().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
