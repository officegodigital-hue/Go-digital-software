// models/TaskActionLog.js

module.exports = (sequelize, DataTypes) => {
  const TaskActionLog = sequelize.define('TaskActionLog', {
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
    action_type: {
      type: DataTypes.STRING(50),
      allowNull: false,
      // Valid values: START, HOLD, RESTART, COMPLETED, REJECTED
    },
    action_timestamp: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    duration_so_far: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Total duration in seconds accumulated so far',
    },
    current_session_duration: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Duration in current session (before this action)',
    },
    created_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  }, {
    tableName: 'task_action_logs',
    timestamps: false,
  });

  return TaskActionLog;
};