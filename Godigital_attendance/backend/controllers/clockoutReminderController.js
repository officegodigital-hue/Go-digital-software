'use strict';
const reminder = require('../lib/clockoutReminder');
function ok(res, data, message) { return res.json({ success: true, message: message || 'OK', data }); }
function fail(res, status, message) { return res.status(status).json({ success: false, message }); }
async function policy(req, res) { try { return ok(res, await reminder.policy()); } catch (e) { return fail(res, 500, e.message); } }
async function updatePolicy(req, res) { try { return ok(res, await reminder.updatePolicy(req.body || {}, req.user && req.user.id), 'Reminder policy saved'); } catch (e) { return fail(res, 400, e.message); } }
async function register(req, res) { try { return ok(res, await reminder.registerDevice(req.user.id, req.body || {}), 'Notification device registered'); } catch (e) { return fail(res, 400, e.message); } }
async function remove(req, res) { try { return ok(res, await reminder.unregisterDevice(req.user.id, req.params.id), 'Notification device removed'); } catch (e) { return fail(res, 400, e.message); } }
async function status(req, res) { try { return ok(res, await reminder.status(req.user.id)); } catch (e) { return fail(res, 500, e.message); } }
module.exports = { policy, updatePolicy, register, remove, status };
