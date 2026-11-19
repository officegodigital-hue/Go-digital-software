import 'package:godigital_portal/services/auth_storage.dart';
// lib/core/widgets/employee_topbar.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart'; // 🟢 Added for saving agreed state
import '../constants/app_colors.dart';
import '../constants/employee_role.dart';
import '../../services/auth_service.dart';
import '../../services/api_config.dart';
import '../../services/app_notification_center.dart';
import 'package:godigital_portal/screens/employee_dashboard/task_actions.dart';

// ============================================================
// NOTIFICATION EVENTS
//
// Every notification that reaches this top bar (Socket.IO
// `new_notification` or the 5-second poll) is classified from its real
// payload / message text. The robot's face, action and colour follow the
// event. Nothing is shown for events that never produce a notification.
// ============================================================

enum _Face { neutral, focused, happy, sad, worried, attentive, confident }

enum _Badge { none, pause, review, rework, warning, checklist }

enum RobotEvent {
  generic(
    Color(0xFF1976D2),
    Icons.notifications_none_rounded,
    5000,
    _Face.neutral,
    _Badge.none,
  ),
  taskStarted(
    Color(0xFF2563EB),
    Icons.play_arrow,
    6000,
    _Face.focused,
    _Badge.none,
  ),
  taskRestarted(
    Color(0xFF2563EB),
    Icons.play_arrow,
    6000,
    _Face.happy,
    _Badge.none,
    celebrates: true,
  ),
  taskHold(
    Color(0xFFF97316),
    Icons.pause_circle_outline,
    6000,
    _Face.sad,
    _Badge.pause,
  ),
  taskCompleted(
    Color(0xFF16A34A),
    Icons.check_circle_outline,
    6000,
    _Face.happy,
    _Badge.none,
    celebrates: true,
  ),
  taskRejected(
    Color(0xFFDC2626),
    Icons.cancel_outlined,
    7000,
    _Face.worried,
    _Badge.warning,
  ),
  taskReview(
    Color(0xFF7C3AED),
    Icons.search,
    6000,
    _Face.attentive,
    _Badge.review,
  ),
  taskRework(
    Color(0xFFD97706),
    Icons.refresh,
    7000,
    _Face.sad,
    _Badge.rework,
  ),
  taskApproved(
    Color(0xFF16A34A),
    Icons.verified_outlined,
    6000,
    _Face.happy,
    _Badge.none,
    celebrates: true,
  ),
  plannerSubmitted(
    Color(0xFF2563EB),
    Icons.fact_check_outlined,
    6000,
    _Face.confident,
    _Badge.checklist,
  ),
  plannerApproved(
    Color(0xFF16A34A),
    Icons.event_available_outlined,
    6000,
    _Face.happy,
    _Badge.none,
    celebrates: true,
  ),
  plannerRework(
    Color(0xFFD97706),
    Icons.refresh,
    7000,
    _Face.sad,
    _Badge.rework,
  ),
  contentShared(
    Color(0xFF0EA5A9),
    Icons.send_rounded,
    6000,
    _Face.confident,
    _Badge.checklist,
  );

  final Color accent;
  final IconData icon;

  /// How long the panel stays open once fully revealed.
  final int holdMs;
  final _Face face;
  final _Badge badge;
  final bool celebrates;

  const RobotEvent(
    this.accent,
    this.icon,
    this.holdMs,
    this.face,
    this.badge, {
    this.celebrates = false,
  });
}

class ParsedNotification {
  final String preview;
  final Map? decoded;

  const ParsedNotification(this.preview, this.decoded);
}

/// Same preview rules the top bar already used, but also keeps the decoded
/// JSON so the event can be classified from its fields.
ParsedNotification parseNotificationMessage(String raw) {
  String preview = raw;
  Map? decodedMap;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      decodedMap = decoded;
      preview = decoded['preview']?.toString() ??
          decoded['text']?.toString() ??
          (decoded['fileName'] != null ? '📎 ${decoded['fileName']}' : raw);
    }
  } catch (_) {}
  return ParsedNotification(preview, decodedMap);
}

String _eventToken(dynamic v) =>
    v.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// Maps a real notification to a robot event.
///
/// 1. Explicit fields in the payload (event / action / category ...) are read
///    first, when the backend sends them.
/// 2. Otherwise the real message text is matched against phrases such as
///    "on hold", "sent for review", "approved".
/// Anything that does not clearly look like a task / Day Planner event stays
/// `generic` (normal chat messages, file attachments, etc.).
RobotEvent classifyNotificationEvent(
  Map? source,
  Map? decoded,
  String message,
) {
  // Attachments are chat, never a task event.
  if (decoded != null && decoded['fileName'] != null) {
    return RobotEvent.generic;
  }

  const hintKeys = [
    'event',
    'eventType',
    'event_type',
    'action',
    'notificationType',
    'notification_type',
    'category',
    'kind',
  ];
  const extraKeys = ['status', 'type'];

  // Review / planner notifications carry their real event under a nested
  // `payload` map ({type: "TASK_REVIEW", action: "APPROVED", ...}); scan it
  // too so the event is read from the backend's own fields, not just text.
  final Map? nested =
      (decoded != null && decoded['payload'] is Map) ? decoded['payload'] as Map : null;

  final buf = StringBuffer();
  bool structuredHint = false;
  for (final m in <Map?>[source, decoded, nested]) {
    if (m == null) continue;
    for (final k in hintKeys) {
      final v = m[k];
      if (v == null) continue;
      structuredHint = true;
      buf.write(' ${_eventToken(v)}');
    }
    for (final k in extraKeys) {
      final v = m[k];
      if (v is String) buf.write(' ${_eventToken(v)}');
    }
  }

  final t = '${buf.toString()} | ${message.toLowerCase()}';
  bool has(String pattern) => RegExp(pattern).hasMatch(t);

  final bool isPlanner = has(r'planner');
  if (!structuredHint && !isPlanner && !has(r'\btasks?\b')) {
    return RobotEvent.generic;
  }

  const rework = r'rework|re-work|sent back|send back|returned|return for|revision';

  if (isPlanner) {
    if (has(rework)) return RobotEvent.plannerRework;
    if (has(r'approv')) return RobotEvent.plannerApproved;
    if (has(r'submit')) return RobotEvent.plannerSubmitted;
    return RobotEvent.generic;
  }

  if (has(rework)) return RobotEvent.taskRework;
  if (has(r'reject')) return RobotEvent.taskRejected;
  if (has(r'approv')) return RobotEvent.taskApproved;
  if (has(r'for review|to review|under review|in review|review request')) {
    return RobotEvent.taskReview;
  }
  if (has(r'complet|finished')) return RobotEvent.taskCompleted;
  if (has(r'on[ _-]?hold|\bheld\b|\bpaused\b')) return RobotEvent.taskHold;
  if (has(r'\bstarted\b|in[ _-]?progress')) return RobotEvent.taskStarted;
  return RobotEvent.generic;
}

// ============================================================
// NOTIFICATION ROBOT SCENE
//
// Timeline (one controller, value 0 -> 1 opening, 1 -> 0 closing):
//   0.00-0.50  robot walks in from the right (slow, 4 stride cycles)
//   0.50-0.62  robot extends its hand
//   0.62-0.72  laser beam shoots from the hand
//   0.70-1.00  beam "scans" the panel open (reveal)
// Reversing the controller plays it backwards: panel closes, laser
// retracts, hand lowers, robot walks away.
//
// A second controller (`action`) starts when the reveal starts and drives
// the event-specific part: pause symbol, celebration, warning sway, etc.
// ============================================================

class NotificationRobotScene extends StatelessWidget {
  final AnimationController controller;
  final Animation<double> pulse;
  final Animation<double> action;
  final RobotEvent event;
  final String message;
  final double maxWidth;

  const NotificationRobotScene({
    required this.controller,
    required this.pulse,
    required this.action,
    required this.event,
    required this.message,
    required this.maxWidth,
  });

  static const double _robotW = 112;
  static const double _robotH = 124;
  static const double _handDX = 9; // hand tip x inside the robot canvas
  static const double _handDY = 76; // hand tip y inside the robot canvas
  static const double _sceneH = 150;
  static const double _beamLen = 40;

  static double _phase(double t, double a, double b, Curve curve) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    const double robotTail = _robotW - _handDX;
    final double panelW =
        (maxWidth - _beamLen - robotTail).clamp(180.0, 320.0).toDouble();
    final double sceneW = panelW + _beamLen + robotTail;
    const double handY = _sceneH / 2;

