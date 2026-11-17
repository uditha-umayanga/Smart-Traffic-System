// Check ODBC.INI / ODBCINST.INI contents and try connecting to SQL Express via named instance
const { execSync } = require('child_process');

console.log('=== ODBC.INI contents ===');
try {
  const r = execSync('powershell.exe -NoProfile -Command "Get-Content \"HKLM:\\\\Software\\\\ODBC\\\\ODBC.INI\" -ErrorAction SilentlyContinue"', { encoding: 'utf8', maxBuffer: 1024 * 1024 });
  console.log(r || '(empty)');
} catch (e) { console.log('(none)'); }

console.log('\n=== ODBCINST.INI contents ===');
try {
  const r = execSync('powershell.exe -NoProfile -Command "Get-Content \"HKLM:\\\\Software\\\\ODBC\\\\ODBCINST.INI\" -ErrorAction SilentlyContinue"', { encoding: 'utf8', maxBuffer: 1024 * 1024 });
  console.log(r || '(empty)');
} catch (e) { console.log('(none)'); }

console.log('\n=== SQL Server error log check ===');
try {
  const r = execSync('powershell.exe -NoProfile -Command "if(Test-Path \"C:\\\\Program Files\\\\Microsoft SQL Server\\\\MSSQL$SQLEXPRESS\\\\LOG\\\\ERRORLOG\") { Get-Content \"C:\\\\Program Files\\\\Microsoft SQL Server\\\\MSSQL$SQLEXPRESS\\\\LOG\\\\ERRORLOG\" -ErrorAction SilentlyContinue | Select-Object -First 30 }"', { encoding: 'utf8', maxBuffer: 1024 * 1024 });
  console.log(r || '(no error log access)');
} catch (e) { console.log((e.stderr || '(none)').slice(0, 1000)); }

console.log('\n=== SQL Server Services status ===');
try {
  const r = execSync('powershell.exe -NoProfile -Command "Get-Service *SQL* | Select-Object Name, Status, StartType"', { encoding: 'utf8', maxBuffer: 1024 * 1024 });
  console.log(r.slice(0, 1500));
} catch (e) { console.log(''); }
