import 'package:flutter/material.dart';
import '../core/config/app_brand.dart';

class FamalthWatermark extends StatelessWidget {
  final Color? color;
  final double fontSize;
  final bool showVersion;
  final String version;

  const FamalthWatermark({
    super.key,
    this.color,
    this.fontSize = 12,
    this.showVersion = false,
    this.version = '1.1.32',
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Colors.grey.shade600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: fontSize + 6,
              height: fontSize + 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/famalth_lynx_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.verified_user_outlined,
                    size: fontSize + 2,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              AppBrand.permanentWatermark,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        if (showVersion) ...[
          const SizedBox(height: 3),
          Text(
            'Version $version • ${AppBrand.permanentCopyright}',
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: fontSize - 1,
            ),
          ),
        ],
      ],
    );
  }
}