    return SizedBox(
      width: sceneW,
      height: _sceneH,
      child: AnimatedBuilder(
        animation: Listenable.merge([controller, pulse, action]),
        builder: (context, _) {
          final double t = controller.value;
          final double loop = pulse.value;
          final double act = action.value;

          final double walkRaw = (t / 0.50).clamp(0.0, 1.0);
          final double walk = Curves.easeOutSine.transform(walkRaw);
          final double extend = _phase(t, 0.50, 0.62, Curves.easeOut);
          final double beam = _phase(t, 0.62, 0.72, Curves.easeOut);
          final double reveal = _phase(t, 0.70, 1.0, Curves.easeInOutCubic);

          final bool walking = walkRaw > 0 && walkRaw < 1;
          final double stride =
              walking ? math.sin(walkRaw * math.pi * 8) : 0.0;
          final double bob = walking ? -2.5 * stride.abs() : 0.0;

          // ON HOLD: after the panel is up the hand lowers and the laser
          // switches off, leaving the pause symbol.
          final double handLower = event == RobotEvent.taskHold
              ? Curves.easeInOut.transform(((act - 0.55) / 0.45).clamp(0.0, 1.0))
              : 0.0;
          final double extendNow = extend * (1 - 0.8 * handLower);
          final double beamNow = beam * (1 - handLower);

          // Celebration hop / gentle warning sway.
          final double hop = event.celebrates
              ? -4.0 * Curves.easeInOut.transform(loop) * act
              : 0.0;
          final double sway =
              event == RobotEvent.taskRejected ? (loop - 0.5) * 0.09 * act : 0.0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Panel (revealed by the light)
              Positioned(
                left: 0,
                top: 0,
                width: panelW,
                height: _sceneH,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildPanel(panelW, reveal),
                ),
              ),

              // Laser beam
              Positioned(
                left: panelW,
                top: 0,
                width: _beamLen,
                height: _sceneH,
                child: CustomPaint(
                  painter: _LaserBeamPainter(
                    progress: beamNow,
                    pulse: loop,
                    y: handY,
                    color: event.accent,
                  ),
                ),
              ),

              // Robot
              Positioned(
                left: panelW + _beamLen - _handDX,
                top: handY - _handDY,
                width: _robotW,
                height: _robotH,
                child: Transform.translate(
                  offset: Offset(150 * (1 - walk), bob + hop),
                  child: Transform.rotate(
                    angle: sway,
                    alignment: Alignment.bottomCenter,
                    child: Transform.scale(
                      // Grows slightly as it walks towards the viewer.
                      scale: 0.85 + 0.15 * walk,
                      alignment: Alignment.bottomCenter,
                      child: Opacity(
                        opacity: (walkRaw * 4).clamp(0.0, 1.0),
                        child: _NotificationRobot(
                          extend: extendNow,
                          swing: stride,
                          face: event.face,
                          badge: event.badge,
                          celebrate: event.celebrates,
                          act: act,
                          loop: loop,
                          accent: event.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel(double panelW, double reveal) {
    final double shadowA = ((reveal - 0.75) / 0.25).clamp(0.0, 1.0);
    final Color accent = event.accent;

    return SizedBox(
      width: panelW,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10 * shadowA),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipPath(
              clipper: _RevealClipper(reveal),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(event.icon, size: 16, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          message,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanPainter(reveal, accent)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wedge that opens from the beam's impact point (right edge, centre)
/// to the full panel, so the panel looks projected by the light.
class _RevealClipper extends CustomClipper<Path> {
  final double r;

  _RevealClipper(this.r);

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;
    final xl = w * (1 - r);
    final hr = (h / 2) * math.min(1.0, r * 2.2);

    return Path()
      ..moveTo(w, cy - hr)
      ..lineTo(xl, 0)
      ..lineTo(xl, h)
      ..lineTo(w, cy + hr)
      ..close();
  }

  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) => oldClipper.r != r;
}

/// Thin scanning line + cone edges, only visible while the panel opens.
class _ScanPainter extends CustomPainter {
  final double r;
  final Color color;

  _ScanPainter(this.r, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (r <= 0 || r >= 1) return;

    final w = size.width;
    final h = size.height;
    final cy = h / 2;
    final xl = w * (1 - r);
    final hr = (h / 2) * math.min(1.0, r * 2.2);
    final fade = (1 - r).clamp(0.0, 1.0);

    final glow = Paint()
      ..color = color.withValues(alpha: 0.35 * fade)
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final core = Paint()
      ..color = Color.lerp(color, Colors.white, 0.4)!.withValues(alpha: 0.9 * fade)
      ..strokeWidth = 1.4;
    final edge = Paint()
      ..color = color.withValues(alpha: 0.35 * fade)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(xl, 0), Offset(xl, h), glow);
    canvas.drawLine(Offset(xl, 0), Offset(xl, h), core);
    canvas.drawLine(Offset(w, cy - hr), Offset(xl, 0), edge);
    canvas.drawLine(Offset(w, cy + hr), Offset(xl, h), edge);
  }

  @override
  bool shouldRepaint(covariant _ScanPainter oldDelegate) =>
      oldDelegate.r != r || oldDelegate.color != color;
}

/// Thin glowing beam in the event colour. It starts at the robot's hand
/// (right end) and grows to the left towards the panel.
class _LaserBeamPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final double y;
  final Color color;

  _LaserBeamPainter({
    required this.progress,
    required this.pulse,
    required this.y,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final x1 = size.width;
    final x0 = size.width - size.width * progress;
    final a = 0.30 + 0.15 * pulse;
    final rect = Rect.fromLTRB(x0, y - 4, x1, y + 4);
    final light = Color.lerp(color, Colors.white, 0.4)!;
    final lighter = Color.lerp(color, Colors.white, 0.85)!;

    final glow = Paint()
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: a * 0.5),
          color.withValues(alpha: a),
        ],
      ).createShader(rect);

    final core = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: [light, lighter]).createShader(rect);

    canvas.drawLine(Offset(x0, y), Offset(x1, y), glow);
    canvas.drawLine(Offset(x0, y), Offset(x1, y), core);

    // Emitter glow at the hand and a small spot where the beam lands.
    canvas.drawCircle(
      Offset(x1, y),
      7,
      Paint()
        ..color = color.withValues(alpha: 0.35 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(x0, y),
      3,
      Paint()
        ..color = light.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(x0, y), 1.4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _LaserBeamPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pulse != pulse ||
      oldDelegate.color != color;
}

class _NotificationRobot extends StatelessWidget {
  /// 0 = arm lowered, 1 = hand fully extended towards the panel.
  final double extend;

  /// -1..1 leg swing while walking.
  final double swing;

  final _Face face;
  final _Badge badge;
  final bool celebrate;

  /// 0..1 progress of the event-specific action.
  final double act;

  /// 0..1 repeating pulse used for waving / twinkling.
  final double loop;
  final Color accent;

  const _NotificationRobot({
    required this.extend,
    required this.swing,
    required this.face,
    required this.badge,
    required this.celebrate,
    required this.act,
    required this.loop,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 124,
      child: CustomPaint(
        painter: _NotificationRobotPainter(
          extend: extend,
          swing: swing,
          face: face,
          badge: badge,
          celebrate: celebrate,
          act: act,
          loop: loop,
          accent: accent,
        ),
      ),
    );
  }
}

/// The white helmet robot with the black visor, glowing cyan eyes,
/// headphones and antennas (from the reference image), drawn in code.
class _NotificationRobotPainter extends CustomPainter {
  final double extend;
  final double swing;
  final _Face face;
  final _Badge badge;
  final bool celebrate;
  final double act;
  final double loop;
  final Color accent;

  _NotificationRobotPainter({
    required this.extend,
    required this.swing,
    required this.face,
    required this.badge,
    required this.celebrate,
    required this.act,
    required this.loop,
    required this.accent,
  });

  static const Color _ink = Color(0xFF0B1020);
  static const Color _rim = Color(0xFFB4BED0);
  static const Color _cyan = Color(0xFF22D3EE);
  static const Color _mouthGrey = Color(0xFF94A3B8);

  Paint _pearl(Rect r) => Paint()
    ..shader = const RadialGradient(
      center: Alignment(-0.45, -0.55),
      radius: 1.0,
      colors: [Colors.white, Color(0xFFF1F5F9), Color(0xFFCBD5E1)],
      stops: [0.0, 0.55, 1.0],
    ).createShader(r);

  Paint _rimLine() => Paint()
    ..color = _rim
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;

  void _pearlRRect(Canvas c, Rect r, double radius) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    c.drawRRect(rr, _pearl(r));
    c.drawRRect(rr, _rimLine());
  }

  void _pearlCircle(Canvas c, Offset o, double radius) {
    final r = Rect.fromCircle(center: o, radius: radius);
    c.drawCircle(o, radius, _pearl(r));
    c.drawCircle(o, radius, _rimLine());
  }

  // White limb with a thin rim, from a to b.
  void _limb(Canvas c, Offset a, Offset b) {
    c.drawLine(
      a,
      b,
      Paint()
        ..color = _rim
        ..strokeWidth = 10.5
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFFF1F5F9)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
  }

  // Black claw hand drawn at the origin, fingers pointing down (+y).
  void _hand(Canvas c) {
    final ink = Paint()..color = _ink;
    final finger = Paint()
      ..color = _ink
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    c.drawCircle(Offset.zero, 4.2, ink);
    c.drawLine(const Offset(-2, 2), const Offset(-3.6, 6.5), finger);
    c.drawLine(const Offset(2, 2), const Offset(3.6, 6.5), finger);
  }

  // Eyes + mouth for the current expression.
  void _drawFace(Canvas canvas, double cx) {
    const Color highlight = Color(0xFFCFFAFE);

    for (final s in const [-1.0, 1.0]) {
      final e = Offset(cx + s * 10.5, 35);
      canvas.drawCircle(
        e,
        9,
        Paint()
          ..color = _cyan.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      if (face == _Face.happy) {
        // Smiling "^" eyes
        canvas.drawArc(
          Rect.fromCenter(center: Offset(e.dx, e.dy + 2.5), width: 10, height: 9),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = _cyan
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      double lidInner = 0;
      double lidOuter = 0;
      double r = 5.4;
      if (face == _Face.focused) {
        lidInner = 0.5; // lowered inner brows: concentrating
        lidOuter = 0.1;
      } else if (face == _Face.sad) {
        lidOuter = 0.55; // drooping outer lids
      } else if (face == _Face.worried) {
        lidOuter = 0.35;
        r = 5.6;
      } else if (face == _Face.attentive) {
        r = 6.0; // wide, alert eyes
      }

      final double outerX = e.dx + s * (r + 1);
      final double innerX = e.dx - s * (r + 1);
      final double top = e.dy - r - 1;
      final double span = 2 * r + 2;
      final Path clip = Path()
        ..moveTo(outerX, top + span * lidOuter)
        ..lineTo(innerX, top + span * lidInner)
        ..lineTo(innerX, e.dy + r + 1)
        ..lineTo(outerX, e.dy + r + 1)
        ..close();

      canvas.save();
      canvas.clipPath(clip);
      canvas.drawCircle(e, r, Paint()..color = _cyan);
      // Attentive: looks towards the panel (left).
      final double look = face == _Face.attentive ? -1.4 : 0.0;
      canvas.drawCircle(
        Offset(e.dx + look, e.dy),
        r * 0.45,
        Paint()..color = highlight,
      );
      canvas.restore();
    }

    final Paint mouth = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (face == _Face.happy) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, 42), width: 14, height: 8),
        0.1,
        math.pi - 0.2,
        false,
        mouth
          ..color = _cyan
          ..strokeWidth = 1.8,
      );
    } else if (face == _Face.confident) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, 42.5), width: 11, height: 6),
        0.15,
        math.pi - 0.3,
        false,
        mouth
          ..color = _cyan.withValues(alpha: 0.85)
          ..strokeWidth = 1.5,
      );
    } else if (face == _Face.focused) {
      canvas.drawLine(
        Offset(cx - 3.5, 44),
        Offset(cx + 3.5, 44),
        mouth
          ..color = _mouthGrey
          ..strokeWidth = 1.4,
      );
    } else if (face == _Face.sad || face == _Face.worried) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx, 46),
          width: face == _Face.sad ? 10 : 8,
          height: 6,
        ),
        math.pi + 0.25,
        math.pi - 0.5,
        false,
        mouth
          ..color = _mouthGrey
          ..strokeWidth = 1.4,
      );
    } else if (face == _Face.attentive) {
      canvas.drawCircle(
        Offset(cx, 44),
        2,
        mouth
          ..color = _mouthGrey
          ..strokeWidth = 1.2,
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, 43), width: 9, height: 5),
        0.2,
        2.74,
        false,
        mouth
          ..color = const Color(0xFF475569)
          ..strokeWidth = 1,
      );
    }
  }

  // Small sparkles above / around the head for a success celebration.
  void _drawConfetti(Canvas canvas, double cx) {
    final colors = <Color>[
      accent,
      const Color(0xFFFBBF24),
      const Color(0xFF22D3EE),
    ];
    final double burst = Curves.easeOutCubic.transform(act);

    for (int i = 0; i < 12; i++) {
      final double ang = math.pi + (i / 11) * math.pi;
      final double dist = 27 + burst * (12 + (i % 3) * 6);
      final Offset p = Offset(
        cx + math.cos(ang) * dist * 1.2,
        34 + math.sin(ang) * dist,
      );
      final double twinkle = 0.55 + 0.45 * math.sin(loop * math.pi + i);
      final double alpha = (burst * twinkle).clamp(0.0, 1.0);
      final Paint paint = Paint()
        ..color = colors[i % 3].withValues(alpha: alpha);
      final double sz = 1.7 + (i % 3) * 0.7;
      if (i.isEven) {
        canvas.drawCircle(p, sz, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: p, width: sz * 2, height: sz * 1.2),
          paint,
        );
      }
    }
  }

  // Round symbol next to the head (pause, magnifier, refresh, "!", checklist).
  void _drawBadge(Canvas c) {
    final double pop = Curves.easeOutBack.transform(act.clamp(0.0, 1.0));
    if (pop <= 0) return;

    double sc = pop;
    if (badge == _Badge.warning) sc *= 1 + 0.08 * loop;

    final white = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    c.save();
    c.translate(15, 22);
    c.scale(sc);
    c.drawCircle(Offset.zero, 11, Paint()..color = Colors.white);
    c.drawCircle(Offset.zero, 9.5, Paint()..color = accent);

    switch (badge) {
      case _Badge.pause:
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-4.4, -4.6, 3.2, 9.2),
            const Radius.circular(1),
          ),
          white,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1.2, -4.6, 3.2, 9.2),
            const Radius.circular(1),
          ),
          white,
        );
        break;
      case _Badge.review:
        c.drawCircle(const Offset(-1.2, -1.2), 3.9, stroke);
        c.drawLine(
          const Offset(1.8, 1.8),
          const Offset(5, 5),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
        break;
      case _Badge.rework:
        const double r = 4.6;
        final double start = -math.pi / 2 + act * 2 * math.pi;
        const double sweep = math.pi * 1.5;
        c.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          start,
          sweep,
          false,
          stroke,
        );
        final double a = start + sweep;
        final Offset p = Offset(r * math.cos(a), r * math.sin(a));
        final Offset tangent = Offset(-math.sin(a), math.cos(a));
        final Offset normal = Offset(math.cos(a), math.sin(a));
        final Offset tip = p + tangent * 3.4;
        final Path head = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(p.dx + normal.dx * 2.6, p.dy + normal.dy * 2.6)
          ..lineTo(p.dx - normal.dx * 2.6, p.dy - normal.dy * 2.6)
          ..close();
        c.drawPath(head, white);
        break;
      case _Badge.warning:
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-1.2, -5.8, 2.4, 7),
            const Radius.circular(1.2),
          ),
          white,
        );
        c.drawCircle(const Offset(0, 4.2), 1.5, white);
        break;
      case _Badge.checklist:
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-5, -6.5, 10, 13),
            const Radius.circular(2),
          ),
          thin,
        );
        c.drawLine(const Offset(-2.4, -3.4), const Offset(2.4, -3.4), thin);
        c.drawLine(const Offset(-2.4, -1), const Offset(2.4, -1), thin);
        final double prog =
            Curves.easeOut.transform(((act - 0.3) / 0.7).clamp(0.0, 1.0));
        final Path check = Path()
          ..moveTo(-2.8, 3.0)
          ..lineTo(-0.8, 4.8)
          ..lineTo(2.8, 1.8);
        for (final m in check.computeMetrics()) {
          c.drawPath(m.extractPath(0, m.length * prog), thin);
        }
        break;
      case _Badge.none:
        break;
    }
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double cx = 64;
    final ink = Paint()..color = _ink;

    // Soft floor shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, 119), width: 58, height: 7),
      Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Antennas + top knob
    final antenna = Paint()
      ..color = _ink
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(cx - 22, 17), const Offset(cx - 27, 7), antenna);
    canvas.drawLine(const Offset(cx + 22, 17), const Offset(cx + 27, 7), antenna);
    canvas.drawCircle(const Offset(cx - 27, 6), 2.6, ink);
    canvas.drawCircle(const Offset(cx + 27, 6), 2.6, ink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, 11), width: 8, height: 3.5),
        const Radius.circular(1.7),
      ),
      ink,
    );

    // Headphone ear cups
    for (final s in const [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + s * 31, 35), width: 9, height: 21),
          const Radius.circular(4.5),
        ),
        ink,
      );
    }

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 4, 55, 8, 9),
        const Radius.circular(2),
      ),
      ink,
    );

    // Arms (drawn first; shoulders and torso overlap their roots)
    const Offset shoulderL = Offset(cx - 23, 68);
    const Offset shoulderR = Offset(cx + 23, 68);

    // Right arm (screen right): relaxed, or raised and waving when celebrating.
    final double up = celebrate ? Curves.easeOutCubic.transform(act) : 0.0;
    final double wave = (loop - 0.5) * 6 * up;
    final Offset wristR = Offset.lerp(
          const Offset(cx + 28, 92),
          const Offset(cx + 31, 52),
          up,
        )! +
        Offset(wave, 0);
    _limb(canvas, const Offset(cx + 25, 72), wristR);
    canvas.drawCircle(wristR, 3.2, ink);
    canvas.save();
    canvas.translate(wristR.dx, wristR.dy + 6 - 12 * up);
    canvas.rotate(up * math.pi); // fingers swing from down to up
    _hand(canvas);
    canvas.restore();

    // Left arm (screen left, towards the notification): lowered -> extended.
    final Offset wristL = Offset.lerp(
      const Offset(cx - 28, 92),
      const Offset(17, 75),
      extend,
    )!;
    final Offset handL = Offset.lerp(
      const Offset(cx - 28, 98),
      const Offset(9, 76),
      extend,
    )!;
    _limb(canvas, const Offset(cx - 25, 72), wristL);
    canvas.drawCircle(wristL, 3.2, ink);
    canvas.save();
    canvas.translate(handL.dx, handL.dy);
    canvas.rotate(extend * math.pi / 2); // fingers swing from down to left
    _hand(canvas);
    canvas.restore();

    // Light emitter in the palm once the hand is out (event colour).
    if (extend > 0) {
      canvas.drawCircle(
        handL,
        6 * extend,
        Paint()
          ..color = accent.withValues(alpha: 0.55 * extend)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(handL, 1.8 * extend, Paint()..color = accent);
    }

    // Torso + belt line
    _pearlRRect(
      canvas,
      Rect.fromCenter(center: const Offset(cx, 78), width: 38, height: 34),
      17,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - 15, 86)
        ..quadraticBezierTo(cx, 95, cx + 15, 86),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Shoulder spheres
    _pearlCircle(canvas, shoulderL, 7);
    _pearlCircle(canvas, shoulderR, 7);

    // Leg joints
    for (final s in const [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + s * 9, 99), width: 6, height: 10),
          const Radius.circular(2),
        ),
        ink,
      );
    }

    // Boots (swing and lift while walking)
    for (final s in const [-1.0, 1.0]) {
      final double dx = s < 0 ? swing * 3 : -swing * 3;
      final double lift =
          s < 0 ? math.max(0.0, swing) * 3 : math.max(0.0, -swing) * 3;
      final double bx = cx + s * 9 + dx;
      final double by = 108 - lift;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(bx, by + 8), width: 22, height: 5),
          const Radius.circular(2.5),
        ),
        ink,
      );
      _pearlRRect(
        canvas,
        Rect.fromCenter(center: Offset(bx, by), width: 21, height: 15),
        7,
      );
    }

    // Helmet
    _pearlRRect(
      canvas,
      Rect.fromCenter(center: const Offset(cx, 34), width: 56, height: 46),
      22,
    );

    // Visor
    final visorRect =
        Rect.fromCenter(center: const Offset(cx, 36), width: 44, height: 31);
    canvas.drawRRect(
      RRect.fromRectAndRadius(visorRect, const Radius.circular(14)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2540), Color(0xFF050814)],
        ).createShader(visorRect),
    );

    // Eyes + mouth (expression)
    _drawFace(canvas, cx);

    // Helmet glint
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx - 14, 19), width: 12, height: 5),
      Paint()..color = const Color(0xCCFFFFFF),
    );

    if (celebrate && act > 0) _drawConfetti(canvas, cx);
    if (badge != _Badge.none) _drawBadge(canvas);
  }

  @override
  bool shouldRepaint(covariant _NotificationRobotPainter oldDelegate) =>
      oldDelegate.extend != extend ||
      oldDelegate.swing != swing ||
      oldDelegate.face != face ||
      oldDelegate.badge != badge ||
      oldDelegate.celebrate != celebrate ||
      oldDelegate.act != act ||
      oldDelegate.loop != loop ||
      oldDelegate.accent != accent;
}

