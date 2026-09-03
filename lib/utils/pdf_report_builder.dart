import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'branding_storage.dart';
import '../core/config/date_time_service.dart';

class PdfKpiItem {
  final String label;
  final String value;
  final PdfColor color;

  const PdfKpiItem({
    required this.label,
    required this.value,
    this.color = PdfColors.black,
  });
}

class PdfReportBuilder {
  PdfReportBuilder._();

  static Future<void> generateAndPrintReport({
    required String title,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> data,
    Map<int, pw.TableColumnWidth>? columnWidths,
    Map<int, pw.Alignment>? cellAlignments,
    List<PdfKpiItem>? kpis,
    PdfPageFormat? pageFormat,
    String? pdfFileName,
  }) async {
    final format = pageFormat ?? PdfPageFormat.a4.landscape;
    final pdf = pw.Document();
    final nowStr = DateTimeService.instance.formatNow('dd-MMM-yyyy hh:mm a');

    final branding = await BrandingStorage.getCurrentBrandingContext();
    final logo = await BrandingStorage.loadPdfLogo(branding?.logoPath);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        header: (context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logo != null)
                        pw.Container(
                          width: 45,
                          height: 45,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(logo, fit: pw.BoxFit.contain),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if ((branding?.businessName ?? '').isNotEmpty)
                            pw.Text(
                              branding!.businessName,
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#1E293B'),
                              ),
                            ),
                          pw.Text(
                            title.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#2563EB'),
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              subtitle,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: $nowStr',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Total Records: ${data.length}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#475569'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 1),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'RetailSale POS — $title',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          if (kpis != null && kpis.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: kpis.map((kpi) {
                  return pw.Column(
                    children: [
                      pw.Text(
                        kpi.label.toUpperCase(),
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        kpi.value,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: kpi.color,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1E293B'),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 7.0,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: cellAlignments,
            rowDecoration: const pw.BoxDecoration(
              color: PdfColors.white,
            ),
            oddRowDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
            ),
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#CBD5E1'),
              width: 0.5,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            columnWidths: columnWidths,
          ),
        ],
      ),
    );

    final fileName = pdfFileName ?? '${title.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}';
    await Printing.layoutPdf(
      name: fileName,
      onLayout: (_) => pdf.save(),
    );
  }
}
