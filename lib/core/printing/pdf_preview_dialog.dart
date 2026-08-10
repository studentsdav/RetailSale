import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Shows an in-app PDF preview dialog.
///
/// Pass [pageFormat] so the preview renders at the correct paper size:
/// - Thermal bills  → narrow roll width (e.g. 80 mm)
/// - A4 bills       → [PdfPageFormat.a4]
///
/// The dialog contains Print / Share / Download actions from [PdfPreview]
/// and always appears **in front** of the Flutter window on Windows desktop
/// (avoids the OS dialog going to background).
///
/// Usage:
/// ```dart
/// await showPdfPreviewDialog(
///   context: context,
///   name: order.saleNo,
///   pageFormat: PosInvoicePrinter.pageFormatFor(order.billFormat),
///   buildPdf: (_) async => pdfBytes,
/// );
/// ```
Future<void> showPdfPreviewDialog({
  required BuildContext context,
  required String name,
  required Future<Uint8List> Function(PdfPageFormat format) buildPdf,
  PdfPageFormat? pageFormat,
  /// Optional pre-built bytes (e.g. built concurrently during save).
  Uint8List? prebuiltBytes,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _PdfPreviewDialog(
      name: name,
      buildPdf: buildPdf,
      pageFormat: pageFormat ?? PdfPageFormat.a4,
      prebuiltBytes: prebuiltBytes,
    ),
  );
}

class _PdfPreviewDialog extends StatelessWidget {
  const _PdfPreviewDialog({
    required this.name,
    required this.buildPdf,
    required this.pageFormat,
    this.prebuiltBytes,
  });

  final String name;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;
  final PdfPageFormat pageFormat;
  final Uint8List? prebuiltBytes;

  bool get _isThermal => pageFormat.width < 150 * PdfPageFormat.mm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;

    // For thermal (narrow) bills show a narrow dialog; for A4 a wider one.
    final dialogWidth = _isThermal
        ? (screenSize.width * 0.42).clamp(280.0, 480.0)
        : screenSize.width * 0.88;
    final dialogHeight = screenSize.height * 0.92;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // ── Header bar ──────────────────────────────────────────────────
            Container(
              color: colorScheme.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name.isNotEmpty ? 'Bill: $name' : 'Bill Preview',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _isThermal
                              ? '${(pageFormat.width / PdfPageFormat.mm).round()} mm Thermal Roll'
                              : 'A4 Format',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                    splashRadius: 20,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // ── PDF preview ─────────────────────────────────────────────────
            Expanded(
              child: PdfPreview(
                // If we have pre-built bytes use them directly, otherwise let
                // PdfPreview call buildPdf with the correct format.
                build: prebuiltBytes != null
                    ? (_) async => prebuiltBytes!
                    : buildPdf,
                initialPageFormat: pageFormat,
                pdfFileName: '$name.pdf',
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                allowSharing: true,
                allowPrinting: true,
                // Make the action bar blend with our header.
                actionBarTheme: PdfActionBarTheme(
                  backgroundColor: colorScheme.primaryContainer,
                  iconColor: colorScheme.onPrimaryContainer,
                  textStyle: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
                loadingWidget: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Generating bill…'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