class EmployeeTopbar extends StatefulWidget {
  final EmployeeRole role;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAssignedTasks;
  final VoidCallback? onTapWorkingHours;
  final VoidCallback? onOpenRunningTask;
  /// Tapping the running chip: gets the running item
  /// ({client, due_date, section: 'My Tasks' | 'Content Calendar', task_id, …})
  /// so the dashboard can open that client's workspace on that tab.
  final ValueChanged<Map<String, dynamic>>? onOpenRunningItem;
  final Function(String)? onSearch;

  const EmployeeTopbar({
    super.key,
    required this.role,
    this.onOpenNotifications,
    this.onOpenAssignedTasks,
    this.onTapWorkingHours,
    this.onOpenRunningTask,
    this.onOpenRunningItem,
    this.onSearch,
  });

  @override
  State<EmployeeTopbar> createState() => _EmployeeTopbarState();
}

class _EmployeeTopbarState extends State<EmployeeTopbar> with TickerProviderStateMixin {
  Timer? _pollingTimer;
  int _unreadCount = 0;
  String? _latestMessage;
  bool _showPopup = false;
  Timer? _popupTimer;
  IO.Socket? _socket;
  Set<int> _knownNotificationIds = {};
  final TextEditingController _searchController = TextEditingController();

  String formattedTotalWorkingTime = "00h 00m 00s";

