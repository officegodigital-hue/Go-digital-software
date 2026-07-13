// models/timing.js
module.exports = (sequelize, DataTypes) => {
  const Timing = sequelize.define('Timing', {
    task_name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    qty: {
      type: DataTypes.STRING,
      allowNull: false,
      defaultValue: '1',
    },
    timing: {
      type: DataTypes.STRING,
      allowNull: false,
    },
  }, {
    tableName: 'timings',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
  });

  return Timing;
};