require('dotenv').config();

const app = require('./app');
const pool = require('./config/database');

const port = Number(process.env.PORT || 3000);

const startServer = async () => {
  try {
    const connection = await pool.getConnection();

    const [databaseResult] = await connection.query(
      'SELECT DATABASE() AS database_name',
    );

    console.log('MySQL server connected successfully');
    console.log(
      `Connected database: ${databaseResult[0].database_name}`,
    );

    connection.release();

    const server = app.listen(port, () => {
      console.log(
        `Attendance API running on http://localhost:${port}`,
      );

      console.log(
        `Database test: http://localhost:${port}/db-health`,
      );
    });

    const shutdown = (signal) => {
      console.log(`${signal} received. Closing server...`);

      server.close(async () => {
        await pool.end();
        console.log('Server closed successfully');
        process.exit(0);
      });
    };

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  } catch (error) {
    console.error('Unable to connect to MySQL');
    console.error(error.message);
    process.exit(1);
  }
};

startServer();