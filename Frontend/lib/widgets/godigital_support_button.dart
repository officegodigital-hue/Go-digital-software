import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class GoDigitalSupportButton extends StatelessWidget {
  const GoDigitalSupportButton({super.key, this.triggerBuilder});

  final Widget Function(VoidCallback onTap)? triggerBuilder;

  static const Color blue = Color(0xFF0757D5);
  static const Color green = Color(0xFF16A34A);

  static const String contactName = 'Micheal Mithra';
  static const String phoneNumber = '+91 8610096458';

  Future<void> _contact(BuildContext context, String url) async {
    try {
      final success = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the selected application.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the selected application.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        backgroundColor: WidgetStateProperty.all(Colors.white),
        elevation: WidgetStateProperty.all(9),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE4EAF3)),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Support',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF14213D),
                            ),
                          ),
                          Text(
                            'GoDigital Support Team',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF718096),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text(
                  'CONTACT PERSON',
                  style: TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  contactName,
                  style: TextStyle(
                    color: Color(0xFF14213D),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                const Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 17,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 8),
                    Text(
                      phoneNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 19),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _contact(context, 'tel:+918610096458'),
                        icon: const Icon(Icons.call_rounded, size: 16),
                        label: const Text('Call Now'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: blue,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _contact(context, 'https://wa.me/918610096458'),
                        icon: Image.asset(
                          'assets/icons/whatsapp.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                        label: const Text('WhatsApp'),
                        style: FilledButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        void toggle() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        if (triggerBuilder != null) {
          return triggerBuilder!(toggle);
        }

        return OutlinedButton.icon(
          onPressed: toggle,
          icon: const Icon(Icons.support_agent_rounded, size: 17),
          label: const Text(
            'Support',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: blue,
            backgroundColor: const Color(0xFFF4F8FF),
            side: const BorderSide(color: Color(0xFFD6E4FF)),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}
