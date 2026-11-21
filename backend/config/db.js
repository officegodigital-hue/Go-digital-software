// const mysql = require('mysql2');
// require('dotenv').config();

// const pool = mysql.createPool({
//   host: process.env.DB_HOST || 'localhost',
//   user: process.env.DB_USER || 'root',
//   password: process.env.DB_PASSWORD || '',
//   database: process.env.DB_NAME || 'godigital_db',
//   waitForConnections: true,
//   connectionLimit: 10
// });

// module.exports = pool.promise();

// const mysql = require('mysql2/promise');

// const pool = mysql.createPool({
//   host:               'localhost',
//   port:               3306,
//   user:               'root',
//   password:           '',       
//   database:           'godigital_db',
//   waitForConnections: true,
//   connectionLimit:    10,
//   queueLimit:         0,
// });

// module.exports = pool;

// const mysql = require('mysql2');
// require('dotenv').config();

// const pool = mysql.createPool({
//   host: process.env.DB_HOST || 'localhost',
//   user: process.env.DB_USER || 'root',
//   password: process.env.DB_PASSWORD || '',
//   database: process.env.DB_NAME || 'godigital_db',
//   waitForConnections: true,
//   connectionLimit: 10
// });

// module.exports = pool.promise();

const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'godigital_db',

  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  // Report submissions store base64 dashboard screenshots, so single INSERTs
  // can be tens of MB. Let the mysql2 client send large packets; the server's
  // own max_allowed_packet is raised below (and should also be set in my.cnf).
  maxAllowedPacket: 256 * 1024 * 1024,
});

// Best-effort: raise the server's max_allowed_packet so large report payloads
// are accepted. Needs SUPER / SYSTEM_VARIABLES_ADMIN (root@localhost has it).
// Only affects connections opened afterwards, which covers report submissions.
// The durable fix is `max_allowed_packet=256M` in my.cnf + a MySQL restart.
pool.query('SET GLOBAL max_allowed_packet = 268435456')
  .then(() => console.log('✅ max_allowed_packet raised for report payloads'))
  .catch(err =>
    console.warn('⚠️ Could not raise max_allowed_packet (set it in my.cnf):', err.message));

pool.getConnection()
  .then(connection => {
    console.log('✅ Database pool created successfully');
    connection.release();
  })
  .catch(err => {
    console.error('❌ Database pool error:', err.message);
  });

module.exports = pool;