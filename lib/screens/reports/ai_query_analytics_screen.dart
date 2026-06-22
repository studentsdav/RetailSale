import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../controllers/reports/ai_query_analytics_controller.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/api/endpoints.dart';

class AiQueryAnalyticsScreen extends StatefulWidget {
  const AiQueryAnalyticsScreen({super.key});

  @override
  State<AiQueryAnalyticsScreen> createState() => _AiQueryAnalyticsScreenState();
}

class _AiQueryAnalyticsScreenState extends State<AiQueryAnalyticsScreen> {
  final AiQueryAnalyticsController _controller = AiQueryAnalyticsController();
  final TextEditingController _promptCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Navigation display mode
  bool _showChartView = false;

  // Chart configuration
  String? _xAxisCol;
  String? _yAxisCol;
  String _chartType = 'Bar'; // Bar, Line, Pie

  // Pagination state
  int _currentPage = 0;
  int _rowsPerPage = 10;

  // Custom loading text animation
  Timer? _loadingTimer;
  int _loadingTextIndex = 0;
  final List<String> _loadingTexts = [
    'Translating your question to safe SQL query...',
    'Inspecting database schema definitions...',
    'Executing query inside read-only transaction...',
    'Summarizing dataset patterns using AI Analyst...',
    'Structuring narrative intelligence summary...',
    'Preparing tabular data view...',
  ];

  // Suggestions for rapid testing
  final List<String> _suggestions = [
    'Show top sales this month',
    'Show WhatsApp log summary and cost',
    'List active item master inventory',
    'Compare completed vs draft sales',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _controller.initPrefs();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _promptCtrl.dispose();
    _focusNode.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (_controller.loading) {
      _startLoadingTimer();
    } else {
      _stopLoadingTimer();
    }

    // Auto-detect columns for graphing when new data loaded
    if (!_controller.loading && _controller.sampleRows.isNotEmpty) {
      final sampleRows = _controller.sampleRows;
      final keys = List<String>.from(sampleRows.first.keys);
      final numericKeys = keys.where((k) => sampleRows.any((r) => _isNumeric(r[k]))).toList();
      
      setState(() {
        _currentPage = 0;
        
        // Auto-select Y-axis
        if (numericKeys.isNotEmpty) {
          _yAxisCol = numericKeys.first;
          // Auto-select X-axis (prefer non-numeric)
          final nonNumericKeys = keys.where((k) => !numericKeys.contains(k)).toList();
          _xAxisCol = nonNumericKeys.isNotEmpty ? nonNumericKeys.first : keys.first;
        } else {
          _yAxisCol = null;
          _xAxisCol = null;
        }
      });
    }
  }

