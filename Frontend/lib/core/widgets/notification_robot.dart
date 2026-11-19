// Shared notification-robot system.
//
// The robot scene, its event model and the notification classifier live in
// employee_topbar.dart. This library re-exports the public pieces so other
// shells (e.g. the admin layout) can show the same robot for their own
// notifications without duplicating the ~1000 lines of painter code.
export 'employee_topbar.dart'
    show
        RobotEvent,
        NotificationRobotScene,
        ParsedNotification,
        parseNotificationMessage,
        classifyNotificationEvent;
