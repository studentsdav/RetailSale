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

  final BoxFit fit;
  final EdgeInsetsGeometry? padding;

  const BrandLogoWidget({
    super.key,
    required this.logoPath,
    this.size = 76,
    this.customFallback,
    this.fit = BoxFit.contain,
    this.padding,
  });

  Widget _wrap(Widget child, Key key) {
    final effectivePadding = padding ?? EdgeInsets.all(size * 0.22);
    return ClipOval(
      key: key,
      child: Container(
        width: size,
        height: size,
        color: Colors.transparent,
        padding: effectivePadding,
        child: child,
      ),
    );
  }

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

          return _wrap(
            Image.memory(
              bytes,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _fallback(),
            ),
            ValueKey('logo-mem-${cleanStr.hashCode}-$size'),
          );
        } catch (_) {}
      }

      // 2. Full HTTP / HTTPS URL
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return _wrap(
          Image.network(
            path,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
          ValueKey('logo-net-$path-$size'),
        );
      }

      // 3. Relative Server Path (e.g. /uploads/logo.png)
      if (path.startsWith('/') || path.startsWith('uploads/')) {
        final baseUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
        final fullUrl =
            path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
        return _wrap(
          Image.network(
            fullUrl,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
          ValueKey('logo-rel-$fullUrl-$size'),
        );
      }

      // 4. Local File Path (non-web)
      if (!kIsWeb && File(path).existsSync()) {
        return _wrap(
          Image.file(
            File(path),
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
          ValueKey('logo-file-$path-$size'),
        );
      }
    }

    // 5. Mascot Fallback
    return _fallback();
  }

  Widget _fallback() {
    if (customFallback != null) return customFallback!;

    return _wrap(
      Image.asset(
        'assets/images/famalth_lynx_logo.png',
        fit: fit,
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
      ValueKey('logo-fallback-mascot-$size'),
    );
  }
}