  void _startLoadingTimer() {
    _loadingTextIndex = 0;
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        _loadingTextIndex = (_loadingTextIndex + 1) % _loadingTexts.length;
      });
    });
  }

  void _stopLoadingTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }

  Future<void> _submitQuery() async {
    final text = _promptCtrl.text.trim();
    if (text.isEmpty) return;
    _focusNode.unfocus();
    await _controller.executeQuery(text);
  }

  void _useSuggestion(String suggestion) {
    _promptCtrl.text = suggestion;
    _promptCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _focusNode.requestFocus();
    setState(() {});
  }

  Future<void> _exportCsv() async {
    final cacheId = _controller.cacheId;
    if (cacheId == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading CSV file...')),
      );

      final token = await TokenStorage.read();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${ApiEndpoints.aiQueryExportCsv}?cacheId=$cacheId',
      );

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}${Platform.pathSeparator}ai_analytics_${DateTime.now().millisecondsSinceEpoch}.csv',
        );
        await file.writeAsBytes(response.bodyBytes, flush: true);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV saved to: ${file.path}')),
        );
        await OpenFile.open(file.path);
      } else {
        throw Exception(response.body.isNotEmpty ? response.body : 'Server returned status ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV Export Failed: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    final cacheId = _controller.cacheId;
    if (cacheId == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compiling PDF report preview...')),
      );

      final token = await TokenStorage.read();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${ApiEndpoints.aiQueryExportPdf}?cacheId=$cacheId',
      );

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        await Printing.layoutPdf(
          onLayout: (_) async => response.bodyBytes,
          name: 'AI_Analytics_Report_${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        throw Exception(response.body.isNotEmpty ? response.body : 'Server returned status ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF Export Failed: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  // Model settings configuration modal
  void _showSettingsDialog() {
    String selectedProvider = _controller.aiProvider ?? 'gemini';
    final keyCtrl = TextEditingController(text: _controller.aiApiKey ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.tune_outlined, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Text('AI Model Settings'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Configure your custom model provider and key credentials. Default server environment settings are used if fields are left blank.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedProvider,
                      decoration: const InputDecoration(
                        labelText: 'LLM Model Provider',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'gemini', child: Text('Gemini (gemini-2.5-flash)')),
                        DropdownMenuItem(value: 'openai', child: Text('OpenAI (gpt-4o)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedProvider = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: keyCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'API Authentication Key',
                        border: OutlineInputBorder(),
                        helperText: 'Keys are stored locally on this terminal.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await _controller.savePrefs(selectedProvider, keyCtrl.text);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('AI settings saved successfully.')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Data conversion helpers for charting
  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final s = val.toString().trim();
    return double.tryParse(s) ?? 0.0;
  }

  bool _isNumeric(dynamic val) {
    if (val == null) return false;
    if (val is num) return true;
    final s = val.toString().trim();
    return double.tryParse(s) != null;
  }

  // Simple Markdown Parser to rich widgets
  List<Widget> _parseMarkdown(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            trimmed.substring(4),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            trimmed.substring(3),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            trimmed.substring(2),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ));
      } else if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
        final content = trimmed.substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 8),
                child: Icon(Icons.circle, size: 6, color: Color(0xFF475569)),
              ),
              Expanded(
                child: _renderRichText(content),
              ),
            ],
          ),
        ));
      } else if (trimmed.startsWith('> ')) {
        final content = trimmed.substring(2);
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: Color(0xFF3B82F6), width: 4),
            ),
          ),
          child: _renderRichText(content),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _renderRichText(trimmed),
        ));
      }
    }

    return widgets;
  }

  Widget _renderRichText(String text) {
    final parts = text.split('**');
    final spans = <TextSpan>[];

    for (var i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: const Color(0xFF334155),
          fontSize: 14.5,
          height: 1.4,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AI Query Analytics'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'AI Model Configuration',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsDialog,
          ),
          if (_controller.cacheId != null && !_controller.loading) ...[
            IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: _exportCsv,
            ),
            IconButton(
              tooltip: 'Print PDF Report',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _exportPdf,
            ),
            const SizedBox(width: 8),
          ]
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. AI Questioning Console Card
                _buildQuestionConsole(),
                const SizedBox(height: 16),

                // 2. Loading State
                if (_controller.loading) _buildLoadingCard(),

                // 3. Error Card
                if (!_controller.loading && _controller.error != null)
                  _buildErrorCard(),

                // 4. Results Section
                if (!_controller.loading && _controller.cacheId != null) ...[
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  
                  // View Toggles (Table vs Chart)
                  _buildViewToggler(),
                  const SizedBox(height: 12),

                  if (_showChartView)
                    _buildChartView()
                  else
                    _buildDataGridSection(),

                  const SizedBox(height: 16),
                  _buildSQLDebugCard(),
                ],
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildQuestionConsole() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Natural Language Analytics Console',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptCtrl,
                      focusNode: _focusNode,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitQuery(),
                      decoration: const InputDecoration(
                        hintText:
                            'Ask a business question... (e.g., Show top sales this month)',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, right: 6),
                    child: Material(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: _controller.loading ? null : _submitQuery,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Suggestions:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _suggestions.map((suggestion) {
                final isSelected = _promptCtrl.text == suggestion;
                return ChoiceChip(
                  label: Text(
                    suggestion,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF475569),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFEEF2FF),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFC7D2FE)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _useSuggestion(suggestion);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _loadingTexts[_loadingTextIndex],
                key: ValueKey<int>(_loadingTextIndex),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: const Color(0xFFFEF2F2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFCA5A5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Query Execution Failed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _controller.error ?? 'An unexpected error occurred.',
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.red.shade800,
                height: 1.4,
              ),
            ),
            if (_controller.generatedQuery != null) ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFFCA5A5)),
              const SizedBox(height: 6),
              const Text(
                'Generated SQL Statement:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF991B1B),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _controller.generatedQuery!,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    color: Color(0xFF7F1D1D),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _controller.summaryText ?? '';
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFEEF2FF),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 13,
                        color: Color(0xFF4F46E5),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'AI Executive Narrative',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Dataset size: ${_controller.totalRows} rows',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._parseMarkdown(summary),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggler() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4),
        child: ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: const Color(0xFF4F46E5),
          color: const Color(0xFF475569),
          isSelected: [!_showChartView, _showChartView],
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.table_chart_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Table View', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.bar_chart_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Chart View', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          onPressed: (index) {
            setState(() {
              _showChartView = (index == 1);
            });
          },
        ),
      ),
    );
  }

  Widget _buildChartView() {
    final sampleRows = _controller.sampleRows;
    if (sampleRows.isEmpty) return const SizedBox.shrink();

    final keys = List<String>.from(sampleRows.first.keys);
    final numericKeys = keys.where((k) => sampleRows.any((r) => _isNumeric(r[k]))).toList();

    if (numericKeys.isEmpty || _xAxisCol == null || _yAxisCol == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'No numeric columns returned in this dataset to plot a graph.',
              style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );
    }

    Widget chartWidget;

    if (_chartType == 'Pie') {
      chartWidget = SfCircularChart(
        legend: const Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.wrap,
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CircularSeries>[
          PieSeries<dynamic, String>(
            dataSource: sampleRows,
            xValueMapper: (row, _) => row[_xAxisCol]?.toString() ?? '',
            yValueMapper: (row, _) => _toDouble(row[_yAxisCol]),
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelPosition: ChartDataLabelPosition.outside,
            ),
            enableTooltip: true,
          )
        ],
      );
    } else if (_chartType == 'Line') {
      chartWidget = SfCartesianChart(
        primaryXAxis: const CategoryAxis(
          labelRotation: 45,
          labelIntersectAction: AxisLabelIntersectAction.multipleRows,
        ),
        primaryYAxis: const NumericAxis(),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries>[
          LineSeries<dynamic, String>(
            dataSource: sampleRows,
            xValueMapper: (row, _) => row[_xAxisCol]?.toString() ?? '',
            yValueMapper: (row, _) => _toDouble(row[_yAxisCol]),
            dataLabelSettings: const DataLabelSettings(isVisible: true),
            markerSettings: const MarkerSettings(isVisible: true),
            enableTooltip: true,
          )
        ],
      );
    } else {
      chartWidget = SfCartesianChart(
        primaryXAxis: const CategoryAxis(
          labelRotation: 45,
          labelIntersectAction: AxisLabelIntersectAction.multipleRows,
        ),
        primaryYAxis: const NumericAxis(),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries>[
          ColumnSeries<dynamic, String>(
            dataSource: sampleRows,
            xValueMapper: (row, _) => row[_xAxisCol]?.toString() ?? '',
            yValueMapper: (row, _) => _toDouble(row[_yAxisCol]),
            dataLabelSettings: const DataLabelSettings(isVisible: true),
            enableTooltip: true,
          )
        ],
      );
    }

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _xAxisCol,
                    decoration: const InputDecoration(
                      labelText: 'X-Axis (Label)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: keys.map((k) {
                      return DropdownMenuItem(value: k, child: Text(k.replaceAll('_', ' ')));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _xAxisCol = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _yAxisCol,
                    decoration: const InputDecoration(
                      labelText: 'Y-Axis (Value)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: numericKeys.map((k) {
                      return DropdownMenuItem(value: k, child: Text(k.replaceAll('_', ' ')));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _yAxisCol = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _chartType,
                    decoration: const InputDecoration(
                      labelText: 'Chart Type',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Bar', child: Text('Bar Chart')),
                      DropdownMenuItem(value: 'Line', child: Text('Line Chart')),
                      DropdownMenuItem(value: 'Pie', child: Text('Pie Chart')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _chartType = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 350,
              child: chartWidget,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataGridSection() {
    final sampleRows = _controller.sampleRows;
    if (sampleRows.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'No records returned from query.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    final totalRows = _controller.totalRows;
    final keys = List<String>.from(sampleRows.first.keys);

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage) > sampleRows.length
        ? sampleRows.length
        : (startIndex + _rowsPerPage);
    final displayedRows = sampleRows.sublist(startIndex, endIndex);

    final totalPages = (sampleRows.length / _rowsPerPage).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (totalRows > 100)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Showing analysis for top 100 records. Click export to download all $totalRows records.',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Card(
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Query Results Table',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Rows per page: ',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        DropdownButton<int>(
                          value: _rowsPerPage,
                          items: [10, 20, 50, 100]
                              .map(
                                (n) => DropdownMenuItem<int>(
                                  value: n,
                                  child: Text(
                                    n.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _rowsPerPage = val;
                                _currentPage = 0;
                              });
                            }
                          },
                          underline: const SizedBox(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              Scrollbar(
                thickness: 6,
                radius: const Radius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: const Color(0xFFF1F5F9),
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF8FAFC),
                      ),
                      headingRowHeight: 40,
                      dataRowMinHeight: 38,
                      dataRowMaxHeight: 44,
                      columns: keys.map((keyName) {
                        final formattedHeader = keyName
                            .replaceAll('_', ' ')
                            .split(' ')
                            .map((word) => word.isEmpty
                                ? ''
                                : '${word[0].toUpperCase()}${word.substring(1)}')
                            .join(' ');
                        return DataColumn(
                          label: Text(
                            formattedHeader,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                          ),
                        );
                      }).toList(),
                      rows: displayedRows.map((row) {
                        return DataRow(
                          cells: keys.map((keyName) {
                            final val = row[keyName];
                            String displayString = '';
                            if (val != null) {
                              displayString = val.toString();
                            }
                            return DataCell(
                              Text(
                                displayString,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${startIndex + 1}-$endIndex of ${sampleRows.length} records',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          iconSize: 20,
                          onPressed: _currentPage > 0
                              ? () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                }
                              : null,
                        ),
                        Text(
                          'Page ${_currentPage + 1} of $totalPages',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          iconSize: 20,
                          onPressed: _currentPage < (totalPages - 1)
                              ? () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSQLDebugCard() {
    final query = _controller.generatedQuery;
    if (query == null) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: const Text(
          'View Executed SQL Query',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
        leading: const Icon(Icons.code_rounded, color: Color(0xFF64748B)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SelectableText(
              query,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Note: Query executes inside a Read-Only transaction and enforces multi-tenant boundary parameters.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
