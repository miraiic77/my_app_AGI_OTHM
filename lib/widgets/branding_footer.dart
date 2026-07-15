import 'package:flutter/material.dart';

class BrandingFooter extends StatelessWidget {
  const BrandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code, color: Colors.teal.shade400, size: 14),
          const SizedBox(width: 6),
          Text(
            "Developed by Mirza's | Attendance V.1",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: Colors.teal.shade700, // Nice professional color
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}