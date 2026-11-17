// Manage SQL Server services: start/stop SQL Browser and check status
const { execSync } = require('child_process');

console.log('=== Current SQL Server services ===');
try {
  const r = execSync('powershell.exe -NoProfile -Command "Get-Service *SQL* | Select-Object Name, Status"', { encoding: 'utf8', maxBuffer: 1024 * 1024 });
  console.log(r.slice(0, 1000));
} catch (e) {
  console.log('(n/a)');
}

console.log('\n=== Starting SQL Browser ===');
try {
  const r = execSync('powershell.exe -NoProfile -Command "Start-Service SQLBrowser -ErrorAction Stop" 2>&1', { encoding: 'utf8', maxBuffer: 1024 * 1024 });
  console.log('Started:', r.slice(0, 200));
} catch (e) {
  console.log('Start err:', (e.message || e.stdout || e.stderr).slice(0, 200));
}

console.log('\n=== Checking status after start ===');
try {
  const r = execSync('powershell.exe -NoProfile -Command "Get-Service *SQL* | Select-Object Name, Status"', { encoding: 'utf8', maxBuffer: 1024 * 1024 });
  console.log(r.slice(0, 1000));
} catch (e) {
  console.log('(n/a)');
}

console.log('\n=== TCP port 1433 test ===');
try {
  const r = execSync('powershell.exe -NoProfile -Command "Get-NetTCPConnection -LocalPort 1433 -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, State, OwningProcess"', { encoding: 'utf8', maxBuffer: 1024 * 1024 });
  console.log(r.slice(0, 500) || '(no process on 1433)');
} catch (e) {
  console.log('no 1433 listener detected');
}
