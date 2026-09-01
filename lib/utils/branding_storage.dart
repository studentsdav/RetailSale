import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/token_storage.dart';

class BrandingContext {
  final String outletCode;
  final String businessName;
  final String? logoPath;

  const BrandingContext({
    required this.outletCode,
    required this.businessName,
    required this.logoPath,
  });
}

class BrandingStorage {
  BrandingStorage._();

  static String _logoKey(String outletCode) => 'brand_logo_$outletCode';

  static String? _cachedPath;
  static pw.MemoryImage? _cachedLogo;

  static Future<String?> saveLogoBytesForOutlet({
    required String outletCode,
    required Uint8List bytes,
    required String extension,
  }) async {
    final cleanExt = extension.replaceAll('.', '').toLowerCase();
    final extName = cleanExt.isEmpty ? 'png' : cleanExt;
    final base64Str = base64Encode(bytes);
    final dataUri = 'data:image/$extName;base64,$base64Str';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logoKey(outletCode), dataUri);
    _cachedPath = null;
    _cachedLogo = null;
    return dataUri;
  }

  static Future<String?> saveLogoForOutlet({
    required String outletCode,
    required String sourcePath,
  }) async {
    if (kIsWeb) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final brandingDir = Directory(p.join(appDir.path, 'branding', outletCode));
    if (!await brandingDir.exists()) {
      await brandingDir.create(recursive: true);
    }

    final extension = p.extension(source.path).toLowerCase();
    final targetPath = p.join(
      brandingDir.path,
      'business_logo${extension.isEmpty ? '.png' : extension}',
    );

    await source.copy(targetPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logoKey(outletCode), targetPath);
    _cachedPath = null;
    _cachedLogo = null;
    return targetPath;
  }

  static Future<String?> getLogoPathForOutlet(String outletCode) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_logoKey(outletCode));
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('data:image') || path.startsWith('http')) return path;
    if (kIsWeb) return null;
    return await File(path).exists() ? path : null;
  }

  static Future<String?> getCurrentOutletCode() async {
    final user = await TokenStorage.getUser();
    final code = user?['outlet_code']?.toString().trim();
    if (code == null || code.isEmpty) return null;
    return code;
  }

  static Future<String?> getCurrentLogoPath() async {
    final outletCode = await getCurrentOutletCode();
    if (outletCode == null) return null;
    return getLogoPathForOutlet(outletCode);
  }

  static Future<BrandingContext?> getCurrentBrandingContext() async {
    final user = await TokenStorage.getUser();
    if (user == null) return null;

    final outletCode = user['outlet_code']?.toString() ?? '';
    if (outletCode.isEmpty) return null;

    return BrandingContext(
      outletCode: outletCode,
      businessName: user['property_name']?.toString() ?? '',
      logoPath: await getLogoPathForOutlet(outletCode),
    );
  }

  static Future<Uint8List?> readLogoBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('data:image')) {
      try {
        final base64Part = path.split(',').last;
        return base64Decode(base64Part);
      } catch (_) {
        return null;
      }
    }
    if (kIsWeb) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<pw.MemoryImage?> loadPdfLogo(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (_cachedPath == path && _cachedLogo != null) {
      return _cachedLogo;
    }
    final bytes = await readLogoBytes(path);
    if (bytes == null) return null;
    _cachedPath = path;
    _cachedLogo = pw.MemoryImage(bytes);
    return _cachedLogo;
  }
}
