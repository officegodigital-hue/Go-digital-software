// models/TaskTrackingDetail.js

module.exports = (sequelize, DataTypes) => {
  const TaskTrackingDetail = sequelize.define('TaskTrackingDetail', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    task_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    task_key: {
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true,
    },
    employee_name: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    client_name: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    task_name: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    submit_date: {
      type: DataTypes.STRING(50),
      allowNull: true,
    },
    task_description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    comment: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    row_count: {
      type: DataTypes.INTEGER,
      defaultValue: 1,
    },
    is_completed: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    is_rejected: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    created_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
    updated_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
      onUpdate: DataTypes.NOW,
    },
  }, {
    tableName: 'task_tracking_details',
    timestamps: false,
  });

  return TaskTrackingDetail;
};