  // ── Working hours + running task (server is the source of truth) ──
  int _baseTotalSecs = 0;               // seconds worked today when last fetched
  DateTime _baseAt = DateTime.now();    // local time of that fetch
  Duration _serverOffset = Duration.zero;
  Map<String, dynamic>? _running;       // {trackingItemId, client, task, sessionStartedAt}
  Timer? _tickTimer;

  late AnimationController _rotateController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late final AnimationController _robotController;
late final AnimationController _actionController; // event-specific robot action
  final AudioPlayer _audioPlayer = AudioPlayer();
  RobotEvent _robotEvent = RobotEvent.generic;
  Timer? _actionTimer;
  // Robot pops up when the employee performs a task action anywhere in the
  // app (Start / Hold / Complete / Restart / Approve / Rework / Reject).
  StreamSubscription<TaskActionSignal>? _taskActionSub;

  bool _isPaused = false;
  bool _isBroadcastPopupShowing = false;

  @override
  void initState() {
    super.initState();
    // This top bar alerts for the notifications list itself (no double sound).
    AppNotificationCenter.layoutPollers++;

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    // Drives the whole robot + laser + panel sequence (see NotificationRobotScene).
    _robotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
      reverseDuration: const Duration(milliseconds: 2200),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Starts when the panel is being revealed; drives pause / celebrate / etc.
    _actionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _glowAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _startPolling();
    _fetchTodayWorkingHours();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _recomputeWorkingDisplay();
    });
    _connectNotificationSocket();
    _checkActiveBroadcast();
    _checkAssignedClientStatusChanges();
    _taskActionSub = AppNotificationCenter.taskActions.listen(_onTaskAction);
  }

  // A task action the employee confirmed (in this top bar, the Employee
  // Workspace, Live Tracking, Day Planner or Task Review). No sound here —
  // the action itself is the trigger, not an incoming notification.
  final math.Random _wishRng = math.Random();
  String _pickWish(List<String> options) =>
      options[_wishRng.nextInt(options.length)];

  void _onTaskAction(TaskActionSignal signal) {
    if (!mounted) return;
    // Friendly, locally generated wishes — not backend text.
    final String name =
        signal.title.trim().isEmpty ? 'your task' : signal.title.trim();
    final RobotEvent event;
    final String message;
    switch (signal.action.toLowerCase()) {
      case 'start':
        event = RobotEvent.taskStarted;
        message = _pickWish([
          '🚀 Started "$name". Let\'s get it done!',
          '💪 On it! "$name" is now in progress.',
          '✨ "$name" started — stay focused, you\'ve got this!',
        ]);
        break;
      case 'restart':
        event = RobotEvent.taskRestarted;
        message = _pickWish([
          '🙌 Welcome back to "$name"! Let\'s finish strong.',
          '😊 Resumed "$name" — pick up right where you left off!',
          '🔁 Back in action on "$name". You\'ve got this!',
        ]);
        break;
      case 'hold':
        event = RobotEvent.taskHold;
        message = _pickWish([
          '😔 "$name" is on hold. Take a breath and resume soon.',
          '⏸️ Paused "$name". It\'ll be here when you\'re ready.',
          '🛑 "$name" held for now — come back to it anytime.',
        ]);
        break;
      case 'complete':
        event = RobotEvent.taskCompleted;
        message = _pickWish([
          '🎉 Congratulations! "$name" is completed.',
          '🥳 Well done! You finished "$name".',
          '✅ Great job! "$name" completed and sent for review.',
        ]);
        break;
      case 'approved':
        event = RobotEvent.taskApproved;
        message = _pickWish([
          '✅ Approved! Brilliant work on "$name".',
          '🌟 "$name" approved — excellent job!',
          '👏 Nailed it! "$name" is approved.',
        ]);
        break;
      case 'rework':
        event = RobotEvent.taskRework;
        message = _pickWish([
          '🔄 "$name" needs a little rework — you can polish it up!',
          '✏️ Small changes needed on "$name". You\'ve got this!',
          '🔧 "$name" sent back for rework — quick fix and done!',
        ]);
        break;
      case 'reject':
      case 'rejected':
        event = RobotEvent.taskRejected;
        message = _pickWish([
          '❌ "$name" was rejected. Check the notes and try again.',
          '💡 "$name" wasn\'t accepted — review the feedback and retry.',
          '🙏 "$name" rejected. Don\'t worry — fix it and resubmit!',
        ]);
        break;
      case 'day_planner_submit':
        event = RobotEvent.plannerSubmitted;
        message = _pickWish([
          '🙌 Good job! Your Day Planner is submitted.',
          '📋 Day Planner submitted — nicely done!',
          '✅ All set! Your Day Planner is in. Great work!',
        ]);
        break;
      case 'share':
        event = RobotEvent.contentShared;
        message = _pickWish([
          '📤 Shared "$name" with the team. Nice teamwork!',
          '🤝 "$name" shared successfully!',
          '📨 Sent "$name" along — great collaboration!',
        ]);
        break;
      default:
        return; // unknown action → no robot
    }
    _triggerTopRightPopup(message, event: event);
  }

  @override
  void dispose() {
    AppNotificationCenter.layoutPollers--;
    _pollingTimer?.cancel();
    _tickTimer?.cancel();
    _popupTimer?.cancel();
    _taskActionSub?.cancel();
    _searchController.dispose();
    _socket?.dispose();
    _audioPlayer.dispose();
    _actionTimer?.cancel();
    _actionController.dispose();
    _rotateController.dispose();
    _robotController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  String get _socketUrl {
    return ApiConfig.baseUrl.trim().replaceFirst(RegExp(r'/api/?$'), '');
  }

void _playNotificationSound() async {
  try {
    await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
  } catch (e) {
    debugPrint("Audio play error: $e");
  }
}

// Future<void> _checkActiveBroadcast() async {
//     final authService = Provider.of<AuthService>(context, listen: false);
//     final employeeId = authService.user?['id'];
//     final employeeName =
//         authService.user?['fullName'] ?? authService.user?['name'] ?? '';

//     if (employeeId == null || employeeName.toString().trim().isEmpty) return;

//     try {
//       final response =
//           await http.get(Uri.parse('${ApiConfig.baseUrl}/broadcast/settings'));

//       if (response.statusCode != 200) return;

//       final data = jsonDecode(response.body) as Map<String, dynamic>;

//       final bool isActive = data['isActive'] ?? false;
//       final bool newClientOn = data['newClientEnabled'] ?? true;
//       final bool inactiveClientOn = data['inactiveClientEnabled'] ?? true;
//       final String adminMessage = (data['message'] ?? '').toString().trim();
//       final String severity =
//           (data['severity'] ?? 'Warning').toString().trim();

//       final dynamic targetEmpId = data['targetEmployeeId'];
//       final String dbBroadcastId = (data['id'] ?? 0).toString();

//       if (!isActive) return;

//       if (targetEmpId != null &&
//           targetEmpId.toString() != employeeId.toString()) {
//         return;
//       }

//       final prefs = await SharedPreferences.getInstance();

//       // 1. ADMIN MANUAL MESSAGE
//       if (adminMessage.isNotEmpty && dbBroadcastId != '0') {
//         final manualKey = 'manual_agreed_$employeeId';
//         final savedMsg = prefs.getString(manualKey) ?? '';

//         // Puthu message-ah iruntha mattum thaan open aagum, same message-ku open aagathu
//         if (savedMsg != adminMessage && !_isBroadcastPopupShowing) {
//           _showBlueWhiteAgreePopup(
//             adminMessage,
//             severity,
//             manualKey,
//             adminMessage,
//             employeeId,
//           );
//           return;
//         }
//       }

//       // 2. AUTOMATED CLIENT / TASK POPUPS
//       final summaryRes = await http.get(
//         Uri.parse(
//           '${ApiConfig.baseUrl}/dashboard/summary/${Uri.encodeComponent(employeeName.toString())}',
//         ),
//       );

//       if (summaryRes.statusCode != 200) return;

//       final summaryData =
//           (jsonDecode(summaryRes.body)['data'] ?? {}) as Map<String, dynamic>;

//       // 2A. New client task assigned
//       final newClientsList =
//           List<dynamic>.from(summaryData['newClientsList'] ?? []);

//       if (newClientOn && newClientsList.isNotEmpty) {
//         final clientNames = newClientsList
//             .map((c) => (c['clientName'] ?? 'Client').toString().trim())
//             .where((name) => name.isNotEmpty)
//             .toSet()
//             .toList()
//           ..sort();

//         if (clientNames.isNotEmpty) {
//           final namesStr = clientNames.join(', ');
//           final triggerMsg =
//               'New client task assigned for: $namesStr. '
//               'Please check your task panel.';

//           final newClientKey = 'new_client_agreed_$employeeId';
//           final savedNewClient = prefs.getString(newClientKey) ?? '';

//           if (savedNewClient != namesStr && !_isBroadcastPopupShowing) {
//             _showBlueWhiteAgreePopup(
//               triggerMsg,
//               'Information',
//               newClientKey,
//               namesStr,
//               employeeId,
//             );
//             return;
//           }
//         }
//       }

//       // 2B. Inactive client
//       final inactiveList =
//           List<dynamic>.from(summaryData['inactiveTodayList'] ?? []);

//       if (inactiveClientOn && inactiveList.isNotEmpty) {
//         final clientNames = inactiveList
//             .map((c) => (c['clientName'] ?? 'Client').toString().trim())
//             .where((name) => name.isNotEmpty)
//             .toSet()
//             .toList()
//           ..sort();

//         if (clientNames.isNotEmpty) {
//           final namesStr = clientNames.join(', ');
//           final triggerMsg =
//               'Assigned client(s) marked inactive: $namesStr.';

//           final inactiveKey = 'inactive_client_agreed_$employeeId';
//           final savedInactive = prefs.getString(inactiveKey) ?? '';

//           if (savedInactive != namesStr && !_isBroadcastPopupShowing) {
//             _showBlueWhiteAgreePopup(
//               triggerMsg,
//               'Information',
//               inactiveKey,
//               namesStr,
//               employeeId,
//             );
//             return;
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint("Broadcast check error: $e");
//     }
//   }

//   void _showBlueWhiteAgreePopup(String message, String severity, String storageKey, String contentValue, dynamic employeeId) {
//     if (!mounted) return;
//     setState(() {
//       _isBroadcastPopupShowing = true;
//     });

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return PopScope(
//           canPop: false,
//           child: AlertDialog(
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             contentPadding: EdgeInsets.zero,
//             content: Container(
//               width: 420,
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(20),
//                 gradient: const LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [Color(0xFFF0F5FF), Colors.white],
//                 ),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF0757D5).withValues(alpha: 0.1),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(
//                       severity == 'Emergency' 
//                           ? Icons.error_outline 
//                           : severity == 'Warning' 
//                               ? Icons.warning_amber_rounded 
//                               : Icons.info_outline_rounded,
//                       color: const Color(0xFF0757D5),
//                       size: 32,
//                     ),
//                   ),
//                   const SizedBox(height: 14),
//                   Text(
//                     '$severity Alert',
//                     style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF04296B)),
//                   ),
//                   const SizedBox(height: 10),
//                   Text(
//                     message,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
//                   ),
//                   const SizedBox(height: 24),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF0757D5),
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                         elevation: 0,
//                       ),
//                       onPressed: () async {
//                         final prefs = await SharedPreferences.getInstance();
//                         // Indha specific message / client string-ah save seithu viduvathal, adutha murai same message-ku popup varaathu
//                         await prefs.setString(storageKey, contentValue);

//                         if (dialogContext.mounted) {
//                           Navigator.of(dialogContext).pop();
//                         }
//                         setState(() {
//                           _isBroadcastPopupShowing = false;
//                         });
//                       },
//                       child: const Text(
//                         'Agree',
//                         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

  // Independent client-status broadcast checker.
  // Uses the existing blue-and-white Agree popup.
  bool _clientStatusCheckRunning = false;

  Future<void> _checkAssignedClientStatusChanges() async {
    if (!mounted || _clientStatusCheckRunning) return;
    _clientStatusCheckRunning = true;

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final employeeId = (auth.user?['id'] ?? '').toString();
      final employeeName =
          (auth.user?['fullName'] ?? auth.user?['name'] ?? '')
              .toString().trim();

      if (employeeId.isEmpty || employeeName.isEmpty) return;

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/dashboard/summary/'
          '${Uri.encodeComponent(employeeName)}',
        ),
      );

      if (!mounted || response.statusCode != 200) return;

      final payload = jsonDecode(response.body);
      if (payload is! Map) return;

      final data = payload['data'];
      if (data is! Map) return;

      final rows = data['assignedClientStatuses'];
      if (rows is! List || rows.isEmpty) return;

      final current = <String, bool>{};
      final names = <String, String>{};

      for (final row in rows) {
        if (row is! Map) continue;

        final id = (row['clientId'] ?? '').toString();
        if (id.isEmpty) continue;

        final raw = row['isActive'];
        current[id] = raw == 1 || raw == true || raw.toString() == '1';
        names[id] = (row['clientName'] ?? 'Client').toString();
      }

      if (current.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final snapshotKey = 'client_status_snapshot_v3_$employeeId';
      final pendingKey = 'client_status_pending_v3_$employeeId';

      final oldText = prefs.getString(snapshotKey);

      // Initial load: record current statuses, do not announce old changes.
      if (oldText == null) {
        await prefs.setString(snapshotKey, jsonEncode(current));
        return;
      }

      final oldStatuses =
          Map<String, dynamic>.from(jsonDecode(oldText) as Map);

      final pendingText = prefs.getString(pendingKey);
      final pending = pendingText == null
          ? <dynamic>[]
          : List<dynamic>.from(jsonDecode(pendingText) as List);

      // Detect actual observed status transitions.
      for (final entry in current.entries) {
        // Notify when a client first appears in this employee's
        // assignment list, or when its Active/Inactive status changes.
        if (oldStatuses.containsKey(entry.key) &&
            oldStatuses[entry.key] == entry.value) {
          continue;
        }

        final clientName = names[entry.key] ?? 'Client';
        final status = entry.value ? 'Active' : 'Inactive';

        final eventId =
            '${entry.key}_${status}_${DateTime.now().microsecondsSinceEpoch}';

        pending.add({
          'key': 'client_status_agreed_${employeeId}_${entry.key}',
          'eventId': eventId,
          'message': entry.value
              ? 'Your assigned client $clientName has been marked Active. '
                'Please review your assigned tasks.'
              : 'Your assigned client $clientName has been marked Inactive. '
                'Please review your assigned tasks.',
        });
      }

      // Persist pending alerts before updating the last-known status.
      await prefs.setString(pendingKey, jsonEncode(pending));
      await prefs.setString(snapshotKey, jsonEncode(current));

      // Do not overlap manual broadcasts or other existing popup dialogs.
      if (!mounted || _isBroadcastPopupShowing) return;

      // Existing Agree button writes the acknowledged event ID.
      while (pending.isNotEmpty) {
        final event = Map<String, dynamic>.from(pending.first as Map);
        final key = event['key'].toString();
        final eventId = event['eventId'].toString();

        if (prefs.getString(key) == eventId) {
          pending.removeAt(0);
          continue;
        }

        await prefs.setString(pendingKey, jsonEncode(pending));

        if (!mounted || _isBroadcastPopupShowing) return;

        _showBlueWhiteAgreePopup(
          event['message'].toString(),
          'Information',
          key,
          eventId,
          employeeId,
        );
        return;
      }

      await prefs.setString(pendingKey, jsonEncode(pending));
    } catch (e) {
      debugPrint('Assigned client status popup error: $e');
    } finally {
      _clientStatusCheckRunning = false;
    }
  }
