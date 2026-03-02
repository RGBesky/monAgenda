import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Centered monAgenda logo header for settings pages.
class SettingsLogoHeader extends StatelessWidget {
  const SettingsLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : Colors.grey)
                        .withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SvgPicture.asset(
                  isDark
                      ? 'assets/logos/logo_dark.svg'
                      : 'assets/logos/logo_light.svg',
                  width: 64,
                  height: 64,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'monAgenda',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
