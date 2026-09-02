import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';

class BrandLogoWidget extends StatelessWidget {
  final String? logoPath;
  final double size;
  final Widget? customFallback;

  static final Map<String, Uint8List> _bytesCache = {};

  const BrandLogoWidget({
    super.key,
    required this.logoPath,
    this.size = 76,
    this.customFallback,
  });

  @override
  Widget build(BuildContext context) {
    if (logoPath != null && logoPath!.trim().isNotEmpty) {
      final path = logoPath!.trim();

      // 1. Base64 Data URI or raw Base64 string
      if (path.startsWith('data:image') ||
          path.contains(';base64,') ||
          (path.length > 100 && !path.contains(' '))) {
        try {
          final base64Str = path.contains(',') ? path.split(',').last : path;
          final cleanStr = base64Str.trim();

          Uint8List? bytes = _bytesCache[cleanStr];
          if (bytes == null) {
            bytes = base64Decode(cleanStr);
            _bytesCache[cleanStr] = bytes;
          }

          return ClipOval(
            key: ValueKey('logo-mem-${cleanStr.hashCode}-$size'),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _fallback(),
            ),
          );
        } catch (_) {}
      }

      // 2. Full HTTP / HTTPS URL
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return ClipOval(
          key: ValueKey('logo-net-$path-$size'),
          child: Image.network(
            path,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        );
      }

      // 3. Relative Server Path (e.g. /uploads/logo.png)
      if (path.startsWith('/') || path.startsWith('uploads/')) {
        final baseUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
        final fullUrl =
            path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
        return ClipOval(
          key: ValueKey('logo-rel-$fullUrl-$size'),
          child: Image.network(
            fullUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        );
      }

      // 4. Local File Path (non-web)
      if (!kIsWeb && File(path).existsSync()) {
        return ClipOval(
          key: ValueKey('logo-file-$path-$size'),
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        );
      }
    }

    // 5. Mascot Fallback
    return _fallback();
  }

  Widget _fallback() {
    if (customFallback != null) return customFallback!;

    return ClipOval(
      key: ValueKey('logo-fallback-mascot-$size'),
      child: Image.asset(
        'assets/images/famalth_lynx_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.storefront_rounded,
              color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}