Future<void> _checkActiveBroadcast() async {
  final authService = Provider.of<AuthService>(context, listen: false);
  final employeeId = authService.user?['id'];
  final employeeName =
      authService.user?['fullName'] ?? authService.user?['name'] ?? '';

  if (employeeId == null || employeeName.toString().trim().isEmpty) return;

  try {
    final response =
        await http.get(Uri.parse('${ApiConfig.baseUrl}/broadcast/settings'));

    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final bool isActive = data['isActive'] ?? false;
    final bool newClientOn = data['newClientEnabled'] ?? true;
    final bool inactiveClientOn = data['inactiveClientEnabled'] ?? true;
    final String adminMessage = (data['message'] ?? '').toString().trim();
    final String severity =
        (data['severity'] ?? 'Warning').toString().trim();

    final dynamic targetEmpId = data['targetEmployeeId'];
    final String dbBroadcastId = (data['id'] ?? 0).toString();

    if (!isActive) return;

    if (targetEmpId != null &&
        targetEmpId.toString() != employeeId.toString()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. ADMIN MANUAL MESSAGE
    if (adminMessage.isNotEmpty && dbBroadcastId != '0') {
      final manualKey = 'manual_agreed_$employeeId';
      final savedMsg = prefs.getString(manualKey) ?? '';

      // Puthu message-ah iruntha mattum popup open aagum
      if (savedMsg != adminMessage && !_isBroadcastPopupShowing) {
        _showBlueWhiteAgreePopup(
          adminMessage,
          severity,
          manualKey,
          adminMessage,
          employeeId,
        );
        return;
      }
    }

    // 2. AUTOMATED CLIENT / TASK POPUPS
    final summaryRes = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/dashboard/summary/${Uri.encodeComponent(employeeName.toString())}',
      ),
    );

    if (summaryRes.statusCode != 200) return;

    final summaryData =
        (jsonDecode(summaryRes.body)['data'] ?? {}) as Map<String, dynamic>;

    // 2A. New client task assigned
    final newClientsList =
        List<dynamic>.from(summaryData['newClientsList'] ?? []);

    if (newClientOn && newClientsList.isNotEmpty) {
      final clientNames = newClientsList
          .map((c) => (c['clientName'] ?? 'Client').toString().trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (clientNames.isNotEmpty) {
        final namesStr = clientNames.join(', ');
        final triggerMsg =
            'New client task assigned for: $namesStr. '
            'Please check your task panel.';

        final newClientKey = 'new_client_agreed_$employeeId';
        final savedNewClient = prefs.getString(newClientKey) ?? '';

        if (savedNewClient != namesStr && !_isBroadcastPopupShowing) {
          _showBlueWhiteAgreePopup(
            triggerMsg,
            'Information',
            newClientKey,
            namesStr,
            employeeId,
          );
          return;
        }
      }
    }

    // 2B. Inactive client
    final inactiveList =
        List<dynamic>.from(summaryData['inactiveTodayList'] ?? []);

    if (inactiveClientOn && inactiveList.isNotEmpty) {
      final clientNames = inactiveList
          .map((c) => (c['clientName'] ?? 'Client').toString().trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (clientNames.isNotEmpty) {
        final namesStr = clientNames.join(', ');
        final triggerMsg =
            'Assigned client(s) marked inactive: $namesStr.';

        final inactiveKey = 'inactive_client_agreed_$employeeId';
        final savedInactive = prefs.getString(inactiveKey) ?? '';

        if (savedInactive != namesStr && !_isBroadcastPopupShowing) {
          _showBlueWhiteAgreePopup(
            triggerMsg,
            'Information',
            inactiveKey,
            namesStr,
            employeeId,
          );
          return;
        }
      }
    }
  } catch (e) {
    debugPrint("Broadcast check error: $e");
  }
}


// ============================================================
// BLUE + WHITE BROADCAST POPUP
// ============================================================

void _showBlueWhiteAgreePopup(
  String message,
  String severity,
  String storageKey,
  String contentValue,
  dynamic employeeId,
) {
  if (!mounted) return;

  setState(() {
    _isBroadcastPopupShowing = true;
  });

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF0F5FF),
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ------------------------------------------------
                // ICON
                // ------------------------------------------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0757D5).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    severity == 'Emergency'
                        ? Icons.error_outline
                        : severity == 'Warning'
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline_rounded,
                    color: const Color(0xFF0757D5),
                    size: 32,
                  ),
                ),

                const SizedBox(height: 14),

                // ------------------------------------------------
                // TITLE
                // ------------------------------------------------
                Text(
                  '$severity Alert',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF04296B),
                  ),
                ),

                const SizedBox(height: 10),

                // ------------------------------------------------
                // MESSAGE WITH HIGHLIGHT
                // ------------------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: SelectableText.rich(
                    TextSpan(
                      children: _buildHighlightedMessage(message),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ------------------------------------------------
                // AGREE BUTTON
                // ------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0757D5),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final prefs =
                          await SharedPreferences.getInstance();

                      // Same message / same client list-ku
                      // next time popup varaama irukka save pannum.
                      await prefs.setString(
                        storageKey,
                        contentValue,
                      );

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }

                      if (mounted) {
                        setState(() {
                          _isBroadcastPopupShowing = false;
                        });
                      }
                    },
                    child: const Text(
                      'Agree',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}


