const {test}=require('node:test');
const assert=require('node:assert/strict');

// Explicitly opt in: creates and drops ONLY a uniquely named scratch database.
test('MySQL exit transaction preserves records, recalculates salary, leaves tasks unchanged and rehires safely',
  {skip:process.env.EMPLOYEE_EXIT_MYSQL_TEST!=='1',timeout:60000},async(t)=>{
  require('dotenv').config({quiet:true});
  const mysql=require('mysql2/promise');
  const settings={host:process.env.DB_HOST || 'localhost',port:Number(process.env.DB_PORT || 3306),user:process.env.DB_USER || 'root',password:process.env.DB_PASSWORD || '',dateStrings:true};
  const name=`codex_employee_exit_test_${Date.now()}_${process.pid}`;
  assert.match(name,/^codex_employee_exit_test_\d+_\d+$/);
  const admin=await mysql.createConnection(settings);
  let pool;
  try {
    await admin.query(`CREATE DATABASE \`${name}\``);
    pool=mysql.createPool({...settings,database:name,connectionLimit:5});
    const definitions=[
      `CREATE TABLE employee_users(id INT PRIMARY KEY,full_name VARCHAR(255),role VARCHAR(100),is_active TINYINT,created_at DATETIME) ENGINE=InnoDB`,
      `CREATE TABLE hrms_employee_profiles(id INT PRIMARY KEY,employee_user_id INT,full_name VARCHAR(255),employee_code VARCHAR(30),department VARCHAR(100),employment_status VARCHAR(30),monthly_salary DECIMAL(12,2),salary_type VARCHAR(30),salary_cycle_start_day INT,salary_cycle_end_day INT,created_at DATETIME) ENGINE=InnoDB`,
      `CREATE TABLE hrms_payroll_items(id INT AUTO_INCREMENT PRIMARY KEY,profile_id INT,employee_user_id INT,pay_year INT,pay_month INT,monthly_salary DECIMAL(12,2),working_days INT,daily_rate DECIMAL(12,2),paid_days DECIMAL(8,2),lop_days DECIMAL(8,2),deductions DECIMAL(12,2),net_pay DECIMAL(12,2),status VARCHAR(30),period_start DATE,period_end DATE,paid_at DATETIME,UNIQUE KEY profile_month(profile_id,pay_year,pay_month)) ENGINE=InnoDB`,
      `CREATE TABLE attendance_records(id INT AUTO_INCREMENT PRIMARY KEY,employee_id INT,attendance_date DATE,check_in_at DATETIME,check_out_at DATETIME,attendance_status VARCHAR(30),admin_status_override VARCHAR(30),is_late TINYINT) ENGINE=InnoDB`,
      `CREATE TABLE employee_leaves(id INT PRIMARY KEY,employee_id INT,from_date DATE,to_date DATE,duration_type VARCHAR(30),leave_type_id INT,status VARCHAR(30)) ENGINE=InnoDB`,
      `CREATE TABLE hrms_leave_types(id INT PRIMARY KEY,is_lop TINYINT) ENGINE=InnoDB`,
      `CREATE TABLE task_assignments(id INT PRIMARY KEY,designer VARCHAR(100),client_name VARCHAR(100),deadline DATE) ENGINE=InnoDB`,
      `CREATE TABLE task_list(id INT AUTO_INCREMENT PRIMARY KEY,task_assignment_id INT,additional_task_id INT,employee_id INT,employee_name VARCHAR(255),client_name VARCHAR(100),deliverables VARCHAR(100),submission_date DATE,no_of_rows INT,task_timing_id INT) ENGINE=InnoDB`,
      `CREATE TABLE time_tracking_task_items(id INT AUTO_INCREMENT PRIMARY KEY,task_list_id INT,task_timing_id INT,s_no INT,sub_no INT,parent_item_id INT,submit_date DATE,task_description VARCHAR(500),status VARCHAR(30),review_status VARCHAR(30),duration_secs INT,complete_time DATETIME,content_calendar_assigned TINYINT,content_calendar_assigned_to VARCHAR(255),cc_assigned_to_id INT,cc_assigned_by_name VARCHAR(255),cc_assigned_at DATETIME,caption TEXT,cta TEXT,notes TEXT,hook_headline TEXT,description_points TEXT,description_rich TEXT,publish_date DATE) ENGINE=InnoDB`,
      `CREATE TABLE hrms_field_tracking_sessions(id INT PRIMARY KEY,employee_user_id INT,started_at DATETIME,stopped_at DATETIME,is_active TINYINT) ENGINE=InnoDB`,
    ];
    for(const sql of definitions) await pool.query(sql);
    await pool.query("INSERT INTO employee_users VALUES (7,'Former Employee','Designer',1,'2020-01-01'),(8,'Replacement','Designer',1,'2020-01-01')");
    await pool.query("INSERT INTO hrms_employee_profiles VALUES (1,7,'Former Employee','E7','Design','Active',27000,'standard',NULL,NULL,'2020-01-01')");
    await pool.query("INSERT INTO task_assignments VALUES (10,'Former Employee','Client','2020-01-15')");
    await pool.query("INSERT INTO task_list(id,task_assignment_id,employee_id,employee_name,client_name,deliverables,submission_date,no_of_rows) VALUES (11,10,7,'Former Employee','Client','Design','2020-01-15',2)");
    await pool.query("INSERT INTO time_tracking_task_items(id,task_list_id,s_no,status,duration_secs) VALUES (12,11,1,'COMPLETED',600),(13,11,2,'IDLE',0)");
    await pool.query("INSERT INTO hrms_field_tracking_sessions VALUES (14,7,'2020-01-15 09:00:00',NULL,1)");
    await pool.query("INSERT INTO attendance_records(employee_id,attendance_date,check_in_at,check_out_at,attendance_status) VALUES (7,'2020-01-15','2020-01-15 09:00:00','2020-01-15 18:00:00','present')");
    require.cache[require.resolve('../config/db')]={exports:pool};
    const lifecycle=require('./employeeLifecycle');
    const payroll=require('../controllers/hrmsPayrollController');
    await lifecycle.ensureLifecycle();
    await payroll.generatePayrollRun(2020,1,'2020-01-31',7);
    let [rows]=await pool.query('SELECT * FROM hrms_payroll_items');
    assert.equal(Number(rows[0].net_pay),27000);
    const policy=require('./attendancePolicy');
    const originalToday=policy.todayIstDate;
    t.after(()=> { policy.todayIstDate=originalToday; });
    policy.todayIstDate=()=> '2020-01-16';
    const preview=await lifecycle.preview(7,{lastWorkingDate:'2020-01-15',reason:'Left the office'});
    assert.equal(preview.conflicts.length,0); assert.equal(preview.salary[0].netPay,13000);
    const exit=await lifecycle.deactivate(7,{lastWorkingDate:'2020-01-15',reason:'Left the office'},1);
    const [[user]]=await pool.query('SELECT is_active FROM employee_users WHERE id=7');
    assert.equal(user.is_active,0);
    const [[paid]]=await pool.query('SELECT net_pay FROM hrms_payroll_items');
    assert.equal(Number(paid.net_pay),13000);
    const [[list]]=await pool.query('SELECT * FROM task_list WHERE id=11');
    assert.equal(list.employee_id,7);assert.equal(list.archived_exit_id,undefined);
    const [[assignment]]=await pool.query('SELECT designer FROM task_assignments WHERE id=10');assert.equal(assignment.designer,'Former Employee');
    const [[tracking]]=await pool.query('SELECT is_active FROM hrms_field_tracking_sessions WHERE id=14');assert.equal(tracking.is_active,0);
    const [[original]]=await pool.query('SELECT duration_secs FROM time_tracking_task_items WHERE id=12');assert.equal(original.duration_secs,600);
    const [[count]]=await pool.query('SELECT COUNT(*) AS n FROM time_tracking_task_items');assert.equal(count.n,2);
    assert.deepEqual(await payroll.computeRows(2020,2,'2020-02-29'),[]);
    policy.todayIstDate=()=> '2020-01-25';
    const rehire=await lifecycle.reactivate(7,{},1);
    assert.equal(rehire.startDate,'2020-01-25');
    const [items]=await payroll.computeRows(2020,1,'2020-01-31');
    assert.equal(items.eligibleWorkingDays,19);
    policy.todayIstDate=()=> '2020-01-21';
    await assert.rejects(lifecycle.deactivate(7,{lastWorkingDate:'2020-01-20',reason:'Invalid'},1),/current employment start/);
    const [[stillActive]]=await pool.query('SELECT is_active FROM employee_users WHERE id=7');assert.equal(stillActive.is_active,1);
    await pool.query("INSERT INTO attendance_records(employee_id,attendance_date,check_in_at,check_out_at,attendance_status) VALUES (7,'2020-01-28','2020-01-28 09:00:00','2020-01-28 18:00:00','present')");
    policy.todayIstDate=()=> '2020-01-28';
    const blocked=await lifecycle.preview(7,{lastWorkingDate:'2020-01-27',reason:'Second exit'});
    assert.equal(blocked.conflicts.length,1);assert.equal(blocked.conflicts[0].resolved,false);
    await assert.rejects(lifecycle.deactivate(7,{lastWorkingDate:'2020-01-27',reason:'Second exit'},1),/Resolve records/);
    const conflict=blocked.conflicts[0];
    await pool.query(`INSERT INTO employee_exit_exceptions(employee_user_id,source_table,source_id,last_working_date,record_hash,reason,created_by,created_at)
      VALUES (7,?,?, '2020-01-27',?,'Reviewed historical correction',1,NOW())`,[conflict.source,conflict.id,conflict.hash]);
    await pool.query("UPDATE hrms_payroll_items SET status='paid',net_pay=19000 WHERE employee_user_id=7");
    await lifecycle.deactivate(7,{lastWorkingDate:'2020-01-27',reason:'Second exit'},1);
    const [[unchanged]]=await pool.query('SELECT net_pay FROM hrms_payroll_items WHERE employee_user_id=7');assert.equal(Number(unchanged.net_pay),19000);
    const [[adjustment]]=await pool.query('SELECT difference FROM employee_salary_adjustments WHERE employee_user_id=7');assert.equal(Number(adjustment.difference),-4000);
    const [[retained]]=await pool.query("SELECT COUNT(*) AS n FROM attendance_records WHERE employee_id=7 AND attendance_date='2020-01-28'");assert.equal(retained.n,1);
    await assert.rejects(lifecycle.completeSettlement(7,1),/resolve adjustments/);
  } finally {
    if(pool) await pool.end();
    // The validated name was generated here; no user-configured DB is dropped.
    if(/^codex_employee_exit_test_\d+_\d+$/.test(name)) await admin.query(`DROP DATABASE IF EXISTS \`${name}\``);
    await admin.end();
  }
});
