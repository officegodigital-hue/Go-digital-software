// lib/widgets/emergency_popup_dialog.dart

import 'package:flutter/material.dart';

class EmergencyPopupDialog extends StatelessWidget {
  final String message;
  final String severity; // Emergency, Warning, Important
  final VoidCallback onAgree;

  const EmergencyPopupDialog({
    super.key,
    required this.message,
    required this.severity,
    required this.onAgree,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents closing without clicking Agree
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              severity == 'Emergency' 
                  ? Icons.error 
                  : severity == 'Warning' 
                      ? Icons.warning_amber_rounded 
                      : Icons.info,
              color: severity == 'Emergency' 
                  ? Colors.red 
                  : severity == 'Warning' 
                      ? Colors.orange 
                      : Colors.blue,
            ),
            const SizedBox(width: 10),
            Text('$severity Alert', style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0757D5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onAgree,
            child: const Text('Agree', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}