// ============================================================
// MESSAGE HIGHLIGHTER
// ============================================================

List<TextSpan> _buildHighlightedMessage(String message) {
  final List<TextSpan> spans = [];

  final RegExp regex = RegExp(
    r'https?:\/\/[^\s]+|'
    r'@[A-Za-z0-9_.]+|'
    r'\b(?:click here|click|here|important|urgent|'
    r'action required|please note|warning|emergency|'
    r'new client|task assigned|inactive)\b',
    caseSensitive: false,
  );

  final List<_HighlightPart> highlights = [];

  // ---------------------------------------------
  // Keyword / URL / @employee highlight
  // ---------------------------------------------
  for (final match in regex.allMatches(message)) {
    highlights.add(
      _HighlightPart(
        start: match.start,
        end: match.end,
      ),
    );
  }

  // ---------------------------------------------
  // Highlight value after ":"
  //
  // Example:
  // Assigned client(s) marked inactive: JEYASRI HOSTAL.
  //
  // "JEYASRI HOSTAL" will also be highlighted.
  // ---------------------------------------------
  final colonIndex = message.indexOf(':');

  if (colonIndex != -1) {
    final valueStart = colonIndex + 1;

    final value = message
        .substring(valueStart)
        .trim();

    if (value.isNotEmpty) {
      final actualStart =
          message.indexOf(value, valueStart);

      if (actualStart >= 0) {
        highlights.add(
          _HighlightPart(
            start: actualStart,
            end: actualStart + value.length,
          ),
        );
      }
    }
  }

  // Sort
  highlights.sort(
    (a, b) => a.start.compareTo(b.start),
  );

  // Remove overlapping ranges
  final List<_HighlightPart> cleanHighlights = [];

  int lastEnd = -1;

  for (final item in highlights) {
    if (item.start >= lastEnd) {
      cleanHighlights.add(item);
      lastEnd = item.end;
    }
  }

  // ---------------------------------------------
  // Create TextSpans
  // ---------------------------------------------
  int lastIndex = 0;

  for (final item in cleanHighlights) {
    // Normal text
    if (item.start > lastIndex) {
      spans.add(
        TextSpan(
          text: message.substring(
            lastIndex,
            item.start,
          ),
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Highlight
    spans.add(
      TextSpan(
        text: message.substring(
          item.start,
          item.end,
        ),
        style: const TextStyle(
          color: Color(0xFF0757D5),
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF0757D5),
          decorationThickness: 1.5,
        ),
      ),
    );

    lastIndex = item.end;
  }

  // Remaining text
  if (lastIndex < message.length) {
    spans.add(
      TextSpan(
        text: message.substring(lastIndex),
        style: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  return spans;
}

  void _connectNotificationSocket() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeName = authService.user?['fullName'];
    if (employeeName == null || employeeName.toString().isEmpty) return;

    try {
      _socket = IO.io(_socketUrl, {
        'transports': ['websocket'],
        'auth': {'token': AuthStorage.cachedToken},
        'autoConnect': false,
        'reconnection': true,
      });

      _socket!.connect();

      void handle(dynamic payload) {
        if (!mounted || payload is! Map) return;
        final recipient = payload['recipientName']?.toString() ?? '';
        final sender = payload['senderName']?.toString() ?? '';
        final isGroup = payload['isGroup'] == true ||
            payload['isGroup'] == 1 ||
            payload['isGroup']?.toString() == '1';

        if (isGroup || recipient != employeeName || sender == employeeName) return;

        final id = int.tryParse(payload['id']?.toString() ?? '') ?? 0;
        if (id != 0 && _knownNotificationIds.contains(id)) return;
        if (id != 0) _knownNotificationIds.add(id);

        setState(() => _unreadCount += 1);

        final raw = payload['message']?.toString() ?? 'New message';
        final parsed = parseNotificationMessage(raw);

        _playNotificationSound();
        _triggerTopRightPopup(
          parsed.preview,
          event: classifyNotificationEvent(payload, parsed.decoded, parsed.preview),
        );
      }

      _socket!.on('new_notification', handle);
      _socket!.on('task_updated', (_) {
        if (mounted) _fetchTodayWorkingHours();
      });
    } catch (e) {
      debugPrint('Topbar socket init error: $e');
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkNewNotifications();
      await _fetchTodayWorkingHours();
      await _checkActiveBroadcast();
      await _checkAssignedClientStatusChanges();
    });
  }

  Future<void> _fetchTodayWorkingHours() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeName = authService.user?['fullName'] ?? authService.user?['name'] ?? authService.user?['username'];
    if (employeeName == null || employeeName.toString().isEmpty) return;
    try {
      final now = DateTime.now();
      final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      // Running item (task or Content Calendar category) + today's total —
      // the same numbers My Tasks, Live Tracking and the Day Planner use.
      final url = Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/running').replace(
        queryParameters: {'employee': employeeName.toString(), 'date': formattedDate},
      );
      final r = await http.get(url);
      if (r.statusCode == 200 && mounted) {
        final body = jsonDecode(r.body);
        final serverNow = DateTime.tryParse((body['serverNow'] ?? '').toString());
        setState(() {
          _baseTotalSecs = (body['totalSecs'] as num?)?.toInt() ?? 0;
          _baseAt = DateTime.now();
          _serverOffset = serverNow != null ? serverNow.difference(DateTime.now()) : Duration.zero;
          _running = body['running'] is Map ? Map<String, dynamic>.from(body['running'] as Map) : null;
        });
        _recomputeWorkingDisplay();
      }
    } catch (e) {
      debugPrint("Working hours fetch error: $e");
    }
  }

  // Today's work only: the server counts sessions started today, and the
  // total ticks only while such a session is running. A task left running
  // from an earlier day adds nothing until it is held and restarted.
  bool get _runningToday => _running != null && _running!['today_running'] == true;

  void _recomputeWorkingDisplay() {
    int total = _baseTotalSecs;
    if (_runningToday) total += DateTime.now().difference(_baseAt).inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final sec = total % 60;
    // Runs live with seconds while something is in progress.
    final text = '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m '
        '${sec.toString().padLeft(2, '0')}s';
    if (_runningToday || text != formattedTotalWorkingTime) {
      setState(() => formattedTotalWorkingTime = text);
    }
  }

  String _runningTimerText() {
    // Total time on the running item (all sessions), ticking live.
    final base = int.tryParse('${_running?['elapsedSecs'] ?? ''}');
    int secs;
    if (base != null) {
      secs = base + DateTime.now().difference(_baseAt).inSeconds;
    } else {
      final started = DateTime.tryParse((_running?['sessionStartedAt'] ?? '').toString());
      if (started == null) return '00:00:00';
      secs = DateTime.now().add(_serverOffset).difference(started).inSeconds;
    }
    if (secs < 0) secs = 0;
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  Future<void> _holdRunningTask() async {
    final running = _running;
    if (running == null) return;
    final token = Provider.of<AuthService>(context, listen: false).token ?? '';
    // TaskActions.run emits a confirmed-action signal on success, which the
    // listener below turns into the ON HOLD robot — no manual trigger here.
    await TaskActions.run(
      context, Map<String, dynamic>.from(running), 'hold', token: token);
    await _fetchTodayWorkingHours();
  }

  // Compact "running task" chip shown next to Today Working Hours.
  Widget _buildRunningChip() {
    final running = _running;
    if (running == null) return const SizedBox.shrink();
    final client = (running['client'] ?? '').toString();
    var title = '${client.isEmpty ? '' : '$client · '}${running['task'] ?? ''}';
    if (title.length > 32) title = '${title.substring(0, 32)}…';
    // Still running from an earlier day → ask to hold it (not counted today).
    final stale = running['stale_running'] == true;
    final since = '${running['running_since'] ?? ''}'.split('-');
    final staleText = since.length == 3
        ? 'Running since ${since[2]}/${since[1]} · hold it'
        : 'Running from an earlier day · hold it';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: stale ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            final item = _running;
            if (item != null && widget.onOpenRunningItem != null) {
              widget.onOpenRunningItem!(Map<String, dynamic>.from(item));
            } else {
              widget.onOpenRunningTask?.call();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(stale ? Icons.warning_amber_rounded : Icons.circle,
                    size: stale ? 13 : 9, color: stale ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF14532D))),
                    Text(stale ? staleText : _runningTimerText(),
                        style: TextStyle(
                            fontSize: stale ? 10 : 11.5,
                            fontWeight: FontWeight.w900,
                            color: stale ? const Color(0xFFB91C1C) : const Color(0xFF166534))),
                  ],
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _holdRunningTask,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Hold',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkNewNotifications() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeName = authService.user?['fullName'];
    
    if (employeeName == null || employeeName.isEmpty) return;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/notifications/${Uri.encodeComponent(employeeName)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List rows = body["data"] ?? [];

        int unread = 0;
        Set<int> currentIds = {};
        bool hasNewNotification = false;
        String? latestMsgText;
        RobotEvent latestEvent = RobotEvent.generic;

        for (var row in rows) {
          int id = int.tryParse(row["id"]?.toString() ?? '0') ?? 0;
          currentIds.add(id);

          bool isSentByMe = row["type"] == "SENT";
          bool isSeen = row["isSeen"] == true || row["isSeen"] == 1 || row["isSeen"].toString() == "true";

          if (!isSentByMe && !isSeen) {
            unread++;
          }

          if (_knownNotificationIds.isNotEmpty && !_knownNotificationIds.contains(id) && !isSentByMe && !isSeen) {
            hasNewNotification = true;
            final parsed = parseNotificationMessage(row["message"]?.toString() ?? '');
            if (parsed.preview.trim().isNotEmpty) {
              latestMsgText = parsed.preview;
              latestEvent = classifyNotificationEvent(
                row is Map ? row : null,
                parsed.decoded,
                parsed.preview,
              );
            }
          }
        }

        setState(() {
          _unreadCount = unread;
          if (_knownNotificationIds.isEmpty && currentIds.isNotEmpty) {
            _knownNotificationIds = currentIds;
          } else if (currentIds.isNotEmpty) {
            _knownNotificationIds = currentIds;
          }
        });

         if (hasNewNotification) {
          _playNotificationSound();
          _triggerTopRightPopup(
            latestMsgText ?? "You have a new notification",
            event: latestEvent,
          );
        }
      }
    } catch (e) {
      debugPrint("Polling error: $e");
    }
  }

