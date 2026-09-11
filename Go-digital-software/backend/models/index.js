// models/index.js

const fs = require('fs');
const path = require('path');
const Sequelize = require('sequelize');

// Get environment variables
const dbHost = process.env.DB_HOST || 'localhost';
const dbUser = process.env.DB_USER || 'root';
const dbPassword = process.env.DB_PASSWORD || '';
const dbName = process.env.DB_NAME || 'godigital';
const dbPort = process.env.DB_PORT || 3306;

// Create Sequelize instance
const sequelize = new Sequelize(dbName, dbUser, dbPassword, {
  host: dbHost,
  port: dbPort,
  dialect: 'mysql',
  logging: process.env.NODE_ENV === 'development' ? console.log : false,
  pool: {
    max: 5,
    min: 0,
    acquire: 30000,
    idle: 10000,
  },
});

// Test connection
sequelize
  .authenticate()
  .then(() => {
    console.log('✅ Database connected successfully');
  })
  .catch((error) => {
    console.error('❌ Unable to connect to database:', error);
  });

const db = {};

// Import models
db.Sequelize = Sequelize;
db.sequelize = sequelize;

// Load models
db.TaskTrackingDetail = require('./TaskTrackingDetail')(sequelize, Sequelize.DataTypes);
db.TaskActionLog = require('./TaskActionLog')(sequelize, Sequelize.DataTypes);



// Sync database
if (process.env.NODE_ENV !== 'production') {
  sequelize.sync({ alter: true }).then(() => {
    console.log('✅ Database synced');
  });
}

module.exports = db;