const sql = require('mssql/msnodesqlv8');

const config = {
    connectionString: "Driver={ODBC Driver 17 for SQL Server};Server=(localdb)\\MSSQLLocalDB;Database=Smart_traffic_System;Trusted_Connection=yes;"
};

const poolPromise = new sql.ConnectionPool(config)
    .connect()
    .then(pool => {
        console.log('Connected to MS SQL Server LocalDB successfully!');
        return pool;
    })
    .catch(err => {
        console.error('Database connection failed:', err);
        return null;
    });

module.exports = {
    sql,
    poolPromise
};