void _triggerTopRightPopup(String message, {RobotEvent event = RobotEvent.generic}) {
  if (!mounted) return;

  _popupTimer?.cancel();

  final bool wasVisible = _showPopup;

  setState(() {
    _latestMessage = message;
    _robotEvent = event;
    _showPopup = true;
  });

  // Robot walks in, extends its hand, fires the laser, panel is revealed.
  if (wasVisible) {
    _robotController.forward();
  } else {
    _robotController.forward(from: 0);
  }

  // The event-specific action (pause symbol, celebration, ...) plays once
  // the panel starts to reveal (70% of the opening animation).
  _actionController.stop();
  _actionController.value = 0;
  final int actionDelayMs = wasVisible
      ? 0
      : ((0.70 - _robotController.value).clamp(0.0, 1.0) *
              _robotController.duration!.inMilliseconds)
          .round();
  _actionTimer?.cancel();
  _actionTimer = Timer(Duration(milliseconds: actionDelayMs), () {
    if (!mounted || !_showPopup) return;
    _actionController.forward(from: 0);
  });

  // Panel stays open for the event's hold time (5-7 s) once fully revealed.
  final int remainingOpenMs = ((1 - _robotController.value) *
          _robotController.duration!.inMilliseconds)
      .round();
  _popupTimer = Timer(
    Duration(milliseconds: remainingOpenMs + event.holdMs),
    _dismissPopup,
  );
}

