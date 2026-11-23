SELECT id, full_name, email, role, user_type, is_active
FROM employee_users
WHERE role = 'Field Marketing';


UPDATE employee_users SET is_active = 1 WHERE role = 'Field Marketing';


-- Give the "Software Developer" role access to every module
INSERT INTO role_application_access (role_id, application, access_type, allowed_pages)
SELECT ur.id, a.app, 'employee', '[]'
FROM user_roles ur
JOIN (SELECT 'attendance' app UNION SELECT 'task_manager' UNION SELECT 'client_repository'
      UNION SELECT 'role_sop' UNION SELECT 'reports') a
WHERE UPPER(TRIM(ur.role_name)) = 'Field Marketing'
ON DUPLICATE KEY UPDATE access_type = VALUES(access_type);

-- Let every Field Marketing upload to the Client Repository
INSERT INTO client_repository_access (employee_id, can_view, can_create, can_download, is_active)
SELECT id, 1, 1, 1, 1 FROM employee_users WHERE role = 'Field Marketing'
ON DUPLICATE KEY UPDATE can_create = 1, can_view = 1, is_active = 1;

