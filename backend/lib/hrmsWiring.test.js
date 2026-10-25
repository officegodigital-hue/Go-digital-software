const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8').replace(/^\s*\/\/.*$/gm,'');
const mounts={attendance:'/attendance',hrmsEmployees:'/hrms/employees',hrmsDashboard:'/hrms/dashboard',hrmsApprovals:'/hrms/approvals',hrmsPayroll:'/hrms/payroll',hrmsTracking:'/hrms/tracking',hrmsPayslips:'/hrms/payslips',hrmsAnnouncements:'/hrms/announcements',employees:'/employees',auth:'/auth'};
function inventory(){
 const routes=[];
 for(const [file,base] of Object.entries(mounts))for(const m of read(`backend/routes/${file}.js`).matchAll(/router\.(get|post|put|patch|delete)\(\s*['"]([^'"]+)/g))routes.push({method:m[1].toUpperCase(),path:base+(m[2]==='/'?'':m[2])});
 for(const m of read('backend/attendance/app.js').matchAll(/app\.(get|post|put|patch|delete)\(`\$\{prefix\}([^`]+)/g))routes.push({method:m[1].toUpperCase(),path:'/attendance'+m[2]});
 return routes;
}
function walk(dir){return fs.readdirSync(path.join(root,dir),{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(dir+'/'+e.name):[dir+'/'+e.name]);}
test('active HRMS frontend URLs have registered backend routes',()=>{
 const routes=inventory();let checked=0;
 const files=[...walk('Frontend/lib/services').filter(f=>/hrms.*\.dart$/.test(f)),...walk('Frontend/lib/hrms_employee/pages'),...walk('Frontend/lib/hrms_employee/attendance')];
 for(const file of files)for(const m of read(file).matchAll(/\$\{ApiConfig.baseUrl\}([^'"\n]*)/g)){
  const endpoint=m[1].replace(/\$\{[^}]*\}/g,'PARAM').replace(/\$\w+/g,'PARAM').split('?')[0];
  // Dynamic attendance helpers and base URLs are checked explicitly below.
  if(!endpoint.startsWith('/')||endpoint==='/attendance'||endpoint.includes('PARAMPARAM'))continue;
  assert.ok(routes.some(r=>new RegExp('^'+r.path.replace(/:[^/]+/g,'[^/]+')+'$').test(endpoint)),`${file}: ${endpoint} has no backend route`);
  checked++;
 }
 assert.ok(checked>=70,`Only ${checked} URLs checked`);
 for(const [method,endpoint] of [
  ['GET','/attendance/dashboard'],['GET','/attendance/check-in-policy'],['POST','/attendance/check-in'],['POST','/attendance/check-out'],['POST','/attendance/break-in'],['POST','/attendance/break-out'],['POST','/attendance/heartbeat'],
  ['GET','/attendance/leave/dashboard'],['GET','/attendance/leave/types'],['POST','/attendance/leave/apply'],['POST','/attendance/leave/cancel'],['GET','/attendance/permissions/mine'],['POST','/attendance/permissions'],
  ['GET','/attendance/extra-hours/dashboard'],['POST','/attendance/extra-hours/log'],['POST','/attendance/corrections'],['GET','/attendance/header-status'],
  ['POST','/employees/user-roles'],['PUT','/hrms/tracking/settings'],['POST','/hrms/payroll/generate'],['PATCH','/hrms/payroll/1'],['PATCH','/hrms/approvals/1'],['GET','/hrms/payslips/my'],['POST','/hrms/payslips/1/request'],['GET','/hrms/payslips/1/download']
 ])assert.ok(routes.some(r=>r.method===method&&new RegExp('^'+r.path.replace(/:[^/]+/g,'[^/]+')+'$').test(endpoint)),`${method} ${endpoint} is not wired`);
});