// Panel closes, laser retracts, hand lowers, robot walks away.
void _dismissPopup() {
  if (!mounted) return;

  _robotController.reverse().whenComplete(() {
    if (!mounted) return;
    if (_robotController.status == AnimationStatus.dismissed) {
      _actionController.stop();
      _actionController.value = 0;
      setState(() {
        _showPopup = false;
      });
    }
  });
}

 @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    final bool isSmallMobile = MediaQuery.of(context).size.width < 450;

    return SizedBox(
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 8 : 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!isDesktop) ...[
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: AppColors.textDark),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  SizedBox(width: isSmallMobile ? 4 : 12),
                ],

                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(Icons.search, size: 16, color: AppColors.textGrey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {});
                                widget.onSearch?.call(value);
                              },
                              decoration: const InputDecoration(
                                hintText: 'Search client name…',
                                hintStyle: TextStyle(fontSize: 12, color: AppColors.textGrey),
                                // No theme box: no blue focus line, no white fill.
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                filled: false,
                                fillColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppColors.textGrey),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              onPressed: () {
                                _searchController.clear();
                                widget.onSearch?.call('');
                                setState(() {});
                              },
                            ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),

                MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      _isPaused = true;
                      _rotateController.stop();
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _isPaused = false;
                      _rotateController.repeat();
                    });
                  },
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPaused = !_isPaused;
                        if (_isPaused) {
                          _rotateController.stop();
                        } else {
                          _rotateController.repeat();
                        }
                      });
                      widget.onTapWorkingHours?.call();
                    },
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_rotateController, _glowAnimation]),
                      builder: (context, child) {
                        final double angle = _isPaused 
                            ? 0.0 
                            : _rotateController.value * 2 * 3.141592653589793;
                        final bool isBackSide = angle > (3.141592653589793 / 2) && angle < (3 * 3.141592653589793 / 2);
                        final double currentGlow = _glowAnimation.value;

                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          alignment: Alignment.center,
                          child: Transform(
                            transform: Matrix4.identity()
                              ..rotateY(isBackSide ? 3.141592653589793 : 0.0),
                            alignment: Alignment.center,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  // Soft, readable glow (deep blue / violet).
                                  BoxShadow(
                                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
                                    blurRadius: currentGlow * 1.2,
                                    spreadRadius: currentGlow * 0.15,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                                    blurRadius: currentGlow * 1.6,
                                    spreadRadius: currentGlow * 0.1,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Material(
                        color: const Color(0xFFF1F6FF),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {},
                          child: CustomPaint(
                            painter: MovingNeonBorderPainter(
                              animationValue: _isPaused ? 0.0 : _rotateController.value,
                              borderRadius: BorderRadius.circular(8),
                              strokeWidth: 2.5,
                            ),
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(0, 14, 65, 141),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 4),
                                  ShaderMask(
                                    shaderCallback: (bounds) {
                                      return LinearGradient(
                                        // Dark, high-contrast colours on the light
                                        // pill (navy → royal blue → violet → teal).
                                        colors: const [
                                          Color(0xFF0A3D91),
                                          Color(0xFF1D4ED8),
                                          Color(0xFF6D28D9),
                                          Color(0xFF0F766E),
                                          Color(0xFF0A3D91),
                                        ],
                                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                                        transform: GradientRotation(_isPaused ? 0.0 : _rotateController.value * 2 * 3.141592653589793),
                                      ).createShader(bounds);
                                    },
                                    child: Text(
                                      isSmallMobile ? "Today: $formattedTotalWorkingTime" : "Today Working Hours: $formattedTotalWorkingTime",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isSmallMobile) _buildRunningChip(),
                const SizedBox(width: 8),
                
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, size: 20, color: AppColors.textDark),
                      onPressed: widget.onOpenNotifications,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$_unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                
                if (!isSmallMobile) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.textDark),
                  const SizedBox(width: 16),
                  Container(height: 30, width: 1, color: AppColors.border),
                  const SizedBox(width: 14),
                ],

                Consumer<AuthService>(
                  builder: (context, authService, _) {
                    final user = authService.user;
                    final employeeName = user?['fullName'] ?? 'Employee';
                    final employeeRole = user?['role'] ?? widget.role.title;
                    final initials = user?['initials'] ?? _generateInitials(employeeName);

                    final String? profilePhoto = user?['profile_photo']?.toString() ?? user?['profilePhoto']?.toString();
                    final String avatarColorHex = user?['avatar_color']?.toString() ?? user?['avatarColor']?.toString() ?? '';

                    Color avatarColor = AppColors.primary;
                    if (avatarColorHex.isNotEmpty) {
                      try {
                        final s = avatarColorHex.replaceAll('#', '');
                        avatarColor = Color(int.parse('FF$s', radix: 16));
                      } catch (_) {}
                    }

                    ImageProvider? profileImage;
                    if (profilePhoto != null && profilePhoto.isNotEmpty) {
                      try {
                        profileImage = MemoryImage(base64Decode(profilePhoto.split(',').last));
                      } catch (_) {}
                    }

                    if (!isDesktop) {
                      return PopupMenuButton<int>(
                        offset: const Offset(0, 45),
                        icon: CircleAvatar(
                          radius: 16,
                          backgroundColor: avatarColor,
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))
                              : null,
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                                const SizedBox(height: 2),
                                Text(employeeRole, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              employeeName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark),
                            ),
                            Text(
                              employeeRole,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: avatarColor,
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                )
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

 if (_showPopup)
  Positioned(
    top: 68,
    right: 12,
    child: Material(
      color: Colors.transparent,
      child: NotificationRobotScene(
        controller: _robotController,
        pulse: _glowController,
        action: _actionController,
        event: _robotEvent,
        message: _latestMessage ?? 'You have a new notification.',
        maxWidth: MediaQuery.of(context).size.width - 24,
      ),
    ),
  ),
  ],
      ),
    );
  }
 
  String _generateInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    } else {
      return parts.first[0].toUpperCase();
    }
  }
}

class MovingNeonBorderPainter extends CustomPainter {
  final double animationValue;
  final BorderRadius borderRadius;
  final double strokeWidth;

  MovingNeonBorderPainter({
    required this.animationValue,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = borderRadius.toRRect(rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * 3.141592653589793,
        colors: const [
          Color(0xFF1D4ED8),
          Color(0xFF7C3AED),
          Color(0xFFDB2777),
          Color(0xFFD97706),
          Color(0xFF0891B2),
          Color(0xFF1D4ED8),
        ],
        transform: GradientRotation(animationValue * 2 * 3.141592653589793),
      ).createShader(rect);

    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant MovingNeonBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _HighlightPart {
  final int start;
  final int end;

  _HighlightPart({
    required this.start,
    required this.end,
  });
}