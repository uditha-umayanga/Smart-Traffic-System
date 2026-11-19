const sql = require('mssql/msnodesqlv8');

const config = {
    connectionString: "Driver={ODBC Driver 17 for SQL Server};Server=(localdb)\\MSSQLLocalDB;Database=Smart_traffic_System;Trusted_Connection=yes;"
};

let pool = null;
let connecting = null;

// Returns a connected pool, or null if the connection fails.
// A failed attempt is NOT cached, so the next request tries again.
async function getConnection() {
    if (pool && pool.connected) return pool;

    // If a connection attempt is already in progress, wait for it
    if (connecting) return connecting;

    connecting = (async () => {
        try {
            const newPool = await new sql.ConnectionPool(config).connect();
            newPool.on('error', err => {
                console.error('Database pool error:', err);
                pool = null;
            });
            pool = newPool;
            console.log('Connected to MS SQL Server LocalDB successfully!');
            return pool;
        } catch (err) {
            console.error('Database connection failed:', err.message);
            console.error('Check: LocalDB running (sqllocaldb start MSSQLLocalDB), database Smart_traffic_System exists, and ODBC Driver 17 is installed.');
            pool = null;
            return null;
        } finally {
            connecting = null;
        }
    })();

    return connecting;
}

// Try once at startup so you see the result in the terminal right away
getConnection();

// Same shape as before, so server.js works without changes
module.exports = {
    sql,
    get poolPromise() {
        return getConnection();
    }
};
