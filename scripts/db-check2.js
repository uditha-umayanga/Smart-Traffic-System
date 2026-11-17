// Check db.js content and module loading
const fs = require('fs');
console.log('db.js path:', __dirname + '/db.js');
console.log('db.js exists:', fs.existsSync('db.js'));
console.log('db.js size:', fs.existsSync('db.js') ? fs.statSync('db.js').size : 'N/A');
if (fs.existsSync('db.js')) {
  const content = fs.readFileSync('db.js', 'utf8');
  console.log('db.js content:');
  console.log(content);
}
